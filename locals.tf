locals {
  # IXO
  ixo_helm_chart_repository  = "https://github.com/ixofoundation/ixo-helm-charts"
  ixo_terra_infra_repository = "https://github.com/ixofoundation/ixo-terra-infra"
  vault_core_mount           = "ixo_core"
  synthetic_monitoring_endpoints = concat(
    compact([
      for app, dns_endpoint in local.dns_for_environment[terraform.workspace] :
      contains(local.excluded_synthetic_monitoring, app) || dns_endpoint == null ? null : "https://${dns_endpoint}"
    ]),
    lookup(var.additional_manual_synthetic_monitoring_endpoints, terraform.workspace, [])
  )
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
      ixo_matrix_appservice_rooms = "rooms.bot.${var.hostnames["${terraform.workspace}_matrix"]}"
      ixo_blocksync_core          = "ixo-blocksync-core.${var.hostnames[terraform.workspace]}"
      claims_credentials_prospect = "prospect.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      claims_credentials_ecs      = "ecs.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      claims_credentials_carbon   = "carbon.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      claims_credentials_umuzi    = "umuzi.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      claims_credentials_did      = "didoracle.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_feegrant_nest           = "feegrant.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_did_resolver            = "resolver.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_faucet                  = "faucet.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_deeplink_server         = "deeplink.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_kyc_server              = "kyc.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_faq_assistant           = ""
      ixo_coin_server             = ""
      ixo_stake_reward_claimer    = ""
      ixo_ussd                    = ""
      ixo_whizz                   = ""
      auto_approve_offset         = ""
      ixo_iot_data                = ""
      ixo_notification_server     = ""
    }
    testnet = {
      ixo_cellnode                = "${terraform.workspace}-cellnode.${var.environments[terraform.workspace].domain}"
      ixo_blocksync               = "${terraform.workspace}-blocksync-graphql.${var.environments[terraform.workspace].domain}"
      ixo_matrix_state_bot        = "state.bot.${var.hostnames["${terraform.workspace}_matrix"]}"
      ixo_matrix_appservice_rooms = "rooms.bot.${var.hostnames["${terraform.workspace}_matrix"]}"
      ixo_blocksync_core          = "ixo-blocksync-core.${var.hostnames[terraform.workspace]}"
      claims_credentials_prospect = "prospect.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      claims_credentials_ecs      = "ecs.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      claims_credentials_carbon   = "carbon.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      claims_credentials_did      = "didoracle.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_feegrant_nest           = "feegrant.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_did_resolver            = "resolver.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_faucet                  = "faucet.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_deeplink_server         = "deeplink.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_kyc_server              = "kyc.devnet.${var.environments[terraform.workspace].domain}"
      ixo_faq_assistant           = ""
      ixo_coin_server             = ""
      ixo_stake_reward_claimer    = ""
      ixo_ussd                    = ""
      ixo_whizz                   = ""
      auto_approve_offset         = "offset.auto-approve.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      ixo_iot_data                = ""
      ixo_notification_server     = ""
    }
    mainnet = {
      ixo_cellnode                         = "cellnode.${var.environments[terraform.workspace].domain}"
      ixo_blocksync                        = "blocksync-graphql.${var.environments[terraform.workspace].domain2}"
      ixo_matrix_state_bot                 = "state.bot.${var.hostnames["${terraform.workspace}_matrix"]}"
      ixo_matrix_appservice_rooms          = "rooms.appservice.${var.hostnames["${terraform.workspace}_matrix"]}"
      ixo_blocksync_core                   = "ixo-blocksync-core.${var.hostnames[terraform.workspace]}"
      claims_credentials_prospect          = "prospect.credentials2.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      claims_credentials_ecs               = "ecs.credentials.${var.environments[terraform.workspace].domain}"
      claims_credentials_carbon            = "carbon.credentials.${var.environments[terraform.workspace].domain}"
      claims_credentials_umuzi             = "umuzi.credentials2.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
      claims_credentials_claimformprotocol = "claimformobjects.credentials.${var.environments[terraform.workspace].domain}"
      claims_credentials_did               = "didoracle.credentials.${var.environments[terraform.workspace].domain2}"
      ixo_feegrant_nest                    = "feegrant.${var.environments[terraform.workspace].domain}"
      ixo_did_resolver                     = "resolver.${var.environments[terraform.workspace].domain}"
      ixo_faucet                           = "faucet2.${var.hostnames[terraform.workspace]}"
      ixo_deeplink_server                  = "x.${var.environments[terraform.workspace].domain2}"
      ixo_kyc_server                       = "kyc.oracle.${var.environments[terraform.workspace].domain2}"
      ixo_faq_assistant                    = "faq.assistant.${var.environments[terraform.workspace].domain2}"
      ixo_coin_server                      = "coincache.${var.environments[terraform.workspace].domain2}"
      ixo_stake_reward_claimer             = "reclaim.${var.environments[terraform.workspace].domain2}"
      ixo_ussd                             = ""
      ixo_whizz                            = "whizz.assistant.${var.environments[terraform.workspace].domain2}"
      auto_approve_offset                  = "offset.auto-approve.${var.environments[terraform.workspace].domain2}"
      ixo_iot_data                         = "iot-data.${var.environments[terraform.workspace].domain2}"
      ixo_notification_server              = "notifications.${var.environments[terraform.workspace].domain2}"
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
      host = "cellnode-pandora.${var.environments[terraform.workspace].domain}" # cellnode-pandora.ixo.earth
      paths = [{
        path     = "/"
        pathType = "Prefix"
      }]
    },
    {
      host = "cellnode-pandora.${var.environments["mainnet"].domain}" # cellnode-pandora.ixo.world
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
      host = "cellnode.${var.environments[terraform.workspace].domain2}" # cellnode.ixo.earth
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