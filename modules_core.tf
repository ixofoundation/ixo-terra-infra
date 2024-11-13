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
    url : local.ixo_helm_chart_repository
    githubAppID : 1
    githubAppInstallationID : 2
  }
}

module "ixo_cellnode" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_cellnode"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-cellnode"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-cellnode.yml",
      {
        environment = terraform.workspace
        hosts       = yamlencode(local.cellnode_hosts)
        tls_hosts   = yamlencode(local.cellnode_tls_hostnames)
        rpc_url     = var.environments[terraform.workspace].rpc_url
        vault_mount = vault_mount.ixo.path
        pgUsername  = var.pg_ixo.pg_users[1].username
        pgPassword  = urlencode(module.postgres-operator.database_password[var.pg_ixo.pg_users[1].username])
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_matrix_state_bot" {
  count      = var.environments[terraform.workspace].enabled_services["ixo_matrix_state_bot"] ? 1 : 0
  depends_on = [kubernetes_persistent_volume_claim_v1.common]
  source     = "./modules/argocd_application"
  application = {
    name       = "ixo-matrix-state-bot"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-matrix-state-bot.yml",
      {
        host       = local.dns_for_environment[terraform.workspace]["ixo_matrix_state_bot"]
        gcs_bucket = "${google_storage_bucket.matrix_backups.url}/bot/state"
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_blocksync_core" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_blocksync_core"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-blocksync-core"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-blocksync-core.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["ixo_blocksync_core"]
        pgUsername  = var.pg_ixo.pg_users[2].username
        pgPassword  = urlencode(module.postgres-operator.database_password[var.pg_ixo.pg_users[2].username])
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_blocksync" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_blocksync"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-blocksync"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-blocksync.yml",
      {
        environment          = terraform.workspace
        vault_mount          = vault_mount.ixo.path
        rpc_url              = var.environments[terraform.workspace].rpc_url
        ipfs_service_mapping = var.environments[terraform.workspace].ipfs_service_mapping
        host                 = local.dns_for_environment[terraform.workspace]["ixo_blocksync"]
        pgCluster            = var.pg_ixo.pg_cluster_name
        pgNamespace          = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername_core      = var.pg_ixo.pg_users[2].username
        pgPassword_core      = urlencode(module.postgres-operator.database_password[var.pg_ixo.pg_users[2].username])
      }
    )
  }
  create_kv = true
  kv_defaults = {
    "DATABASE_URL" = "postgresql://${var.pg_ixo.pg_users[3].username}:${urlencode(module.postgres-operator.database_password[var.pg_ixo.pg_users[3].username])}@${var.pg_ixo.pg_cluster_name}-primary.${kubernetes_namespace_v1.ixo-postgres.metadata[0].name}.svc.cluster.local/${var.pg_ixo.pg_users[3].username}"
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "credentials_prospect" {
  count  = var.environments[terraform.workspace].enabled_services["claims_credentials_prospect"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "claims-credentials-prospect"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/emerging-claims-credentials"
    values_override = templatefile("${local.helm_values_config_path}/core-values/claims_credentials_prospect.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["claims_credentials_prospect"]
        vault_mount = vault_mount.ixo.path
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ecs" {
  count  = var.environments[terraform.workspace].enabled_services["claims_credentials_ecs"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "claims-credentials-ecs"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/emerging-claims-credentials"
    values_override = templatefile("${local.helm_values_config_path}/core-values/claims_credentials_ecs.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["claims_credentials_ecs"]
        vault_mount = vault_mount.ixo.path
        cellnode    = terraform.workspace == "mainnet" ? "https://cellnode.ixo.world" : "http://ixo-cellnode.core.svc.cluster.local:5000" #todo remove
      }
    )
  }
  create_kv = true
  kv_defaults = {
    "REMOTE_CONTEXTS" = "[ \"https://w3id.org/ixo/context/v1\" ]" # TODO this can be moved to an application config in future.
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "carbon" {
  count  = var.environments[terraform.workspace].enabled_services["claims_credentials_carbon"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "claims-credentials-carbon"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/emerging-claims-credentials"
    values_override = templatefile("${local.helm_values_config_path}/core-values/claims_credentials_carbon.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["claims_credentials_carbon"]
        vault_mount = vault_mount.ixo.path
        cellnode    = terraform.workspace == "mainnet" ? "https://cellnode.ixo.world" : "http://ixo-cellnode.core.svc.cluster.local:5000" #todo remove
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "claimformprotocol" {
  count  = var.environments[terraform.workspace].enabled_services["claims_credentials_claimformprotocol"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "claims-credentials-claimformprotocol"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/emerging-claims-credentials"
    values_override = templatefile("${local.helm_values_config_path}/core-values/claims_credentials_claimformprotocol.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["claims_credentials_claimformprotocol"]
        vault_mount = vault_mount.ixo.path
        cellnode    = terraform.workspace == "mainnet" ? "https://cellnode.ixo.world" : "http://ixo-cellnode.core.svc.cluster.local:5000" #todo remove
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "umuzi" {
  count  = var.environments[terraform.workspace].enabled_services["claims_credentials_umuzi"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "claims-credentials-umuzi"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/emerging-claims-credentials"
    values_override = templatefile("${local.helm_values_config_path}/core-values/claims_credentials_umuzi.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["claims_credentials_umuzi"]
        vault_mount = vault_mount.ixo.path
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "did" {
  count  = var.environments[terraform.workspace].enabled_services["claims_credentials_did"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "claims-credentials-did"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/emerging-claims-credentials"
    values_override = templatefile("${local.helm_values_config_path}/core-values/claims_credentials_did.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["claims_credentials_did"]
        vault_mount = vault_mount.ixo.path
        cellnode    = terraform.workspace == "mainnet" ? "https://cellnode.ixo.world" : "http://ixo-cellnode.core.svc.cluster.local:5000" #todo remove
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_feegrant_nest" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_feegrant_nest"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-feegrant-nest"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-feegrant-nest"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_feegrant_nest.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["ixo_feegrant_nest"]
        vault_mount = vault_mount.ixo.path
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_did_resolver" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_did_resolver"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-did-resolver"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-did-resolver"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_did_resolver.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["ixo_did_resolver"] # "resolver.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
        vault_mount = vault_mount.ixo.path
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_faucet" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_faucet"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-faucet"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-faucet"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_faucet.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["ixo_faucet"] #"faucet.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
        vault_mount = vault_mount.ixo.path
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_deeplink_server" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_deeplink_server"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-deeplink-server"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-deeplink-server"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_deeplink_server.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_deeplink_server"] #"faucet.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
        vault_mount = vault_mount.ixo.path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[4].username
        pgPassword  = urlencode(module.postgres-operator.database_password[var.pg_ixo.pg_users[4].username])
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
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_kyc_server" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_kyc_server"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-kyc-server"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-kyc-server"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_kyc_server.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["ixo_kyc_server"]
        vault_mount = vault_mount.ixo.path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[5].username
        pgPassword  = urlencode(module.postgres-operator.database_password[var.pg_ixo.pg_users[5].username])
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
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_redirects" {
  source          = "./modules/ixo_redirects"
  nginx_namespace = kubernetes_namespace_v1.ingress_nginx.metadata[0].name
}

module "ixo_matrix_appservice_rooms" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_matrix_appservice_rooms"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-matrix-appservice-rooms"
    namespace  = kubernetes_namespace_v1.matrix.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-matrix-appservice-rooms"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo_matrix_appservice_rooms.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_matrix_appservice_rooms"]
        vault_mount = vault_mount.ixo.path
        gcs_bucket  = "${google_storage_bucket.matrix_backups.url}/bot/rooms"
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_faq_assistant" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_faq_assistant"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-faq-assistant"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/faq-assistant"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-faq-assistant.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_faq_assistant"]
        vault_mount = vault_mount.ixo.path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[7].username
        pgPassword  = module.postgres-operator.database_password[var.pg_ixo.pg_users[7].username]
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
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_guru" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_guru"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-guru"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-guru"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-guru.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_guru"]
        vault_mount = vault_mount.ixo.path
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
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_guru_temp" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_ai_oracles_guru"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-ai-oracles-guru"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixoworld/ixo-ai-oracles-guru"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-ai-oracles-guru.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_ai_oracles_guru"]
        vault_mount = vault_mount.ixo.path
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
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_trading_bot_server" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_trading_bot_server"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-trading-bot-server"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-trading-bot-server"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-trading-bot-server.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_trading_bot_server"]
        vault_mount = vault_mount.ixo.path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[11].username
        pgPassword  = urlencode(module.postgres-operator.database_password[var.pg_ixo.pg_users[11].username])
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
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_whizz" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_whizz"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-whizz"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-whizz"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-whizz.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_whizz"]
        vault_mount = vault_mount.ixo.path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[8].username
        pgPassword  = module.postgres-operator.database_password[var.pg_ixo.pg_users[8].username]
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
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_coin_server" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_coin_server"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-coin-server"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-coin-server"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-coin-server.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_coin_server"]
        vault_mount = vault_mount.ixo.path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[6].username
        pgPassword  = urlencode(module.postgres-operator.database_password[var.pg_ixo.pg_users[6].username])
      }
    )
  }
  create_kv = true
  kv_defaults = {
    AUTHORIZATION     = ""
    COINGECKO_API_KEY = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_stake_reward_claimer" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_stake_reward_claimer"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-stake-reward-claimer"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-stake-reward-claimer"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-stake-reward-claimer.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_stake_reward_claimer"]
        vault_mount = vault_mount.ixo.path
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
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_offset_auto_approve" {
  count  = var.environments[terraform.workspace].enabled_services["auto_approve_offset"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "auto-approve-offset"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-auto-approve-agent"
    values_override = templatefile("${local.helm_values_config_path}/core-values/auto_approve_offset.yml",
      {
        environment = terraform.workspace
        rpc_url     = var.environments[terraform.workspace].rpc_url
        host        = local.dns_for_environment[terraform.workspace]["auto_approve_offset"]
        vault_mount = vault_mount.ixo.path
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
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_iot_data" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_iot_data"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-iot-data"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-iot-data"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-iot-data.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_iot_data"]
        vault_mount = vault_mount.ixo.path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[9].username
        pgPassword  = urlencode(module.postgres-operator.database_password[var.pg_ixo.pg_users[9].username])
      }
    )
  }
  create_kv = true
  kv_defaults = {
    AUTHORIZATION = ""
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_notification_server" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_notification_server"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-notification-server"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/ixo-notification-server"
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-notification-server.yml",
      {
        environment = terraform.workspace
        host        = local.dns_for_environment[terraform.workspace]["ixo_notification_server"]
        vault_mount = vault_mount.ixo.path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[10].username
        pgPassword  = urlencode(module.postgres-operator.database_password[var.pg_ixo.pg_users[10].username])
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
  vault_mount_path = vault_mount.ixo.path
}

#module "ixo_ussd" {
#  count  = var.environments[terraform.workspace].enabled_services["ixo_ussd"] ? 1 : 0
#  source = "./modules/argocd_application"
#  application = {
#    name       = "ixo-ussd"
#    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
#    owner      = "ixofoundation"
#    repository = local.ixo_helm_chart_repository
#    path       = "charts/${terraform.workspace}/ixofoundation/ixo-ussd"
#    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-ussd.yml",
#      {
#        environment = terraform.workspace
#        host        = local.dns_for_environment[terraform.workspace]["ixo_ussd"]
#        vault_mount = vault_mount.ixo.path
#      }
#    )
#  }
#  argo_namespace   = module.argocd.argo_namespace
#  vault_mount_path = vault_mount.ixo.path
#}

#module "blocksync_migration" { # Note this will be commented in/out only for new releases to blocksync that require re-indexing the DB.
#  depends_on = [module.ixo_blocksync, module.ixo_blocksync_core]
#  source     = "./modules/ixo_blocksync_migration"
#  db_info = {
#    pgUsername  = var.pg_ixo.pg_users[3].username
#    pgPassword  = urlencode(module.postgres-operator.database_password[var.pg_ixo.pg_users[3].username])
#    pgCluster   = var.pg_ixo.pg_cluster_name
#    pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
#    # This is to determine whether we are indexing blocksync or blocksync_alt for the new version. eg if we are running in `blocksync_alt` then set this to false so we index `blocksync` for the new version.
#    # If current DB in-use is `blocksync` set to true. Else if current DB in-use is`blocksync_alt` set to false.
#    # true = pod created will run migrations on `blocksync_alt`
#    # false = pod created will run migrations on `blocksync`
#    useAlt = false
#  }
#  existing_blocksync_pod_label_name = "ixo-blocksync"
#  namespace                         = kubernetes_namespace_v1.ixo_core.metadata[0].name
#}

#DATABASE_URL : postgresql://cellnode:p^mv%7Bv|+^C^vkXlNoYRuBA)@ixo-postgres-primary.ixo-postgres.svc.cluster.local/cellnode
#DATABASE_URL : postgresql://cellnode:p%5Emv%7Bv%7C%2B%5EC%5EvkXlNoYRuBA%29@ixo-postgres-primary.ixo-postgres.svc.cluster.local/cellnode