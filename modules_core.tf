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
  create_kv        = true
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
        host        = local.dns_for_environment[terraform.workspace]["ixo_kyc_server"] #"faucet.${terraform.workspace}.${var.environments[terraform.workspace].domain}"
        vault_mount = vault_mount.ixo.path
        pgCluster   = var.pg_ixo.pg_cluster_name
        pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pgUsername  = var.pg_ixo.pg_users[5].username
        pgPassword  = urlencode(module.postgres-operator.database_password[var.pg_ixo.pg_users[5].username])
      }
    )
  }
  create_kv        = true
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ixo_redirects" {
  count           = terraform.workspace == "mainnet" ? 0 : 1
  source          = "./modules/ixo_redirects"
  nginx_namespace = module.argocd.namespaces_helm["nginx-ingress-controller"].metadata[0].name
}

module "ixo_matrix_appservice_rooms" {
  count  = var.environments[terraform.workspace].enabled_services["ixo_matrix_appservice_rooms"] ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "ixo-matrix-appservice-rooms"
    namespace  = module.argocd.namespaces_helm["matrix"].metadata[0].name
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

#module "blocksync_migration" { # Note this will be commented in/out only for new releases to blocksync that require re-indexing the DB.
#  depends_on = [module.ixo_blocksync, module.ixo_blocksync_core]
#  source     = "./modules/ixo_blocksync_migration"
#  db_info = {
#    pgUsername = var.pg_ixo.pg_users[3].username
#    pgPassword = urlencode(module.postgres-operator.database_password[var.pg_ixo.pg_users[3].username])
#    pgCluster   = var.pg_ixo.pg_cluster_name
#    pgNamespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
#    useAlt      = true # This is to determine whether we are indexing blocksync or blocksync_alt for the new version. eg if we are running in `blocksync_alt` then set this to false so we index `blocksync` for the new version.
#  }
#  existing_blocksync_pod_label_name = "ixo-blocksync"
#  namespace                         = kubernetes_namespace_v1.ixo_core.metadata[0].name
#}

#DATABASE_URL : postgresql://cellnode:p^mv%7Bv|+^C^vkXlNoYRuBA)@ixo-postgres-primary.ixo-postgres.svc.cluster.local/cellnode
#DATABASE_URL : postgresql://cellnode:p%5Emv%7Bv%7C%2B%5EC%5EvkXlNoYRuBA%29@ixo-postgres-primary.ixo-postgres.svc.cluster.local/cellnode