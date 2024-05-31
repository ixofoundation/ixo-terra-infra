locals {
  # IXO
  ixo_helm_chart_repository  = "https://github.com/ixofoundation/ixo-helm-charts"
  ixo_terra_infra_repository = "https://github.com/ixofoundation/ixo-terra-infra"
  vault_core_mount           = "ixo_core"
  synthetic_monitoring_endpoints = compact([
    for app, dns_endpoint in local.dns_for_environment[terraform.workspace] :
    contains(local.excluded_synthetic_monitoring, app) || dns_endpoint == null ? null : "https://${dns_endpoint}"
  ])
  excluded_synthetic_monitoring = []
  # IXO DNS Entries
  dns_for_environment = {
    for env, config in var.environments : env => {
      for service, enabled in config.enabled_services : service => enabled ? local.dns_endpoints[env][service] : null
    }
  }

  dns_endpoints = {
    devnet = {
      ixo_cellnode                = "${terraform.workspace}-cellnode.${var.environments[terraform.workspace].domain}"
      ixo_blocksync               = "${terraform.workspace}-blocksync-graphql.${var.environments[terraform.workspace].domain}"
      ixo_matrix_state_bot        = "state.bot.${var.hostnames["${terraform.workspace}_matrix"]}"
      ixo_blocksync_core          = "ixo-blocksync-core.${var.hostnames[terraform.workspace]}"
      claims_credentials_prospect = "prospect.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      claims_credentials_ecs      = "ecs.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      claims_credentials_carbon   = "carbon.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      claims_credentials_umuzi    = "umuzi.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_feegrant_nest           = "feegrant.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_did_resolver            = "resolver.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_faucet                  = "faucet.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
    }
    testnet = {
      ixo_cellnode                = "${terraform.workspace}-cellnode.${var.environments[terraform.workspace].domain}"
      ixo_blocksync               = "${terraform.workspace}-blocksync-graphql2.${var.environments[terraform.workspace].domain}"
      ixo_matrix_state_bot        = "state.bot.${var.hostnames["${terraform.workspace}_matrix"]}"
      ixo_blocksync_core          = "ixo-blocksync-core.${var.hostnames[terraform.workspace]}"
      claims_credentials_prospect = "prospect.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      claims_credentials_ecs      = "ecs.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      claims_credentials_carbon   = "carbon.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_feegrant_nest           = "feegrant.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_did_resolver            = "resolver.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_faucet                  = "faucet.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
    }
    mainnet = {
      ixo_cellnode                = "${terraform.workspace}-cellnode2.${var.environments[terraform.workspace].domain}"
      ixo_blocksync               = "${terraform.workspace}-blocksync-graphql.${var.environments[terraform.workspace].domain}"
      ixo_matrix_state_bot        = "state.bot.${var.hostnames["${terraform.workspace}_matrix"]}"
      ixo_blocksync_core          = "ixo-blocksync-core.${var.hostnames[terraform.workspace]}"
      claims_credentials_prospect = "prospect.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      claims_credentials_ecs      = "ecs.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      claims_credentials_carbon   = "carbon.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      claims_credentials_umuzi    = "umuzi.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_feegrant_nest           = "feegrant.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_did_resolver            = "resolver.${var.hostnames[terraform.workspace]}"
      ixo_faucet                  = "faucet.${var.hostnames[terraform.workspace]}"
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
      host = "cellnode-pandora.${var.environments[terraform.workspace].domain}"
      paths = [{
        path     = "/"
        pathType = "Prefix"
      }]
    },
    {
      host = "cellnode-pandora.${var.environments["main"].domain}"
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
  cellnode_tls_hostnames = [for host in local.cellnode_hosts : host.host]

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
- group: monitoring.coreos.com
  kind: ServiceMonitor
  jqPathExpressions:
    - .metadata.annotations
    - .spec
    - .spec.endpoints[]?.relabelings[]?.action
- group: monitoring.coreos.com
  kind: PodMonitor
  jqPathExpressions:
    - .metadata.annotations
    - .spec
    - .spec.endpoints[]?.relabelings[]?.action
- group: monitoring.coreos.com
  kind: Probes
  jqPathExpressions:
    - .metadata.annotations
    - .spec
    - .spec.endpoints[]?.relabelings[]?.action
EOT
  loki_ignore_differences             = <<EOT
- group: monitoring.coreos.com
  kind: ServiceMonitor
  jqPathExpressions:
    - .metadata.annotations
    - .spec
    - .spec.endpoints[]?.relabelings[]?.action
- group: monitoring.coreos.com
  kind: PodMonitor
  jqPathExpressions:
    - .metadata.annotations
    - .spec
    - .spec.endpoints[]?.relabelings[]?.action
EOT
  vault_ignore_differences            = <<EOT
- group: apps
  kind: StatefulSet
  jqPathExpressions:
    - '.spec.volumeClaimTemplates[]?'
EOT
}