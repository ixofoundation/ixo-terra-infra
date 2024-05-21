resource "kubernetes_secret_v1" "repository" { // Common Git Repository for Core modules.
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
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-cellnode"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-cellnode.yml",
      {
        host        = "${terraform.workspace}-cellnode.${var.environments[terraform.workspace].domain}"
        vault_mount = vault_mount.ixo.path
        pgUsername  = var.pg_ixo.pg_users[1].username
        pgPassword  = module.postgres-operator.database_password[var.pg_ixo.pg_users[1].username]
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
  depends_on = [kubernetes_persistent_volume_claim_v1.common]
  source     = "./modules/argocd_application"
  application = {
    name       = "ixo-matrix-state-bot"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-matrix-state-bot.yml",
      {
        host = "state.bot.${var.hostnames["${terraform.workspace}_matrix"]}"
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
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-blocksync-core.yml",
      {
        host        = "ixo-blocksync-core.${var.hostnames[terraform.workspace]}"
        pgUsername  = var.pg_ixo.pg_users[2].username
        pgPassword  = module.postgres-operator.database_password[var.pg_ixo.pg_users[2].username]
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
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
    values_override = templatefile("${local.helm_values_config_path}/core-values/ixo-blocksync.yml",
      {
        host            = "${terraform.workspace}-blocksync-graphql.${var.environments[terraform.workspace].domain}"
        pgUsername      = var.pg_ixo.pg_users[3].username
        pgPassword      = module.postgres-operator.database_password[var.pg_ixo.pg_users[3].username]
        pgCluster       = var.pg_ixo.pg_cluster_name
        pgNamespace     = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername_core = var.pg_ixo.pg_users[2].username
        pgPassword_core = module.postgres-operator.database_password[var.pg_ixo.pg_users[2].username]
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
    name       = "claims-credentials-prospect"
    namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    path       = "charts/${terraform.workspace}/ixofoundation/emerging-claims-credentials"
    values_override = templatefile("${local.helm_values_config_path}/core-values/claims_credentials_prospect.yml",
      {
        environment = terraform.workspace
        host        = "prospect.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
        vault_mount = vault_mount.ixo.path
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ecs" {
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
        host        = "ecs.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
        vault_mount = vault_mount.ixo.path
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "carbon" {
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
        host        = "carbon.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
        vault_mount = vault_mount.ixo.path
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "umuzi" {
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
        host        = "umuzi.credentials.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
        vault_mount = vault_mount.ixo.path
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_feegrant_nest" {
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
        host        = "feegrant.${var.hostnames[terraform.workspace]}" # "feegrant.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
        vault_mount = vault_mount.ixo.path
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_did_resolver" {
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
        host        = "resolver.${var.hostnames[terraform.workspace]}" # "resolver.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
        vault_mount = vault_mount.ixo.path
      }
    )
  }
  create_kv        = false
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_faucet" {
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
        host        = "faucet.${var.hostnames[terraform.workspace]}" #"faucet.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
        vault_mount = vault_mount.ixo.path
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}