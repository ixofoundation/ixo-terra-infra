locals {
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
      contains(local.excluded_synthetic_monitoring, app) || !config.enabled ? null : (
        config.dns_prefix != null ? (
          terraform.workspace == "mainnet" ? "https://${config.dns_prefix}.${var.domains[config.domain]}" : "https://${config.dns_prefix}.${terraform.workspace}.${var.domains[config.domain]}"
        ) : config.dns_endpoint != null ? "https://${config.dns_endpoint}" : null
      )
    ]),
    lookup(var.additional_manual_synthetic_monitoring_endpoints, terraform.workspace, [])
  )
  excluded_synthetic_monitoring = [
    # Application services that shouldn't be monitored
    "ixo_trading_bot_server",
    "hermes",
    "ixo_registry_server",
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
    "matrix_admin"
  ]

  vault_mount_path = var.vault_core_mount
  
  # IXO DNS Entries - extract from application configs
  dns_for_environment = {
    for env, env_config in var.environments : env => {
      for service, config in env_config.application_configs : service => config.enabled ? (
        config.dns_prefix != null ? (
          env == "mainnet" ? "${config.dns_prefix}.${var.domains[config.domain]}" : "${config.dns_prefix}.${env}.${var.domains[config.domain]}"
        ) : config.dns_endpoint != null ? config.dns_endpoint : null
      ) : null
    }
  }

  # Helper function to get domain from application config
  get_domain = {
    for env, env_config in var.environments : env => {
      for service, config in env_config.application_configs : service => config.enabled && config.domain != null ? var.domains[config.domain] : null
    }
  }

  storage_class_for_environment = {
    for env, env_config in var.environments : env => {
      for service, config in env_config.application_configs : service => config.enabled && config.storage_class != null ? config.storage_class : null
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

  registry_server_hosts = terraform.workspace == "testnet" ? [
    {
      host = local.dns_for_environment[terraform.workspace]["ixo_registry_server"]
      paths = [{
        path     = "/"
        pathType = "Prefix"
      }]
    },
    {
      host = "${terraform.workspace}.api.${var.domains[var.environments[terraform.workspace].application_configs["ixo_registry_server"].domain]}"
      paths = [{
        path     = "/"
        pathType = "Prefix"
      }]
    }
    ] : terraform.workspace == "mainnet" ? [
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
      host = "${terraform.workspace}.api.${var.domains[var.environments[terraform.workspace].application_configs["ixo_registry_server"].domain]}"
      paths = [{
        path     = "/"
        pathType = "Prefix"
      }]
    }
  ]
  cellnode_tls_hostnames = [for host in local.cellnode_hosts : host.host]
  registry_server_tls    = [for host in local.registry_server_hosts : host.host]
  
  # Vultr
  region_ids = { for city, id in var.region_ids : id => city }

  # Helm
  helm_values_config_path = "${path.root}/config/yml/helm_values"

  # Postgres Operator
  postgres_operator_config_path = "${path.root}/config/yml/postgres-operator"
  pg_users_usernames            = [for user in var.pg_ixo.pg_users : user.username]
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
- group: ""
  kind: Service
  jsonPointers:
    - /spec/ports
- group: admissionregistration.k8s.io
  kind: ValidatingWebhookConfiguration
  jsonPointers:
    - /webhooks
EOT
}
