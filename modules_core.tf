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
            value = "[\"image/svg+xml\",\"image/png\", \"application/ld+json\", \"application/json\", \"application/pdf\",\"image/jpeg\",\"image/webp\"]"
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
        host          = var.hostnames[terraform.workspace]
        port          = 8081
        ingressPath   = "/ixo-blocksync-core(/|$)(.*)"
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