module "ixo_cellnode" {
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-cellnode"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    values_override = templatefile("${local.helm_values_config_path}/ixo-common.yml",
      {
        environment   = terraform.workspace
        app_name      = "ixo-cellnode"
        host          = "${terraform.workspace}-cellnode.${var.environments[terraform.workspace].domain}"
        port          = 5000
        ingressPath   = "/"
        memoryRequest = "300Mi"
        memoryLimit   = "600Mi"
        envVars = [
          {
            name  = "NODE_ENV"
            value = "production"
          },
          {
            name  = "PORT"
            value = "5000"
          },
          {
            name  = "WEB3_KEY"
            value = "<path:${vault_mount.ixo.path}/data/ixo-cellnode#WEB3_KEY>"
          },
          {
            name  = "WEB3_PROOF"
            value = "<path:${vault_mount.ixo.path}/data/ixo-cellnode#WEB3_PROOF>"
          },
          {
            name  = "DATABASE_URL"
            value = "postgresql://${var.pg_ixo.pg_users[1].username}:${module.postgres-operator.database_password[var.pg_ixo.pg_users[1].username]}@${var.pg_ixo.pg_cluster_name}-primary.${kubernetes_namespace_v1.ixo-postgres.metadata[0].name}.svc.cluster.local/${var.pg_ixo.pg_users[1].username}"
          },
          {
            name  = "MIGRATE_DB_PROGRAMATICALLY"
            value = "0"
          },
          {
            name  = "DATABASE_USE_SSL"
            value = "1"
          },
          {
            name  = "TRUST_PROXY"
            value = "1"
          },
          {
            name  = "FILE_TYPES"
            value = "[\\\"image/svg+xml\\\", \\\"image/png\\\", \\\"application/ld+json\\\", \\\"application/json\\\", \\\"application/pdf\\\",\\\"image/jpeg\\\",\\\"image/webp\\\"]"
          }
        ]
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_matrix_state_bot" {
  depends_on = [kubernetes_persistent_volume_claim_v1.common]
  source     = "./modules/argocd_application"
  application = {
    name       = "ixo-matrix-state-bot"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    values_override = templatefile("${local.helm_values_config_path}/ixo-common.yml",
      {
        environment   = terraform.workspace
        app_name      = "ixo-matrix-state-bot"
        host          = "state.bot.${var.hostnames["${terraform.workspace}_matrix"]}"
        port          = 8080
        ingressPath   = "/"
        memoryRequest = "100Mi"
        memoryLimit   = "200Mi"
        envVars = [
          {
            name  = "PORT"
            value = "8080"
          }
        ]
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_blocksync_core" {
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-blocksync-core"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    values_override = templatefile("${local.helm_values_config_path}/ixo-common.yml",
      {
        environment   = terraform.workspace
        app_name      = "ixo-blocksync-core"
        host          = "ixo-blocksync-core.${var.hostnames[terraform.workspace]}"
        port          = 8081
        ingressPath   = "/"
        memoryRequest = "300Mi"
        memoryLimit   = "600Mi"
        envVars = [
          {
            name  = "PORT"
            value = "8081"
          },
          {
            name  = "NODE_ENV"
            value = "production"
          },
          {
            name  = "TRUST_PROXY"
            value = "1"
          },
          {
            name  = "RPC"
            value = "https://devnet.ixo.earth/rpc/"
          },
          {
            name  = "MIGRATE_DB_PROGRAMATICALLY"
            value = "1"
          },
          {
            name  = "DATABASE_USE_SSL"
            value = "1"
          },
          {
            name  = "SENTRYDSN"
            value = ""
          },
          {
            name  = "DATABASE_URL"
            value = "postgresql://${var.pg_ixo.pg_users[2].username}:${module.postgres-operator.database_password[var.pg_ixo.pg_users[2].username]}@${var.pg_ixo.pg_cluster_name}-primary.${kubernetes_namespace_v1.ixo-postgres.metadata[0].name}.svc.cluster.local/${var.pg_ixo.pg_users[2].username}"
          }
        ]
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ixo-blocksync" {
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-blocksync"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    values_override = templatefile("${local.helm_values_config_path}/ixo-common.yml",
      {
        environment   = terraform.workspace
        app_name      = "ixo-blocksync"
        host          = "ixo-blocksync.${var.hostnames[terraform.workspace]}"
        port          = 8082
        ingressPath   = "/"
        memoryRequest = "300Mi"
        memoryLimit   = "800Mi"
        envVars = [
          {
            name  = "PORT"
            value = "8082"
          },
          {
            name  = "NODE_ENV"
            value = "production"
          },
          {
            name  = "RPC"
            value = "https://devnet.ixo.earth/rpc/"
          },
          {
            name  = "MIGRATE_DB_PROGRAMATICALLY"
            value = "1"
          },
          {
            name  = "DATABASE_USE_SSL"
            value = "1"
          },
          {
            name  = "IPFS_SERVICE_MAPPING"
            value = "https://devnet-blocksync-graphql.ixo.earth/api/ipfs/"
          },
          {
            name  = "DATABASE_URL_CORE"
            value = "postgresql://${var.pg_ixo.pg_users[2].username}:${module.postgres-operator.database_password[var.pg_ixo.pg_users[2].username]}@${var.pg_ixo.pg_cluster_name}-primary.${kubernetes_namespace_v1.ixo-postgres.metadata[0].name}.svc.cluster.local/${var.pg_ixo.pg_users[2].username}"
          },
          {
            name  = "DATABASE_URL"
            value = "postgresql://${var.pg_ixo.pg_users[3].username}:${module.postgres-operator.database_password[var.pg_ixo.pg_users[3].username]}@${var.pg_ixo.pg_cluster_name}-primary.${kubernetes_namespace_v1.ixo-postgres.metadata[0].name}.svc.cluster.local/${var.pg_ixo.pg_users[3].username}"
          },
          {
            name  = "ENTITY_MODULE_CONTRACT_ADDRESS"
            value = "ixo14hj2tavq8fpesdwxxcu44rty3hh90vhujrvcmstl4zr3txmfvw9sqa3vn7"
          }
        ]
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "credentials_prospect" {
  source = "./modules/argocd_application"
  application = {
    name       = "credentials-prospect"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/emerging-claims-credentials"
    values_override = templatefile("${local.helm_values_config_path}/ixo-common.yml",
      {
        environment   = terraform.workspace
        app_name      = "credentials-prospect"
        host          = "credentials-prospect.${var.hostnames[terraform.workspace]}"
        port          = 3000
        ingressPath   = "/"
        memoryRequest = "200Mi"
        memoryLimit   = "300Mi"
        envVars = [
          {
            name  = "PORT"
            value = "3000"
          },
          {
            name  = "Authorization"
            value = "<path:${vault_mount.ixo.path}/data/credentials-prospect#AUTHORIZATION>"
          },
          {
            name  = "ENABLE_CLAIMS"
            value = "true"
          },
          {
            name  = "BLOCKSYNC_GRAPHQL"
            value = "http://ixo-blocksync.core.svc.cluster.local"
          },
          {
            name  = "CELLNODE"
            value = "http://ixo-cellnode.core.svc.cluster.local"
          },
          {
            name  = "RPC_URL"
            value = "https://devnet.ixo.earth/rpc/"
          },
          {
            name  = "SECP_MNEMONIC"
            value = "<path:${vault_mount.ixo.path}/data/credentials-prospect#SECP_MNEMONIC>"
          },
          {
            name  = "ENABLE_CREDENTIALS"
            value = "true"
          },
          {
            name  = "ISSUER_DID"
            value = "<path:${vault_mount.ixo.path}/data/credentials-prospect#ISSUER_DID>"
          },
          {
            name  = "CREDENTIALS_MNEMONIC"
            value = "<path:${vault_mount.ixo.path}/data/credentials-prospect#CREDENTIALS_MNEMONIC>"
          },
          {
            name  = "NETWORK"
            value = terraform.workspace
          },
          {
            name  = "REMOTE_CONTEXTS"
            value = "[\\\"https://w3id.org/ixo/context/v1\\\"]"
          },
          {
            name  = "ENABLE_TOKENS"
            value = "false"
          },
          {
            name  = "ENABLE_PROOFS"
            value = "false"
          }
        ]
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}