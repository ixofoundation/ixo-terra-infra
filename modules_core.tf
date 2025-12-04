resource "kubernetes_secret_v1" "repository" { // Common ArgoCD Git Repository for Core modules.
  metadata {
    name      = "ixo"
    namespace = kubernetes_namespace_v1.ixo_core.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" : "repository"
    }
  }
  data = {
    type : "git"
    url : var.ixo_helm_chart_repository
    githubAppID : 1
    githubAppInstallationID : 2
  }
}

module "ixo_cellnode" {
  count  = var.environments[terraform.workspace].application_configs["ixo_cellnode"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-cellnode"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-cellnode"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-cellnode.yml",
      {
        environment = terraform.workspace
        hosts       = yamlencode(local.cellnode_hosts)
        tls_hosts   = yamlencode(local.cellnode_tls_hostnames)
        rpc_url     = var.environments[terraform.workspace].rpc_url
        vault_mount = local.vault_mount_path
        pgUsername  = var.pg_ixo.pg_users[1].username
        pgPassword  = urlencode(module.postgres-operator[0].database_password[var.pg_ixo.pg_users[1].username])
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_matrix_state_bot" {
  count      = var.environments[terraform.workspace].application_configs["ixo_matrix_state_bot"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name       = "ixo-matrix-state-bot"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-matrix-state-bot"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-matrix-state-bot.yml",
      {
        host       = local.dns_for_environment[terraform.workspace]["ixo_matrix_state_bot"]
        gcs_bucket = "${google_storage_bucket.matrix_backups[0].url}/bot/state"
        storage_class = local.storage_class_for_environment[terraform.workspace]["ixo_matrix_state_bot"]
        storage_size = local.storage_size_for_environment[terraform.workspace]["ixo_matrix_state_bot"]
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_blocksync_core" {
  count  = var.environments[terraform.workspace].application_configs["ixo_blocksync_core"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-blocksync-core"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-blocksync-core"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-blocksync-core.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["ixo_blocksync_core"]
        vault_mount = local.vault_mount_path
      }
    )
  }
  create_kv        = true
  kv_defaults = {
    "DATABASE_URL" = "postgresql://${var.pg_ixo.pg_users[2].username}:${urlencode(module.postgres-operator[0].database_password[var.pg_ixo.pg_users[2].username])}@${var.pg_ixo.pg_cluster_name}-primary.${kubernetes_namespace_v1.ixo-postgres.metadata[0].name}.svc.cluster.local/${var.pg_ixo.pg_users[2].username}"
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_memory_engine" {
  count  = var.environments[terraform.workspace].application_configs["ixo_memory_engine"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-memory-engine"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/memory-engine"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_memory_engine.yml",
      {
        environment = terraform.workspace
        vault_mount = local.vault_mount_path
        neo4j_uri = "neo4j://neo4j.neo4j.svc.cluster.local"
        neo4j_port = "7687"
        neo4j_user = "neo4j"
        neo4j_password = random_password.neo4j_password.result
        host = local.dns_for_environment[terraform.workspace]["ixo_memory_engine"]
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_memory_engine_graphiti" {
  count  = var.environments[terraform.workspace].application_configs["ixo_memory_engine_graphiti"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-memory-engine-graphiti"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/memory-engine-graphiti"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_memory_engine_graphiti.yml",
      {
        environment = terraform.workspace
        vault_mount = local.vault_mount_path
        neo4j_uri = "neo4j://neo4j.neo4j.svc.cluster.local"
        neo4j_port = "7687"
        neo4j_user = "neo4j"
        neo4j_password = random_password.neo4j_password.result
        host = local.dns_for_environment[terraform.workspace]["ixo_memory_engine_graphiti"]
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_companion" {
  count  = var.environments[terraform.workspace].application_configs["ixo_companion"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-companion"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/companion-app"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_companion.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_companion"]
        vault_mount = local.vault_mount_path
        firecrawl_mcp_url = terraform.workspace == "devnet" ? "http://ixo-firecrawl-ixo-firecrawler-mcp.core.svc.cluster.local:3001/mcp" : "https://mcp-firecrawl.devnet.ixo.earth/mcp"
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_blocksync" {
  count  = var.environments[terraform.workspace].application_configs["ixo_blocksync"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-blocksync"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-blocksync"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-blocksync.yml",
      {
        environment          = terraform.workspace
        vault_mount          = local.vault_mount_path
        rpc_url              = var.environments[terraform.workspace].rpc_url
        ipfs_service_mapping = var.environments[terraform.workspace].ipfs_service_mapping
        host                 = local.dns_for_environment[terraform.workspace]["ixo_blocksync"]
        pgCluster            = var.pg_ixo.pg_cluster_name
        pgNamespace          = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername_core      = var.pg_ixo.pg_users[2].username
        pgPassword_core      = urlencode(module.postgres-operator[0].database_password[var.pg_ixo.pg_users[2].username])
      }
    )
  }
  create_kv = true
  kv_defaults = {
    "DATABASE_URL" = "postgresql://${var.pg_ixo.pg_users[3].username}:${urlencode(module.postgres-operator[0].database_password[var.pg_ixo.pg_users[3].username])}@${var.pg_ixo.pg_cluster_name}-primary.${kubernetes_namespace_v1.ixo-postgres.metadata[0].name}.svc.cluster.local/${var.pg_ixo.pg_users[3].username}"
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "credentials_prospect" {
  count  = var.environments[terraform.workspace].application_configs["claims_credentials_prospect"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "claims-credentials-prospect"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/emerging-claims-credentials"
    values_override = templatefile("${local.helm_values_config_path}/core-values/claims_credentials_prospect.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["claims_credentials_prospect"]
        vault_mount = local.vault_mount_path
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ecs" {
  count  = var.environments[terraform.workspace].application_configs["claims_credentials_ecs"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "claims-credentials-ecs"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/emerging-claims-credentials"
    values_override = templatefile("${local.helm_values_config_path}/core-values/claims_credentials_ecs.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["claims_credentials_ecs"]
        vault_mount = local.vault_mount_path
        cellnode    = terraform.workspace == "mainnet" ? "https://${local.dns_for_environment[terraform.workspace]["ixo_cellnode"]}" : "http://ixo-cellnode.core.svc.cluster.local:5000" #todo remove
      }
    )
  }
  create_kv = true
  kv_defaults = {
    "REMOTE_CONTEXTS" = "[ \"https://w3id.org/ixo/context/v1\" ]" # TODO this can be moved to an application config in future.
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "carbon" {
  count  = var.environments[terraform.workspace].application_configs["claims_credentials_carbon"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "claims-credentials-carbon"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/emerging-claims-credentials"
    values_override = templatefile("${local.helm_values_config_path}/core-values/claims_credentials_carbon.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["claims_credentials_carbon"]
        vault_mount = local.vault_mount_path
        cellnode    = terraform.workspace == "mainnet" ? "https://${local.dns_for_environment[terraform.workspace]["ixo_cellnode"]}" : "http://ixo-cellnode.core.svc.cluster.local:5000" #todo remove
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "claimformprotocol" {
  count  = var.environments[terraform.workspace].application_configs["claims_credentials_claimformprotocol"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "claims-credentials-claimformprotocol"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/emerging-claims-credentials"
    values_override = templatefile("${local.helm_values_config_path}/core-values/claims_credentials_claimformprotocol.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["claims_credentials_claimformprotocol"]
        vault_mount = local.vault_mount_path
        cellnode    = terraform.workspace == "mainnet" ? "https://${local.dns_for_environment[terraform.workspace]["ixo_cellnode"]}" : "http://ixo-cellnode.core.svc.cluster.local:5000" #todo remove
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "umuzi" {
  count  = var.environments[terraform.workspace].application_configs["claims_credentials_umuzi"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "claims-credentials-umuzi"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/emerging-claims-credentials"
    values_override = templatefile("${local.helm_values_config_path}/core-values/claims_credentials_umuzi.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["claims_credentials_umuzi"]
        vault_mount = local.vault_mount_path
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "did" {
  count  = var.environments[terraform.workspace].application_configs["claims_credentials_did"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "claims-credentials-did"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/emerging-claims-credentials"
    values_override = templatefile("${local.helm_values_config_path}/core-values/claims_credentials_did.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["claims_credentials_did"]
        vault_mount = local.vault_mount_path
        cellnode    = terraform.workspace == "mainnet" ? "https://${local.dns_for_environment[terraform.workspace]["ixo_cellnode"]}" : "http://ixo-cellnode.core.svc.cluster.local:5000" #todo remove
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_feegrant_nest" {
  count  = var.environments[terraform.workspace].application_configs["ixo_feegrant_nest"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-feegrant-nest"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-feegrant-nest"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_feegrant_nest.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["ixo_feegrant_nest"]
        vault_mount = local.vault_mount_path
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_payments_nest" {
  count  = var.environments[terraform.workspace].application_configs["ixo_payments_nest"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-payments-nest"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-payments-nest"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_payments_nest.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["ixo_payments_nest"]
        vault_mount = local.vault_mount_path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[12].username
        pgPassword  = urlencode(module.postgres-operator[0].database_password[var.pg_ixo.pg_users[12].username])
      }
    )
  }
  create_kv = true
  kv_defaults = {
    AUTHORIZATION                           = ""
    BLOCKSYNC_URL                           = ""
    STRIPE_API_KEY                          = ""
    STRIPE_WEBHOOK_SECRET                   = ""
    NOTIFICATIONS_WORKER_URL                = ""
    NOTIFICATIONS_WORKER_AUTH               = ""
    RPC_URL                                 = ""
    MNEMONIC                                = ""
    NETWORK                                 = ""
    CRYPTOCOM_WEBHOOK_SECRET                = ""
    SENTRY_DSN                              = ""
    COLLECTIONS_TO_SELL                     = ""
    COLLECTIONS_TO_SELL_END_DATE_ADD_MONTHS = ""
    TOKENS_TO_SELL                          = ""
    TOKENS_TO_SELL_COLLECTIONS              = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_did_resolver" {
  count  = var.environments[terraform.workspace].application_configs["ixo_did_resolver"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-did-resolver"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-did-resolver"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_did_resolver.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["ixo_did_resolver"] # "resolver.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
        vault_mount = local.vault_mount_path
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_faucet" {
  count  = var.environments[terraform.workspace].application_configs["ixo_faucet"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-faucet"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-faucet"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_faucet.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["ixo_faucet"] #"faucet.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
        vault_mount = local.vault_mount_path
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_deeplink_server" {
  count  = var.environments[terraform.workspace].application_configs["ixo_deeplink_server"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-deeplink-server"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-deeplink-server"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_deeplink_server.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_deeplink_server"] #"faucet.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
        vault_mount = local.vault_mount_path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[4].username
        pgPassword  = urlencode(module.postgres-operator[0].database_password[var.pg_ixo.pg_users[4].username])
      }
    )
  }
  create_kv = true
  kv_defaults = {
    AUTHORIZATION        = ""
    BASE_URL             = ""
    REDIRECT_URL         = ""
    ANDROID_REDIRECT_URL = ""
    IOS_REDIRECT_URL     = ""
    FALLBACK_URL         = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_kyc_server" {
  count  = var.environments[terraform.workspace].application_configs["ixo_kyc_server"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-kyc-server"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-kyc-server"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_kyc_server.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["ixo_kyc_server"]
        vault_mount = local.vault_mount_path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[5].username
        pgPassword  = urlencode(module.postgres-operator[0].database_password[var.pg_ixo.pg_users[5].username])
      }
    )
  }
  create_kv = true
  kv_defaults = {
    AUTHORIZATION               = ""
    COMPLYCUBE_API_KEY          = ""
    COMPLYCUBE_WEBHOOK_SECRET   = ""
    WEBVIEW_BASE_URL            = ""
    ORACLE_DID                  = ""
    CREDENTIALS_WORKER_API_KEY  = ""
    CREDENTIALS_WORKER_URL      = ""
    ORACLE_DELEGATOR_ADDRESS    = ""
    ORACLE_DELEGATE_MNEMONIC    = ""
    NOTIFICATION_SERVER_API_KEY = ""
    SLACK_WEBHOOK_URL           = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_redirects" {
  source          = "./modules/ixo_redirects"
  nginx_namespace = kubernetes_namespace_v1.ingress_nginx.metadata[0].name
}

module "ixo_matrix_appservice_rooms" {
  count  = var.environments[terraform.workspace].application_configs["ixo_matrix_appservice_rooms"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-matrix-appservice-rooms"
    namespace  = kubernetes_namespace_v1.matrix.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-matrix-appservice-rooms"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_matrix_appservice_rooms.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_matrix_appservice_rooms"]
        vault_mount = local.vault_mount_path
        gcs_bucket  = "${google_storage_bucket.matrix_backups[0].url}/bot/rooms"
        storage_class = local.storage_class_for_environment[terraform.workspace]["ixo_matrix_appservice_rooms"]
        storage_size = local.storage_size_for_environment[terraform.workspace]["ixo_matrix_appservice_rooms"]
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_matrix_bids_bot" {
  count  = var.environments[terraform.workspace].application_configs["ixo_matrix_bids_bot"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-matrix-bids-bot"
    namespace  = kubernetes_namespace_v1.matrix.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/ixo-matrix-bids-bot"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_matrix_bids_bot.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_matrix_bids_bot"]
        vault_mount = local.vault_mount_path
        gcs_bucket  = "${google_storage_bucket.matrix_backups[0].url}/bot/bids"
        storage_class = local.storage_class_for_environment[terraform.workspace]["ixo_matrix_bids_bot"]
        storage_size = local.storage_size_for_environment[terraform.workspace]["ixo_matrix_bids_bot"]
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_matrix_supamoto_bot" {
  count  = var.environments[terraform.workspace].application_configs["ixo_matrix_supamoto_bot"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-matrix-supamoto-bot"
    namespace  = kubernetes_namespace_v1.matrix.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/ixo-matrix-supamoto-bot"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_matrix_supamoto_bot.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_matrix_supamoto_bot"]
        vault_mount = local.vault_mount_path
        storage_size = local.storage_size_for_environment[terraform.workspace]["ixo_matrix_supamoto_bot"]
        storage_class = local.storage_class_for_environment[terraform.workspace]["ixo_matrix_supamoto_bot"]
        gcs_bucket  = "${google_storage_bucket.matrix_backups[0].url}/bot/supamoto"
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_matrix_supamoto_onboarding_server" {
  count  = var.environments[terraform.workspace].application_configs["ixo_matrix_supamoto_onboarding_server"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-matrix-supamoto-onboarding-server"
    namespace  = kubernetes_namespace_v1.matrix.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/ixo-supamoto-onboarding-server"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_matrix_supamoto_onboarding_server.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_matrix_supamoto_onboarding_server"]
        vault_mount = local.vault_mount_path
        storage_class = local.storage_class_for_environment[terraform.workspace]["ixo_matrix_supamoto_onboarding_server"]
        storage_size = local.storage_size_for_environment[terraform.workspace]["ixo_matrix_supamoto_onboarding_server"]
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_domain_indexer" {
  count  = var.environments[terraform.workspace].application_configs["ixo_domain_indexer"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-domain-indexer"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/domain-indexer"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_domain_indexer.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_domain_indexer"]
        vault_mount = local.vault_mount_path
        firecrawl_api_url = terraform.workspace == "devnet" ? "http://ixo-firecrawl-ixo-firecrawler-api.core.svc.cluster.local:3002" : "https://firecrawl.devnet.ixo.earth"
      }
    )
  }
  create_kv = true
  kv_defaults = {
    SURREAL_USER       = "admin"
    SURREAL_PASS       = random_password.surrealdb_password.result
    OPENAI_API_KEY     = ""
    MAPS_API_KEY       = ""
    FIRECRAWL_API_KEY  = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_firecrawl" {
  count  = var.environments[terraform.workspace].application_configs["ixo_firecrawl"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-firecrawl"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/ixo-firecrawl"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_firecrawl.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_firecrawl"]
        vault_mount = local.vault_mount_path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[20].username
        pgPassword  = urlencode(module.postgres-operator[0].database_password[var.pg_ixo.pg_users[20].username])
        redis_host  = "redis-master.redis.svc.cluster.local"
        redis_port  = "6379"
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_matrix_supamoto_claims_bot" {
  count  = var.environments[terraform.workspace].application_configs["ixo_matrix_supamoto_claims_bot"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-matrix-supamoto-claims-bot"
    namespace  = kubernetes_namespace_v1.matrix.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/ixo-matrix-supamoto-claims-bot"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_matrix_supamoto_claims_bot.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_matrix_supamoto_claims_bot"]
        vault_mount = local.vault_mount_path
        gcs_bucket  = "${google_storage_bucket.matrix_backups[0].url}/bot/supamoto-claims"
        storage_class = local.storage_class_for_environment[terraform.workspace]["ixo_matrix_supamoto_claims_bot"]
        storage_size  = local.storage_size_for_environment[terraform.workspace]["ixo_matrix_supamoto_claims_bot"]
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "minerva_oracle" {
  count  = var.environments[terraform.workspace].application_configs["ixo_minerva_oracle"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-minerva-oracle"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/minerva-app"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_minerva_oracle.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_minerva_oracle"]
        vault_mount = local.vault_mount_path
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_minerva_livekit" {
  count  = var.environments[terraform.workspace].application_configs["ixo_minerva_livekit"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-minerva-livekit"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/minerva-livekit"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_minerva_livekit.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_minerva_livekit"]
        vault_mount = local.vault_mount_path
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_matrix_claims_bot" {
  count  = var.environments[terraform.workspace].application_configs["ixo_matrix_claims_bot"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-matrix-claims-bot"
    namespace  = kubernetes_namespace_v1.matrix.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/ixo-matrix-claims-bot"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_matrix_claims_bot.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_matrix_claims_bot"]
        vault_mount = local.vault_mount_path
        gcs_bucket  = "${google_storage_bucket.matrix_backups[0].url}/bot/claims"
        storage_class = local.storage_class_for_environment[terraform.workspace]["ixo_matrix_claims_bot"]
        storage_size = local.storage_size_for_environment[terraform.workspace]["ixo_matrix_claims_bot"]
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_faq_assistant" {
  count  = var.environments[terraform.workspace].application_configs["ixo_faq_assistant"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-faq-assistant"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/faq-assistant"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-faq-assistant.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_faq_assistant"]
        vault_mount = local.vault_mount_path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[7].username
        pgPassword  = module.postgres-operator[0].database_password[var.pg_ixo.pg_users[7].username]
      }
    )
  }
  create_kv = true
  kv_defaults = {
    OPEN_AI_API_KEY = ""

    AIRTABLE_API_KEY        = ""
    AIRTABLE_FAQ_TABLE_NAME = ""

    FAQ_ASSISTANCE_API_TOKEN = ""

    SLACK_SIGNING_SECRET  = ""
    SLACK_BOT_TOKEN       = ""
    BOT_OAUTH_TOKEN       = ""
    SLACK_APP_LEVEL_TOKEN = ""

    LANGCHAIN_TRACING_V2           = ""
    LANGCHAIN_API_KEY              = ""
    LANGCHAIN_CALLBACKS_BACKGROUND = ""
    LANGCHAIN_PROJECT              = ""

    PINECONE_INDEX   = ""
    PINECONE_API_KEY = ""

    QSTASH_URL                 = ""
    QSTASH_TOKEN               = ""
    QSTASH_CURRENT_SIGNING_KEY = ""
    QSTASH_NEXT_SIGNING_KEY    = ""
    REDIS_URL                  = ""
    REDIS_TOKEN                = ""
    QUEUE_CALLBACK_Root_Path   = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_guru" {
  count  = var.environments[terraform.workspace].application_configs["ixo_guru"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-guru"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-guru"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-guru.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_guru"]
        vault_mount = local.vault_mount_path
      }
    )
  }
  create_kv = true
  kv_defaults = {
    SLACK_SIGNING_SECRET  = ""
    SLACK_BOT_TOKEN       = ""
    BOT_OAUTH_TOKEN       = ""
    USER_OAUTH_TOKEN      = ""
    SLACK_APP_LEVEL_TOKEN = ""

    API_KEY                    = ""
    QUEUE_CALLBACK_Root_Path   = ""
    QSTASH_URL                 = ""
    QSTASH_TOKEN               = ""
    QSTASH_CURRENT_SIGNING_KEY = ""
    QSTASH_NEXT_SIGNING_KEY    = ""
    REDIS_URL                  = ""

    AITABLE_BASE_TABLE_LINK = ""

    AIRTABLE_API_KEY = ""
    AIRTABLE_BASE_ID = ""

    OPENAI_API_KEY = ""

    PINECONE_API_KEY = ""
    PINECONE_INDEX   = ""

    LANGCHAIN_TRACING_V2 = ""
    LANGCHAIN_ENDPOINT   = ""
    LANGCHAIN_API_KEY    = ""
    LANGCHAIN_PROJECT    = ""

    MATRIX_BASE_URL                  = ""
    MATRIX_ORACLE_ADMIN_PASSWORD     = ""
    MATRIX_ORACLE_ADMIN_ACCESS_TOKEN = ""
    MATRIX_ORACLE_ADMIN_USER_ID      = ""
    MATRIX_ORACLE_ADMIN_DEVICE_ID    = ""
    MATRIX_TOKEN_KEY                 = ""
    TAVILY_API_KEY                   = ""
    NODE_ENV                         = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_guru_temp" {
  count  = var.environments[terraform.workspace].application_configs["ixo_ai_oracles_guru"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-ai-oracles-guru"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/ixo-ai-oracles-guru"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-ai-oracles-guru.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_ai_oracles_guru"]
        vault_mount = local.vault_mount_path
      }
    )
  }
  create_kv = true
  kv_defaults = {
    SLACK_SIGNING_SECRET  = ""
    SLACK_BOT_TOKEN       = ""
    BOT_OAUTH_TOKEN       = ""
    USER_OAUTH_TOKEN      = ""
    SLACK_APP_LEVEL_TOKEN = ""

    API_KEY                    = ""
    QUEUE_CALLBACK_Root_Path   = ""
    QSTASH_URL                 = ""
    QSTASH_TOKEN               = ""
    QSTASH_CURRENT_SIGNING_KEY = ""
    QSTASH_NEXT_SIGNING_KEY    = ""
    REDIS_URL                  = ""

    AITABLE_BASE_TABLE_LINK = ""

    AIRTABLE_API_KEY = ""
    AIRTABLE_BASE_ID = ""

    OPENAI_API_KEY = ""

    PINECONE_API_KEY = ""
    PINECONE_INDEX   = ""

    LANGCHAIN_TRACING_V2 = ""
    LANGCHAIN_ENDPOINT   = ""
    LANGCHAIN_API_KEY    = ""
    LANGCHAIN_PROJECT    = ""

    MATRIX_BASE_URL                  = ""
    MATRIX_ORACLE_ADMIN_PASSWORD     = ""
    MATRIX_ORACLE_ADMIN_ACCESS_TOKEN = ""
    MATRIX_ORACLE_ADMIN_USER_ID      = ""
    MATRIX_ORACLE_ADMIN_DEVICE_ID    = ""
    MATRIX_ORACLE_USER_TOKEN         = ""
    MATRIX_TOKEN_KEY                 = ""
    TAVILY_API_KEY                   = ""
    NODE_ENV                         = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_giza_oracle" {
  count  = var.environments[terraform.workspace].application_configs["ixo_ai_oracles_giza"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-ai-oracles-giza"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/ixo-ai-oracles-giza"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-ai-oracles-giza.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_ai_oracles_giza"]
        vault_mount = local.vault_mount_path
      }
    )
  }
  create_kv = true
  kv_defaults = {
    SLACK_SIGNING_SECRET  = ""
    SLACK_BOT_TOKEN       = ""
    BOT_OAUTH_TOKEN       = ""
    USER_OAUTH_TOKEN      = ""
    SLACK_APP_LEVEL_TOKEN = ""

    API_KEY   = ""
    REDIS_URL = ""

    AITABLE_BASE_TABLE_LINK = ""

    AIRTABLE_API_KEY = ""
    AIRTABLE_BASE_ID = ""

    OPENAI_API_KEY = ""

    PINECONE_API_KEY = ""
    PINECONE_INDEX   = ""

    LANGCHAIN_TRACING_V2 = ""
    LANGCHAIN_ENDPOINT   = ""
    LANGCHAIN_API_KEY    = ""
    LANGCHAIN_PROJECT    = ""

    MATRIX_BASE_URL                  = ""
    MATRIX_ORACLE_ADMIN_PASSWORD     = ""
    MATRIX_ORACLE_ADMIN_ACCESS_TOKEN = ""
    MATRIX_ORACLE_ADMIN_USER_ID      = ""
    MATRIX_ORACLE_ADMIN_DEVICE_ID    = ""
    MATRIX_ORACLE_USER_TOKEN         = ""
    MATRIX_TOKEN_KEY                 = ""
    TAVILY_API_KEY                   = ""
    BLOCKSYNC_GRAPHQL_URL            = ""
    SUPAMOTO_API_KEY                 = ""
    GIZA_API_URL                     = ""
    GIZA_PROVING_JOBS_API_URL        = ""
    CRON_JOBS                        = "true"
    ISSUER_DID                       = ""
    CREDENTIALS_MNEMONIC             = ""
    CELLNODE_URL                     = ""
    RPC_URL                          = ""
    SECP_MNEMONIC                    = ""
    NETWORK                          = ""
    NODE_ENV                         = ""
    ALLOW_SLACK_BOT                  = ""
    GIZA_DRY_RUN                     = ""
    ORACLE_ENTITY_DID                = ""
    ORACLE_PROTOCOL_CLAIM_DID        = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_trading_bot_server" {
  count  = var.environments[terraform.workspace].application_configs["ixo_trading_bot_server"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-trading-bot-server"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-trading-bot-server"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-trading-bot-server.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_trading_bot_server"]
        vault_mount = local.vault_mount_path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[11].username
        pgPassword  = urlencode(module.postgres-operator[0].database_password[var.pg_ixo.pg_users[11].username])
        rpc_url     = var.environments[terraform.workspace].rpc_url
      }
    )
  }
  create_kv = true
  kv_defaults = {
    POOL_ADDRESSES        = ""
    MNEMONICS             = ""
    EXECUTE_RANDOM_TRADES = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_subscriptions_oracle" {
  count  = var.environments[terraform.workspace].application_configs["ixo_subscriptions_oracle"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-subscriptions-oracle"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/subscriptions-oracle"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-subscriptions-oracle.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_subscriptions_oracle"]
        vault_mount = local.vault_mount_path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[11].username
        pgPassword  = urlencode(module.postgres-operator[0].database_password[var.pg_ixo.pg_users[11].username])
        rpc_url     = var.environments[terraform.workspace].rpc_url
      }
    )
  }
  create_kv = true
  kv_defaults = {
    STRIPE_API_KEY        = ""
    CHAIN_NETWORK             = ""
    ALLOWED_STRIPE_PLANS = ""
    BLOCKSYNC_GRAPHQL_URL = ""
    SUBSCRIPTION_PROTOCOL_DID = ""
    ORACLE_SERVICE_CLAIM_COLLECTION_PROTOCOL_DID = ""
    SUBSCRIPTION_SERVICE_CLAIM_COLLECTION_PROTOCOL_DID = ""
    RPC_URL = ""
    SECP_MNEMONIC = ""
    DID = ""
    RELAYER_NODE = ""
    MATRIX_ACCESS_TOKEN = ""
    STRIPE_WEBHOOK_SECRET = ""
    STRIPE_PRO_PLAN_ID = ""
    STRIPE_TEAM_PLAN_ID = ""
    STRIPE_ECOSYSTEM_PLAN_ID = ""
    STRIPE_TOP_UP_1500_PLAN_ID = ""
    STRIPE_TRIAL_PERIOD_DAYS = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_subscriptions_oracle_bot" {
  count  = var.environments[terraform.workspace].application_configs["ixo_subscriptions_oracle_bot"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-subscriptions-oracle-bot"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/subscription-oracle-bot-app"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-subscriptions-oracle-bot.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_subscriptions_oracle_bot"]
        vault_mount = local.vault_mount_path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[14].username
        pgPassword  = module.postgres-operator[0].database_password[var.pg_ixo.pg_users[14].username]
      }
    )
  }
  create_kv = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_pathgen_oracle" {
  count  = var.environments[terraform.workspace].application_configs["ixo_pathgen_oracle"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-pathgen-oracle"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/pathgen-oracle-app"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-pathgen-oracle.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_pathgen_oracle"]
        vault_mount = local.vault_mount_path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[16].username
        pgPassword  = module.postgres-operator[0].database_password[var.pg_ixo.pg_users[16].username]  
      }
    )
  }
  create_kv = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_website_bot_oracle" {
  count  = var.environments[terraform.workspace].application_configs["ixo_website_bot_oracle"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-website-bot-oracle"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/website-bot-oracle-app"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-website-bot-oracle.yml",
      {
        environment = terraform.workspace
        vault_mount = local.vault_mount_path
        host        = local.dns_for_environment[terraform.workspace]["ixo_website_bot_oracle"]
      }
    )
  }
  create_kv = true
  kv_defaults = {
    ORACLE_NAME = "website-bot-oracle"
    MATRIX_BASE_URL = ""
    MATRIX_ORACLE_ADMIN_ACCESS_TOKEN = ""
    MATRIX_ORACLE_ADMIN_PASSWORD = ""
    MATRIX_ORACLE_ADMIN_USER_ID = ""
    MATRIX_RECOVERY_PHRASE = ""
    LANGFUSE_PUBLIC_KEY = ""
    LANGFUSE_SECRET_KEY = ""
    LANGFUSE_HOST = ""
    OPEN_ROUTER_API_KEY = ""
    ORACLE_ROOM_ID = ""
    AIRTABLE_API_KEY = ""
    AIRTABLE_BASE_ID = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_jokes_oracle" {
  count  = var.environments[terraform.workspace].application_configs["ixo_jokes_oracle"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-jokes-oracle"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/jokes-oracle-app"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-jokes-oracle.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_jokes_oracle"]
        vault_mount = local.vault_mount_path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[17].username
        pgPassword  = module.postgres-operator[0].database_password[var.pg_ixo.pg_users[17].username]
      }
    )
    create_kv = true
    argo_namespace = module.argocd.argo_namespace
    vault_mount_path = local.vault_mount_path
  }
  create_kv = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_whizz" {
  count  = var.environments[terraform.workspace].application_configs["ixo_whizz"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-whizz"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-whizz"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-whizz.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_whizz"]
        vault_mount = local.vault_mount_path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[8].username
        pgPassword  = module.postgres-operator[0].database_password[var.pg_ixo.pg_users[8].username]
      }
    )
  }
  create_kv = true
  kv_defaults = {
    OPEN_AI_API_KEY = ""

    AIRTABLE_API_KEY              = ""
    AIRTABLE_Marketing_TABLE_NAME = ""

    GURU_ASSISTANCE_API_TOKEN = ""
    IXO_GURU_API_URL          = ""
    MARKETING_GURU_API_TOKEN  = ""

    SLACK_SIGNING_SECRET  = ""
    SLACK_BOT_TOKEN       = ""
    BOT_OAUTH_TOKEN       = ""
    SLACK_APP_LEVEL_TOKEN = ""

    LANGCHAIN_TRACING_V2           = ""
    LANGCHAIN_API_KEY              = ""
    LANGCHAIN_CALLBACKS_BACKGROUND = ""
    LANGCHAIN_PROJECT              = ""

    PINECONE_INDEX   = ""
    PINECONE_API_KEY = ""

    QSTASH_URL                 = ""
    QSTASH_TOKEN               = ""
    QSTASH_CURRENT_SIGNING_KEY = ""
    QSTASH_NEXT_SIGNING_KEY    = ""
    REDIS_URL                  = ""
    REDIS_TOKEN                = ""
    QUEUE_CALLBACK_Root_Path   = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_coin_server" {
  count  = var.environments[terraform.workspace].application_configs["ixo_coin_server"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-coin-server"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-coin-server"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-coin-server.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_coin_server"]
        vault_mount = local.vault_mount_path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[6].username
        pgPassword  = urlencode(module.postgres-operator[0].database_password[var.pg_ixo.pg_users[6].username])
      }
    )
  }
  create_kv = true
  kv_defaults = {
    AUTHORIZATION     = ""
    COINGECKO_API_KEY = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_stake_reward_claimer" {
  count  = var.environments[terraform.workspace].application_configs["ixo_stake_reward_claimer"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-stake-reward-claimer"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-stake-reward-claimer"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-stake-reward-claimer.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_stake_reward_claimer"]
        vault_mount = local.vault_mount_path
        rpc_url     = var.environments[terraform.workspace].rpc_url
      }
    )
  }
  create_kv = true
  kv_defaults = {
    AUTHORIZATION = ""
    SENTRYDSN     = ""
    MNEMONIC      = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_offset_auto_approve" {
  count  = var.environments[terraform.workspace].application_configs["auto_approve_offset"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "auto-approve-offset"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-auto-approve-agent"
    values_override = templatefile("${local.helm_values_config_path}/core-values/auto_approve_offset.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["auto_approve_offset"]
        vault_mount = local.vault_mount_path
      }
    )
  }
  create_kv = true
  kv_defaults = {
    AUTHORIZATION              = ""
    BLOCKSYNC_GRAPHQL          = ""
    MNEMONIC_DELEGATE          = ""
    MNEMONIC_OWNER             = ""
    COLLECTION_IDS             = ""
    QUOTAS_PER_COLLECTION      = ""
    EXPIRATION_PER_COLLECTION  = ""
    NOTIFICATIONS_WORKER_AUTH  = ""
    NOTIFICATIONS_TEMPLATE_ID  = ""
    NOTIFICATIONS_TEMPLATE_IDS = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_iot_data" {
  count  = var.environments[terraform.workspace].application_configs["ixo_iot_data"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-iot-data"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-iot-data"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-iot-data.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_iot_data"]
        vault_mount = local.vault_mount_path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[9].username
        pgPassword  = urlencode(module.postgres-operator[0].database_password[var.pg_ixo.pg_users[9].username])
      }
    )
  }
  create_kv = true
  kv_defaults = {
    AUTHORIZATION = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_message_relayer" {
  count  = var.environments[terraform.workspace].application_configs["ixo_message_relayer"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-message-relayer"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-message-relayer"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-message-relayer.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_message_relayer"]
        vault_mount = local.vault_mount_path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[13].username
        pgPassword  = urlencode(module.postgres-operator[0].database_password[var.pg_ixo.pg_users[13].username])
      }
    )
  }
  create_kv = true
  kv_defaults = {
    AUTHORIZATION = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_notification_server" {
  count  = var.environments[terraform.workspace].application_configs["ixo_notification_server"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-notification-server"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-notification-server"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-notification-server.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_notification_server"]
        vault_mount = local.vault_mount_path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[10].username
        pgPassword  = urlencode(module.postgres-operator[0].database_password[var.pg_ixo.pg_users[10].username])
      }
    )
  }
  create_kv = true
  kv_defaults = {
    AUTHORIZATION                   = ""
    AIRTABLE_API_KEY                = ""
    AIRTABLE_BASE_ID                = ""
    AIRTABLE_TABLE_NOTIFICATIONS_V2 = ""
    PUBLIC_AUTHORIZATION            = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "hermes" {
  count  = var.environments[terraform.workspace].application_configs["hermes"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "hermes"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/hermes"
    values_override = templatefile("${local.helm_values_config_path}/core-values/hermes.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["hermes"]
        vault_mount = local.vault_mount_path
      }
    )
  }
  create_kv = true
  kv_defaults = {
    CHAIN_A_RPC_ADDR  = ""
    CHAIN_A_GRPC_ADDR = ""
    CHAIN_B_RPC_ADDR  = ""
    CHAIN_B_GRPC_ADDR = ""

    CHAIN_A_SECRET_KEY = ""
    CHAIN_B_SECRET_KEY = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_cvms_exporter" {
  count  = var.environments[terraform.workspace].application_configs["ixo_cvms_exporter"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-cvms-exporter"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-cvms-exporter"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-cvms-exporter.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_cvms_exporter"]
        vault_mount = local.vault_mount_path
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_dmrv_registry_server" {
  count  = var.environments[terraform.workspace].application_configs["ixo_registry_server"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-registry-server"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/ixo-registry-server"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-registry-server.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_registry_server"]
        vault_mount = local.vault_mount_path
        hosts       = yamlencode(local.registry_server_hosts)
        tls_hosts   = yamlencode(local.registry_server_tls)
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_observable_framework_builder" {
  count  = var.environments[terraform.workspace].application_configs["ixo_observable_framework_builder"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-observable-framework-builder"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/observable-framework-builder"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_observable_framework_builder.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_observable_framework_builder"]
        vault_mount = local.vault_mount_path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[15].username
        pgPassword  = urlencode(module.postgres-operator[0].database_password[var.pg_ixo.pg_users[15].username])
        storage_class = local.storage_class_for_environment[terraform.workspace]["ixo_observable_framework_builder"]
        storage_size = local.storage_size_for_environment[terraform.workspace]["ixo_observable_framework_builder"]
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ixo_agent_images_slack" {
  count  = var.environments[terraform.workspace].application_configs["ixo_agent_images_slack"].enabled ? 1 : 0
  source = "./modules/aws/lambda_function"
  providers = {
    aws = aws
  }

  aws_region        = var.environments[terraform.workspace].aws_region
  github_repo_name  = "agent-images-slack"
  github_repo_org   = "ixoworld"
  function_fileName = "./modules/aws/lambda_function/dummy.zip"
  function_handler  = "worker.lambda_handler"
  function_name     = "agent-images-slack-${terraform.workspace}"
  function_runtime  = "python3.9"
}

module "ixo_aws_iam" {
  count  = var.environments[terraform.workspace].application_configs["ixo_aws_iam"].enabled ? 1 : 0
  source = "./modules/aws/iam_ixo"
  users  = var.environments[terraform.workspace].aws_iam_users
}

#module "ixo_ussd" {
#  count  = var.environments[terraform.workspace].application_configs["ixo_ussd"].enabled ? 1 : 0
#  source = "./modules/argocd_application"
#  application = {
#    name       = "ixo-ussd"
#    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
#    repository = var.ixo_helm_chart_repository
#    path       = "charts/${terraform.workspace}/ixofoundation/ixo-ussd"
#    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-ussd.yml",
#      {
#        environment = terraform.workspace
#        host        = local.dns_for_environment[terraform.workspace]["ixo_ussd"]
#        vault_mount = local.vault_mount_path
#      }
#    )
#  }
#  argo_namespace   = module.argocd.argo_namespace
#  vault_mount_path = local.vault_mount_path
#}

module "ixo_ussd_supamoto" {
  count  = var.environments[terraform.workspace].application_configs["ixo_ussd_supamoto"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-ussd-supamoto"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    repository = var.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/emerging-eco/ixo-ussd-supamoto"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_ussd_supamoto.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_ussd_supamoto"]
        vault_mount = local.vault_mount_path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[21].username
        pgPassword  = urlencode(module.postgres-operator[0].database_password[var.pg_ixo.pg_users[21].username])
      }
    )
  }
  create_kv = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "blocksync_migration" { # Note this will be commented in/out only for new releases to blocksync that require re-indexing the DB.
 depends_on = [module.ixo_blocksync, module.ixo_blocksync_core]
 source     = "./modules/ixo_blocksync_migration"
 db_info = {
   pgUsername  = var.pg_ixo.pg_users[3].username
   pgPassword  = urlencode(module.postgres-operator[0].database_password[var.pg_ixo.pg_users[3].username])
   pgCluster   = var.pg_ixo.pg_cluster_name
   pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
   # This is to determine whether we are indexing blocksync or blocksync_alt for the new version. eg if we are running in `blocksync_alt` then set this to false so we index `blocksync` for the new version.
   # If current DB in-use is `blocksync` set to true. Else if current DB in-use is`blocksync_alt` set to false.
   # true = pod created will run migrations on `blocksync_alt`
   # false = pod created will run migrations on `blocksync`
   useAlt = true
 }
 image = "ghcr.io/ixofoundation/ixo-blocksync:v2.5.0-develop.1"
 existing_blocksync_pod_label_name = "ixo-blocksync"
 env_overrides = {
  RPC = "https://archive.devnet.ixo.earth/rpc/"
 }
 migration_pod_name                = "ixo-blocksync-migration"
 namespace                         = kubernetes_namespace_v1.ixo_core.metadata[0].name
}

# module "blocksyn_core_migration" { # Note this will be commented in/out only for new releases to blocksync-core that require re-indexing the DB.
# #  depends_on = [module.ixo_blocksync, module.ixo_blocksync_core]
#  source     = "./modules/ixo_blocksync_migration"
#  db_info = {
#    pgUsername  = var.pg_ixo.pg_users[2].username
#    pgPassword  = urlencode(module.postgres-operator[0].database_password[var.pg_ixo.pg_users[2].username])
#    pgCluster   = var.pg_ixo.pg_cluster_name
#    pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
#    # This is to determine whether we are indexing blocksync-core or blocksync-core_alt for the new version. eg if we are running in `blocksync-core_alt` then set this to false so we index `blocksync-core` for the new version.
#    # If current DB in-use is `blocksync-core` set to true. Else if current DB in-use is`blocksync-core_alt` set to false.
#    # true = pod created will run migrations on `blocksync-core_alt`
#    # false = pod created will run migrations on `blocksync-core`
#    useAlt = false
#  }
#  image = "ghcr.io/ixofoundation/ixo-blocksync-core:v0.1.0-develop.16"
#  existing_blocksync_pod_label_name = "ixo-blocksync-core"
#  env_overrides = {
#   RPC = "https://archive.impacthub.ixo.earth/rpc/"
#  }
#  migration_pod_name                = "ixo-blocksync-core-migration"
#  namespace                         = kubernetes_namespace_v1.ixo_core.metadata[0].name
# }

#DATABASE_URL : postgresql://cellnode:p^mv%7Bv|+^C^vkXlNoYRuBA)@ixo-postgres-primary.ixo-postgres.svc.cluster.local/cellnode
#DATABASE_URL : postgresql://cellnode:p%5Emv%7Bv%7C%2B%5EC%5EvkXlNoYRuBA%29@ixo-postgres-primary.ixo-postgres.svc.cluster.local/cellnode