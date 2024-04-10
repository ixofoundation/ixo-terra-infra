module "ixo_cellnode" {
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-cellnode"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    values_override = templatefile("${local.helm_values_config_path}/ixo-common.yml",
      {
        environment = terraform.workspace
        app_name    = "ixo-cellnode"
        host        = var.hostnames[terraform.workspace]
        DB_ENDPOINT = "postgresql://${var.pg_ixo.pg_users[0].username}:${module.postgres-operator.database_password[var.pg_ixo.pg_users[0].username]}@${var.pg_ixo.pg_cluster_name}-primary.${kubernetes_namespace_v1.ixo-postgres.metadata[0].name}.svc.cluster.local"
        web3_key    = "<path:${vault_mount.ixo.path}/data/ixo-cellnode#WEB3_KEY>"
        web3_proof  = "<path:${vault_mount.ixo.path}/data/ixo-cellnode#WEB3_PROOF>"
        port        = 5000
        ingressPath = "/ixo-cellnode(/|$)(.*)"
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
        environment = terraform.workspace
        app_name    = "ixo-matrix-state-bot"
        host        = "state.bot.${var.hostnames["${terraform.workspace}_matrix"]}"
        DB_ENDPOINT = ""
        web3_key    = ""
        web3_proof  = ""
        port        = 8080
        ingressPath = "/"
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}