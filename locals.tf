locals {
  # Per-environment differences that match what is live on each cluster.
  live_overrides = {
    devops_filebrowser            = false
    nomic_deployment              = true
    nomic_ingress                 = true
    neo4j_ingress                 = true # neo4j is disabled everywhere but its ingress is still live
    neo4j_bolt_transport          = true
    neo4j_ssl_redirect_annotation = false
    common_matrix_storage         = false
    common_storage_enabled        = var.cloud_provider != "aws" # RWX; EBS has no ReadWriteMany backing
    graphiti_image_updater        = false                       # re-enable once an image-updater writer exists
    grafana_tls_redirect          = false
    argocd_image_updater_app      = terraform.workspace != "mainnet" # mainnet pins image tags by hand
    digihub_tunnel                = false
    unprobed_apps                 = []
    # Immutable on an existing PVC.
    common_storage = {
      name          = "${var.org}-core-common-storage"
      size          = "100Gi"
      storage_class = var.storage_classes["shared"]
    }
  }

  # Environment identity, decoupled from terraform.workspace (see var.environments).
  # cloud_resource_name: AWS names that cannot be renamed (EKS cluster, IAM roles, SGs).
  env                  = var.environments[terraform.workspace]
  cloud_resource_name  = coalesce(local.env.cloud_resource_name, terraform.workspace)
  global_resource_name = coalesce(local.env.global_resource_name, terraform.workspace)
  # Keeps a renamed workspace's old name where it renders; see variables.tf.
  legacy_workspace_name = coalesce(local.env.legacy_workspace_name, terraform.workspace)
  kubeconfig_name       = coalesce(local.env.kubeconfig_name, local.cloud_resource_name)

  # DNS hostname segment; dns_segment overrides keys that are not valid DNS labels.
  dns_segment_overrides = {
    for env, cfg in var.environments : env => cfg.dns_segment if cfg.dns_segment != null
  }

  dns_segment_for_environment = {
    for env, _ in var.environments : env => lookup(local.dns_segment_overrides, env, env)
  }

  # GitHub team slug for Vault OIDC (ixofoundation:<segment>-devsecops); not a DNS label.
  vault_oidc_team_segment = coalesce(local.env.vault_oidc_team, terraform.workspace)

  # charts/<tree>/ in ixo-helm-charts that ArgoCD Applications read.
  chart_tree = coalesce(local.env.chart_tree, terraform.workspace)

  # The chain environment this workspace serves, where it differs from the workspace name.
  network_name = coalesce(local.env.network_name, terraform.workspace)

  # dns_for_environment is null for disabled apps.
  neo4j_host = "neo4j.${local.dns_segment_for_environment[terraform.workspace]}.${var.domains[var.environments[terraform.workspace].application_configs["neo4j"].domain]}"

  # Extract all unique domain keys used in application configs
  used_domain_keys = toset(flatten([
    for env, env_config in var.environments : [
      for service, config in env_config.application_configs : config.domain
      if config.domain != null
    ]
  ]))

  # Validate that all used domain keys exist in the domains variable
  domain_validation = {
    for key in local.used_domain_keys : key => lookup(var.domains, key, null) != null
  }

  synthetic_monitoring_endpoints = concat(
    compact([
      for app, config in var.environments[terraform.workspace].application_configs :
      contains(local.excluded_synthetic_monitoring, app) || contains(local.live_overrides.unprobed_apps, app) || !config.enabled ? null : (
        config.dns_prefix != null ? (
          "https://${config.dns_prefix}.${local.dns_segment_for_environment[terraform.workspace]}.${var.domains[config.domain]}"
        ) : config.dns_endpoint != null ? "https://${config.dns_endpoint}" : null
      )
    ]),
    lookup(var.additional_manual_synthetic_monitoring_endpoints, terraform.workspace, [])
  )
  excluded_synthetic_monitoring = [ #TODO move this to variables.tf
    # Application services that shouldn't be monitored
    "ixo_trading_bot_server",
    "hermes",
    "ixo_registry_server",
    "searxng",
    # Infrastructure services that shouldn't be monitored via blackbox
    "cert_manager",
    "ingress_nginx",
    "postgres_operator_crunchydata",
    "prometheus_stack",
    "external_dns",
    "dex",
    "vault",
    "loki",
    "prometheus_blackbox_exporter",
    "tailscale",
    "matrix",
    "nfs_provisioner",
    "metrics_server",
    "hyperlane_validator",
    "aws_vpc",
    "chromadb",
    "matrix_admin",
    "matrix_livekit",
    "memory_engine_graphiti",
    "falco_security",
    "ixo_matrix_whatsapp",
    "ixo_sygnal",
    "ixo_matrix_supamoto_bot",
    "ixo_matrix_supamoto_onboarding_server",
    "ixo_matrix_supamoto_claims_bot",
    "supamoto_matrix_bids_bot",
    "supamoto_matrix_state_bot",
    "supamoto_matrix_appservice_rooms",
    "nomic_embedding",
    "vault_argocd_watcher",
    "ixo_flow_manager_oracle"
  ]

  # Vault ArgoCD Watcher - derived from application_configs where create_kv = true and enabled.
  # Add entries to additional_manual_vault_watched_apps (per workspace) for apps that use vault
  # path syntax in their upstream helm chart but have create_kv = false.
  # Add entries to excluded_vault_watched_apps for apps that have create_kv = true but should not be watched.
  vault_watched_apps = sort(concat(
    compact([
      for key, config in var.environments[terraform.workspace].application_configs :
      config.enabled && config.create_kv && !contains(local.excluded_vault_watched_apps, replace(key, "_", "-"))
      ? replace(key, "_", "-")
      : null
    ]),
    lookup(var.additional_manual_vault_watched_apps, terraform.workspace, [])
  ))

  excluded_vault_watched_apps = [
    # ArgoCD app names (kebab-case) that have create_kv = true but should not be watched
    # e.g. "ixo-some-app"
  ]

  vault_mount_path = var.vault_core_mount

  # Vault raft snapshot backup: the bucket, the ServiceAccount and the CronJob are one
  # unit, so they share a single condition.
  vault_snapshot_enabled = (
    var.environments[terraform.workspace].application_configs["vault"].enabled &&
    var.environments[terraform.workspace].application_configs["vault"].vault_snapshot_enabled
  )

  # Null until the service account behind the hand-placed gcp-key-secret is recorded in
  # tfvars; see vault_snapshot_writer_sa_email in variables.tf.
  vault_snapshot_writer_sa_email = var.environments[terraform.workspace].application_configs["vault"].vault_snapshot_writer_sa_email

  # IXO DNS Entries - extract from application configs
  dns_for_environment = {
    for env, env_config in var.environments : env => {
      for service, config in env_config.application_configs : service => config.enabled ? (
        config.dns_prefix != null ? (
          "${config.dns_prefix}.${local.dns_segment_for_environment[env]}.${var.domains[config.domain]}"
        ) : config.dns_endpoint != null ? config.dns_endpoint : null
      ) : null
    }
  }

  # DNS cross-env guard: a workspace with a dns_segment override must not render another
  # env's live hostname (dns_endpoint is used verbatim). Inert where no override is set.
  dns_guard_segment = lookup(local.dns_segment_overrides, terraform.workspace, null)

  # Hyphens stripped on both sides so "testnet-test" matches "testnettest".
  dns_guard_normalise = { for k, v in local.dns_segment_overrides : k => replace(v, "-", "") }

  # Hosts built outside dns_for_environment, which external-dns publishes just the same.
  dns_guard_extra_hosts = {
    ixo_registry_server = local.registry_server_tls
    ixo_cellnode        = local.cellnode_tls_hostnames
    neo4j               = [local.neo4j_host]
  }

  # Enabled apps only: dns_for_environment already yields null for a disabled app, and 25
  # disabled blocks carrying a stale endpoint are the normal state of this file.
  dns_guard_hosts = {
    for app, config in var.environments[terraform.workspace].application_configs : app => distinct(compact(concat(
      [local.dns_for_environment[terraform.workspace][app]],
      try(local.dns_guard_extra_hosts[app], []),
    ))) if config.enabled
  }

  # var.dns_cutover_apps is the per-app opt-in to take over another environment's live
  # hostname at cutover. A name that is not an app here fails too, so a typo cannot pass.
  dns_guard_violations = local.dns_guard_segment == null ? [] : sort(concat(
    [
      for app in var.dns_cutover_apps : "${app} = (in dns_cutover_apps but not an app on this workspace)"
      if !contains(keys(var.environments[terraform.workspace].application_configs), app)
    ],
    flatten([
      for app, hosts in local.dns_guard_hosts : [
        for host in hosts : "${app} = ${host}"
        if !contains(var.dns_cutover_apps, app) && !strcontains(replace(host, "-", ""), local.dns_guard_normalise[terraform.workspace])
      ]
    ]),
  ))
  # --- end DNS cross-environment guard ---------------------------------------------

  # Helper function to get domain from application config
  get_domain = {
    for env, env_config in var.environments : env => {
      for service, config in env_config.application_configs : service => config.enabled && config.domain != null ? var.domains[config.domain] : null
    }
  }

  storage_class_for_environment = {
    for env, env_config in var.environments : env => {
      for service, config in env_config.application_configs : service => config.enabled && config.storage_class != null ? var.storage_classes[config.storage_class] : null
    }
  }

  storage_size_for_environment = {
    for env, env_config in var.environments : env => {
      for service, config in env_config.application_configs : service => config.enabled && config.storage_size != null ? config.storage_size : null
    }
  }

  cellnode_hosts = terraform.workspace == "testnet" ? [
    {
      host = local.dns_for_environment[terraform.workspace]["ixo_cellnode"]
      paths = [{
        path     = "/"
        pathType = "Prefix"
      }]
    },
    {
      host = "cellnode-pandora.${var.domains[var.environments[terraform.workspace].application_configs["ixo_cellnode"].domain]}" # cellnode-pandora.ixo.earth
      paths = [{
        path     = "/"
        pathType = "Prefix"
      }]
    },
    {
      # NOTE: Hardcoded "ixoworld" - this creates a cross-domain alias (testnet service on .world domain)
      # Cannot easily be made dynamic without restructuring the multi-host logic
      host = "cellnode-pandora.${var.domains["ixoworld"]}" # cellnode-pandora.ixo.world  
      paths = [{
        path     = "/"
        pathType = "Prefix"
      }]
    }
    ] : terraform.workspace == "mainnet" ? [
    {
      host = local.dns_for_environment[terraform.workspace]["ixo_cellnode"] # cellnode.ixo.world
      paths = [{
        path     = "/"
        pathType = "Prefix"
      }]
    },
    {
      # NOTE: Hardcoded "ixoearth" - this creates a cross-domain alias (mainnet service on .earth domain)  
      # Cannot easily be made dynamic without restructuring the multi-host logic
      host = "cellnode.${var.domains["ixoearth"]}" # cellnode.ixo.earth
      paths = [{
        path     = "/"
        pathType = "Prefix"
      }]
    }
    ] : [{
      host = local.dns_for_environment[terraform.workspace]["ixo_cellnode"]
      paths = [{
        path     = "/"
        pathType = "Prefix"
      }]
  }]

  registry_server_hosts = terraform.workspace == "mainnet" ? [
    {
      host = local.dns_for_environment[terraform.workspace]["ixo_registry_server"]
      paths = [{
        path     = "/"
        pathType = "Prefix"
      }]
    },
    {
      host = "api.${var.domains[var.environments[terraform.workspace].application_configs["ixo_registry_server"].domain]}"
      paths = [{
        path     = "/"
        pathType = "Prefix"
      }]
    }
    ] : [
    {
      host = local.dns_for_environment[terraform.workspace]["ixo_registry_server"]
      paths = [{
        path     = "/"
        pathType = "Prefix"
      }]
    },
    {
      # testnet's dns_segment is still "testnet-test", so the lookup keeps testnet.api.<domain>;
      # drop it when the segment becomes "testnet".
      host = "${lookup({ testnet = "testnet" }, terraform.workspace, local.dns_segment_for_environment[terraform.workspace])}.api.${var.domains[var.environments[terraform.workspace].application_configs["ixo_registry_server"].domain]}"
      paths = [{
        path     = "/"
        pathType = "Prefix"
      }]
    }
  ]
  cellnode_tls_hostnames = [for host in local.cellnode_hosts : host.host]
  registry_server_tls    = [for host in local.registry_server_hosts : host.host]

  # IXO-3541: PROXY protocol on the AWS Classic ELB; trust the VPC CIDR.
  aws_proxy_protocol_environments = ["mainnet"]
  enable_aws_proxy_protocol       = var.cloud_provider == "aws" && contains(local.aws_proxy_protocol_environments, terraform.workspace)

  # Helm
  helm_values_config_path = "${path.root}/config/yml/helm_values"

  # Postgres Operator
  postgres_operator_config_path = "${path.root}/config/yml/postgres-operator"

  # Switches both PostgresClusters in this workspace from the pgmonitor exporter to the
  # OpenTelemetry collector. Required before Postgres 18, which the exporter does not
  # support. Metrics change namespace from pg_* to ccp_*, and log shipping moves from the
  # promtail sidecar to the collector.
  pg_enable_otel = var.environments[terraform.workspace].application_configs["postgres_operator_crunchydata"].use_otel

  # Patroni synchronous_mode on the core cluster in this workspace. Applied to ixo-postgres
  # only: the matrix cluster runs a single instance, so it has no standby to synchronise
  # with. See variables.tf for the trade-off and the precondition.
  pg_enable_sync_replication = var.environments[terraform.workspace].application_configs["postgres_operator_crunchydata"].enable_sync_replication

  # pgBackRest retention for this workspace, per cluster. The object-storage and
  # PersistentVolume repositories are bounded differently; see variables.tf.
  pg_retention_days        = var.environments[terraform.workspace].application_configs["postgres_operator_crunchydata"].backup_retention_days
  pg_retention_full_matrix = var.environments[terraform.workspace].application_configs["postgres_operator_crunchydata"].matrix_backup_retention_full

  # Major version upgrade state for this workspace (see variable "pg_upgrade").
  pg_upgrade_cfg = lookup(var.pg_upgrade, terraform.workspace, null)

  # Per-cluster resolution of the values a major version upgrade changes. Clusters not
  # listed in pg_upgrade.clusters keep their pg_ixo/pg_matrix defaults, allowing an upgrade
  # to be staged one cluster at a time. Version and image change only at cutover, which is
  # what makes stages 1 and 2 reversible.
  pg_upgrade_for = {
    for c in [
      { name = var.pg_ixo.pg_cluster_name, version = var.pg_ixo.pg_version, image_tag = var.pg_ixo.pg_image_tag, pgbackrest_image_tag = var.pg_ixo.pgbackrest_image_tag },
      { name = var.pg_matrix.pg_cluster_name, version = var.pg_matrix.pg_version, image_tag = var.pg_matrix.pg_image_tag, pgbackrest_image_tag = var.pg_matrix.pgbackrest_image_tag },
      ] : c.name => (
      local.pg_upgrade_cfg != null && try(local.pg_upgrade_cfg.enabled, false) && contains(try(local.pg_upgrade_cfg.clusters, []), c.name)
      ? {
        pg_version           = local.pg_upgrade_cfg.cutover ? tostring(local.pg_upgrade_cfg.to_version) : c.version
        pg_image_tag         = local.pg_upgrade_cfg.cutover ? local.pg_upgrade_cfg.postgres_image_tag : c.image_tag
        pgbackrest_image_tag = local.pg_upgrade_cfg.cutover ? local.pg_upgrade_cfg.pgbackrest_image_tag : c.pgbackrest_image_tag
        shutdown             = local.pg_upgrade_cfg.shutdown
        upgrade = {
          name            = "${c.name}-pg${local.pg_upgrade_cfg.from_version}-to-pg${local.pg_upgrade_cfg.to_version}"
          from_version    = local.pg_upgrade_cfg.from_version
          to_version      = local.pg_upgrade_cfg.to_version
          transfer_method = local.pg_upgrade_cfg.transfer_method
        }
      }
      : {
        pg_version           = c.version
        pg_image_tag         = c.image_tag
        pgbackrest_image_tag = c.pgbackrest_image_tag
        shutdown             = false
        upgrade              = null
      }
    )
  }

  pg_users_usernames = [for user in var.pg_ixo.pg_users : user.username]
  pg_users_yaml = yamlencode(
    [
      for user in var.pg_ixo.pg_users : {
        name      = user.username
        databases = user.databases
        options   = user.options != null ? user.options : "NOSUPERUSER"
      }
    ]
  )

  matrix_pg_users_usernames = [for user in var.pg_matrix.pg_users : user.username]
  matrix_pg_users_yaml = yamlencode(
    [
      for user in var.pg_matrix.pg_users : {
        name      = user.username
        databases = user.databases
        options   = user.options != null ? user.options : "NOSUPERUSER"
      }
    ]
  )

  # Via dns_for_environment (null when disabled) so dns_prefix works too.
  prometheus_stack_host = local.dns_for_environment[terraform.workspace]["prometheus_stack"]

  # Argo Helm Ignore Differences
  prometheus_stack_ignore_differences = <<EOT
- group: admissionregistration.k8s.io
  kind: MutatingWebhookConfiguration
  jsonPointers:
    - /webhooks
- group: admissionregistration.k8s.io
  kind: ValidatingWebhookConfiguration
  jsonPointers:
    - /webhooks
- group: apps
  kind: DaemonSet
  jsonPointers:
    - /spec/template/spec/containers/0/resources
- group: apps
  kind: Deployment
  jsonPointers:
    - /spec/template/spec/containers/0/resources
    - /spec/template/spec/containers/1/resources
    - /spec/template/spec/containers/2/resources
    - /spec/template/spec/initContainers/0/resources
EOT
  loki_ignore_differences             = <<EOT
- group: apiextensions.k8s.io
  kind: CustomResourceDefinition
  jsonPointers:
    - /metadata/annotations
    - /spec/versions
- group: apps
  kind: DaemonSet
  jsonPointers:
    - /spec/template/spec/containers/0/resources
- group: apps
  kind: Deployment
  jsonPointers:
    - /spec/template/spec/containers/0/resources
EOT
  vault_ignore_differences            = <<EOT
- group: admissionregistration.k8s.io
  kind: MutatingWebhookConfiguration
  jsonPointers:
    - /webhooks
- group: apps
  kind: StatefulSet
  jqPathExpressions:
    - '.spec.volumeClaimTemplates[]?'
EOT
  nfs_provisioner_ignore_differences  = <<EOT
- group: apps
  kind: StatefulSet
  jsonPointers:
    - /spec/volumeClaimTemplates
EOT
  cert_manager_ignore_differences     = <<EOT
- group: admissionregistration.k8s.io
  kind: MutatingWebhookConfiguration
  jsonPointers:
    - /webhooks
- group: admissionregistration.k8s.io
  kind: ValidatingWebhookConfiguration
  jsonPointers:
    - /webhooks
- group: apps
  kind: Deployment
  jsonPointers:
    - /spec/template/spec/containers/0/resources
EOT
  nginx_ignore_differences            = <<EOT
- kind: Service
  jsonPointers:
    - /spec/ports
- group: admissionregistration.k8s.io
  kind: ValidatingWebhookConfiguration
  jsonPointers:
    - /webhooks
EOT
  # cert-manager http01-edit-in-place edits spec.rules during ACME challenges.
  edit_in_place_ignore_differences = <<EOT
- kind: Secret
  jsonPointers:
    - /data
- group: networking.k8s.io
  kind: Ingress
  jqPathExpressions:
    - .spec.rules
EOT
  matrix_ignore_differences        = <<EOT
- kind: Secret
  name: matrix-synapse
  namespace: matrix-synapse
  jsonPointers:
    - /data/config.yaml
- group: apps
  kind: Deployment
  name: matrix-synapse
  namespace: matrix-synapse
  jsonPointers:
    - /spec/template/metadata/annotations/checksum~1secrets
EOT
}
