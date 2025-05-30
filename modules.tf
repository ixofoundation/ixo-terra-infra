module "kubernetes_cluster" {
  source         = "./modules/kubernetes_cluster"
  cloud_provider = "vultr"
  
  vultr = {
    cluster_firewall            = lookup(var.environments[terraform.workspace], "cluster_firewall", false)
    cluster_label               = "ixo-cluster-${terraform.workspace}"
    initial_node_pool_label     = "ixo-${terraform.workspace}"
    initial_node_pool_plan      = "vhf-3c-8gb"
    k8_version                  = var.versions["kubernetes_cluster"]
    cluster_region              = local.region_ids["Amsterdam"]
    ha_controlplanes            = false
    initial_node_pool_quantity  = 2
    initial_node_pool_scaler    = true
    initial_node_pool_min_nodes = 2
    initial_node_pool_max_nodes = 4
  }
}

module "argocd" {
  depends_on           = [module.kubernetes_cluster]
  source               = "./modules/argocd"
  hostnames            = {
    (terraform.workspace) = local.dns_for_environment[terraform.workspace]["prometheus_stack"]
  }
  github_client_id     = var.oidc_argo.clientId
  github_client_secret = var.oidc_argo.clientSecret
  argo_version         = var.versions["argocd"]
  org                  = var.org
  git_repositories = [
    {
      name       = "ixofoundation"
      repository = var.ixo_helm_chart_repository
    }
  ]
  applications_helm = [
  ]
}

module "chromadb" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["chromadb"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "chromadb"
    namespace = kubernetes_namespace_v1.chromadb.metadata[0].name
    helm = {
      isOci             = false
      chart             = "chromadb"
      revision          = var.versions["chromadb"]
    }
    repository      = "https://amikos-tech.github.io/chromadb-chart/"
    values_override = templatefile("${local.helm_values_config_path}/chromadb-values.yml", {})
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "cert_manager" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["cert_manager"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "cert-manager"
    namespace = kubernetes_namespace_v1.cert_manager.metadata[0].name
    helm = {
      isOci             = false
      chart             = "cert-manager"
      revision          = var.versions["cert-manager"]
      ignoreDifferences = local.cert_manager_ignore_differences
    }
    repository      = "https://charts.jetstack.io"
    values_override = templatefile("${local.helm_values_config_path}/cert-manager-values.yml", {})
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "ingress_nginx" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["ingress_nginx"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "nginx-ingress-controller"
    namespace = kubernetes_namespace_v1.ingress_nginx.metadata[0].name
    helm = {
      isOci             = false
      chart             = "ingress-nginx"
      revision          = var.versions["nginx-ingress-controller"]
      ignoreDifferences = local.nginx_ignore_differences
    }
    repository = "https://kubernetes.github.io/ingress-nginx"
    values_override = templatefile("${local.helm_values_config_path}/nginx-ingress-controller-values.yml",
      {
        host = local.dns_for_environment[terraform.workspace]["prometheus_stack"]
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "postgres_operator_crunchydata" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["postgres_operator_crunchydata"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = { # We use a fork of the main Operator helm chart to enable feature gates.
    name            = "postgres-operator"
    namespace       = kubernetes_namespace_v1.postgres_operator.metadata[0].name
    repository      = "https://github.com/ixofoundation/postgres-operator-examples"
    path            = "helm/install"
    values_override = templatefile("${local.helm_values_config_path}/postgres-operator-values.yml", {})
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "prometheus_stack" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["prometheus_stack"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "prometheus-stack"
    namespace = kubernetes_namespace_v1.prometheus_stack.metadata[0].name
    helm = {
      isOci             = false
      chart             = "kube-prometheus-stack"
      revision          = var.versions["prometheus-stack"]
      ignoreDifferences = local.prometheus_stack_ignore_differences
    }
    repository = "https://prometheus-community.github.io/helm-charts"
    values_override = templatefile("${local.helm_values_config_path}/prometheus.yml", {
      host                = local.dns_for_environment[terraform.workspace]["prometheus_stack"]
      blackbox_targets    = yamlencode(local.synthetic_monitoring_endpoints)
      grafana_oidc_secret = random_password.grafana_dex_oidc_secret.result
      dex_host            = local.dns_for_environment[terraform.workspace]["dex"]
      org                 = var.org
      environment         = terraform.workspace
      additional_scrape_metrics = var.additional_prometheus_scrape_metrics[terraform.workspace]
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

# module "external_dns" {
#   depends_on = [module.argocd]
#   count      = var.environments[terraform.workspace].application_configs["external_dns"].enabled ? 1 : 0
#   source     = "./modules/argocd_application"
#   application = {
#     name      = "external-dns"
#     namespace = kubernetes_namespace_v1.external_dns.metadata[0].name
#     helm = {
#       isOci    = false
#       chart    = "external-dns"
#       revision = var.versions["external-dns"]
#     }
#     repository = "https://kubernetes-sigs.github.io/external-dns/"
#     values_override = templatefile("${local.helm_values_config_path}/external-dns-values.yml", {
#       VULTR_API_KEY = var.vultr_api_key
#     })
#   }
#   argo_namespace   = module.argocd.argo_namespace
#   vault_mount_path = vault_mount.ixo.path
# }

module "dex" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["dex"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "dex"
    namespace = kubernetes_namespace_v1.dex.metadata[0].name
    helm = {
      isOci    = false
      chart    = "dex"
      revision = var.versions["dex"]
    }
    repository = "https://charts.dexidp.io"
    values_override = templatefile("${local.helm_values_config_path}/dex-values.yml",
      {
        vault_host           = local.dns_for_environment[terraform.workspace]["vault"]
        host                 = local.dns_for_environment[terraform.workspace]["dex"]
        github_client_id     = var.oidc_vault.clientId
        github_client_secret = var.oidc_vault.clientSecret
        vault_oidc_secret    = random_password.vault_dex_oidc_secret.result
        grafana_oidc_secret  = random_password.grafana_dex_oidc_secret.result
        grafana_host         = "${local.dns_for_environment[terraform.workspace]["prometheus_stack"]}/grafana"
        org                  = var.org
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "vault" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["vault"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "vault"
    namespace = kubernetes_namespace_v1.vault.metadata[0].name
    helm = {
      isOci             = false
      chart             = "vault"
      revision          = var.versions["vault"]
      ignoreDifferences = local.vault_ignore_differences
    }
    repository = "https://helm.releases.hashicorp.com"
    values_override = templatefile("${local.helm_values_config_path}/vault-values.yml",
      {
        project         = var.gcp_project_ids[terraform.workspace]
        key_ring        = module.gcp_kms_vault.key_ring_name
        crypto_key      = module.gcp_kms_vault.crypto_key_name
        gcp_secret_name = module.gcp_kms_vault.gcp_key_secret_name
        replicas        = 2
        host            = local.dns_for_environment[terraform.workspace]["vault"]
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "loki" {
  depends_on = [module.argocd, module.prometheus_stack]
  count      = var.environments[terraform.workspace].application_configs["loki"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "loki"
    namespace = kubernetes_namespace_v1.loki.metadata[0].name
    helm = {
      isOci             = false
      chart             = "loki"
      revision          = var.versions["loki"]
      ignoreDifferences = local.loki_ignore_differences
    }
    repository      = "https://grafana.github.io/helm-charts"
    values_override = templatefile("${local.helm_values_config_path}/loki-values.yml",
      {
        gcs_bucket = google_storage_bucket.loki_logs_backups.name
        service_account = indent(8, module.gcp_kms_loki.gcp_key_secret_data["key.json"])
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "prometheus_blackbox_exporter" {
  depends_on = [module.argocd, module.prometheus_stack]
  count      = var.environments[terraform.workspace].application_configs["prometheus_blackbox_exporter"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "prometheus-blackbox-exporter"
    namespace = kubernetes_namespace_v1.prometheus_blackbox_exporter.metadata[0].name
    helm = {
      isOci    = false
      chart    = "prometheus-blackbox-exporter"
      revision = var.versions["prometheus-blackbox-exporter"]
    }
    repository      = "https://prometheus-community.github.io/helm-charts"
    values_override = templatefile("${local.helm_values_config_path}/prometheus-blackbox.yml", {})
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "tailscale" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["tailscale"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "tailscale"
    namespace = kubernetes_namespace_v1.tailscale.metadata[0].name
    helm = {
      isOci    = false
      chart    = "tailscale-operator"
      revision = var.versions["tailscale"]
    }
    repository = "https://pkgs.tailscale.com/helmcharts"
    values_override = templatefile("${local.helm_values_config_path}/tailscale-values.yml",
      {
        clientId     = var.oidc_tailscale.clientId
        clientSecret = var.oidc_tailscale.clientSecret
        environment  = terraform.workspace
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "matrix" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["matrix"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "matrix"
    namespace = kubernetes_namespace_v1.matrix.metadata[0].name
    helm = {
      isOci    = false
      chart    = "matrix-synapse"
      revision = var.versions["matrix"]
    }
    repository = "https://ananace.gitlab.io/charts"
    values_override = templatefile("${local.helm_values_config_path}/matrix-values.yml",
      {
        pg_host         = "${var.pg_matrix.pg_cluster_name}-primary.matrix-synapse.svc.cluster.local"
        pg_username     = "synapse"
        pg_cluster_name = var.pg_matrix.pg_cluster_name
        host            = local.dns_for_environment[terraform.workspace]["matrix"]
        kv_mount        = var.vault_core_mount
        app_name        = "matrix"
        gcs_bucket_url  = google_storage_bucket.matrix_backups.url
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "nfs_provisioner" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["nfs_provisioner"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "nfs-provisioner"
    namespace = kubernetes_namespace_v1.nfs_provisioner.metadata[0].name
    helm = {
      isOci             = false
      chart             = "nfs-server-provisioner"
      revision          = "1.8.0"
      ignoreDifferences = local.nfs_provisioner_ignore_differences
    }
    repository      = "https://kubernetes-sigs.github.io/nfs-ganesha-server-and-external-provisioner"
    values_override = templatefile("${local.helm_values_config_path}/nfs-values.yml", {})
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "metrics_server" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["metrics_server"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name       = "metrics-server"
    namespace  = kubernetes_namespace_v1.metrics_server.metadata[0].name
    repository = "https://kubernetes-sigs.github.io/metrics-server/"
    helm = {
      isOci    = false
      chart    = "metrics-server"
      revision = var.versions["metrics-server"]
    }
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "uptime_kuma" {
  count      = var.environments[terraform.workspace].application_configs["uptime_kuma"].enabled ? 1 : 0
  depends_on = [module.argocd]
  source     = "./modules/argocd_application"
  application = {
    name       = "uptime-kuma"
    namespace  = kubernetes_namespace_v1.uptime_kuma.metadata[0].name
    repository = "https://dirsigler.github.io/uptime-kuma-helm"
    helm = {
      isOci    = false
      chart    = "uptime-kuma"
      revision = var.versions["uptime-kuma"]
    }
    values_override = templatefile("${local.helm_values_config_path}/uptime-kuma-values.yml", {
        host = local.dns_for_environment[terraform.workspace]["uptime_kuma"]
      })
    argo_namespace   = module.argocd.argo_namespace
    vault_mount_path = vault_mount.ixo.path
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "matrix_admin" {
  depends_on = [module.argocd, module.matrix]
  source     = "./modules/argocd_application"
  application = {
    name       = "matrix-admin"
    namespace  = kubernetes_namespace_v1.matrix.metadata[0].name
    repository = var.ixo_terra_infra_repository
    path       = "charts/matrix-admin"
    values_override = templatefile("${local.helm_values_config_path}/matrix-admin.yml",
      {
        matrix_host = local.dns_for_environment[terraform.workspace]["matrix"]
        app_name    = "matrix-admin"
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

module "cert-issuer" {
  depends_on = [module.argocd]
  source     = "./modules/cert-manager"
}

module "postgres-operator" { # Sets up Cluster Instances
  depends_on = [module.argocd, module.postgres_operator_crunchydata]
  source     = "./modules/postgres-operator"
  clusters = [
    {
      # Matrix Postgres Cluster
      pg_cluster_name        = var.pg_matrix.pg_cluster_name
      pg_cluster_namespace   = kubernetes_namespace_v1.matrix.metadata[0].name
      pg_image               = var.pg_matrix.pg_image
      pg_image_tag           = var.pg_matrix.pg_image_tag
      pg_version             = var.pg_matrix.pg_version
      pg_instances           = file("${local.postgres_operator_config_path}/matrix-postgres-instances.yml")
      pg_users               = local.matrix_pg_users_yaml
      pg_usernames           = local.matrix_pg_users_usernames
      pgbackrest_image       = var.pg_matrix.pgbackrest_image
      pgbackrest_image_tag   = var.pg_matrix.pgbackrest_image_tag
      pgbackrest_repos       = file("${local.postgres_operator_config_path}/matrix-postgres-backups-repos.yml")
      pgmonitoring_image     = var.pg_matrix.pgmonitoring_image
      pgmonitoring_image_tag = var.pg_matrix.pgmonitoring_image_tag
      initSql                = file("${path.root}/config/sql/matrix-init.sql")
    },
    {
      # IXO Cluster
      pg_cluster_name      = var.pg_ixo.pg_cluster_name
      pg_cluster_namespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
      pg_image             = var.pg_ixo.pg_image
      pg_image_tag         = var.pg_ixo.pg_image_tag
      pg_version           = var.pg_ixo.pg_version
      pg_instances         = file("${local.postgres_operator_config_path}/ixo-postgres-instances.yml")
      pg_users             = local.pg_users_yaml
      pg_usernames         = local.pg_users_usernames
      pgbackrest_image     = var.pg_ixo.pgbackrest_image
      pgbackrest_image_tag = var.pg_ixo.pgbackrest_image_tag
      pgbackrest_repos = templatefile("${local.postgres_operator_config_path}/ixo-postgres-backups-repos.yml",
        {
          gcs_bucket = google_storage_bucket.postgres_backups.name
        }
      )
      pgmonitoring_image     = var.pg_ixo.pgmonitoring_image
      pgmonitoring_image_tag = var.pg_ixo.pgmonitoring_image_tag
      initSql                = file("${path.root}/config/sql/ixo-init.sql")
    }
  ]
  gcs_key = file("${path.root}/credentials.json")
}

module "hyperlane_validator" {
  source = "./modules/hyperlane"
  count      = var.environments[terraform.workspace].application_configs["hyperlane_validator"].enabled ? 1 : 0
  providers = {
    aws = aws
  }
  aws_region = var.environments[terraform.workspace].aws_region
  environment = terraform.workspace
  chain_names = var.environments[terraform.workspace].hyperlane.chain_names
  metadata_chains = var.environments[terraform.workspace].hyperlane.metadata_chains
}

module "ixo_loki_logs" {
  depends_on = [module.argocd]
  source     = "./modules/loki_logs"

  matchNamespaces = [
    kubernetes_namespace_v1.ixo_core.metadata[0].name,
    kubernetes_namespace_v1.ingress_nginx.metadata[0].name,
    kubernetes_namespace_v1.matrix.metadata[0].name,
    kubernetes_namespace_v1.ixo-postgres.metadata[0].name
  ]
  name      = "ixo"
  namespace = "ixo-loki"
}

module "gcp_kms_vault" {
  source    = "./modules/gcp_kms"
  name      = "vault-${terraform.workspace}"
  namespace = "vault"
}

module "gcp_kms_matrix" {
  depends_on = [module.matrix]
  source     = "./modules/gcp_kms"
  name       = "matrix-${terraform.workspace}"
  namespace  = kubernetes_namespace_v1.matrix.metadata[0].name
}

module "gcp_kms_loki" {
  source     = "./modules/gcp_kms"
  name       = "loki-${terraform.workspace}"
  namespace  = kubernetes_namespace_v1.loki.metadata[0].name
}

module "gcp_kms_core" {
  depends_on = [module.argocd]
  source     = "./modules/gcp_kms"
  name       = "core-${terraform.workspace}"
  namespace  = kubernetes_namespace_v1.ixo_core.metadata[0].name
}

module "vault_init" {
  depends_on = [module.argocd]
  source     = "./modules/vault"

  init_params = {
    key_shares    = 3
    key_threshold = 2
  }
  name                     = "vault"
  namespace                = "vault"
  kube_config_path         = module.kubernetes_cluster.kubeconfig_path
  kubernetes_host          = module.kubernetes_cluster.endpoint
  argo_namespace           = module.argocd.argo_namespace
  argo_policy              = file("${path.root}/config/vault/argocd_policy.hcl")
  dex_host                 = local.dns_for_environment[terraform.workspace]["dex"]
  oidc_client_secret       = random_password.vault_dex_oidc_secret.result
  vault_host               = local.dns_for_environment[terraform.workspace]["vault"]
  vault_terraform_password = var.vultr_api_key
  org                      = var.org
}

module "matrix_init" {
  depends_on = [module.argocd, module.matrix]
  source     = "./modules/matrix"

  kube_config_path = module.kubernetes_cluster.kubeconfig_path
  namespace        = kubernetes_namespace_v1.matrix.metadata[0].name
  vault_mount_path = vault_mount.ixo.path
}

module "external_dns_cloudflare" {
  source = "./modules/argocd_application"
  application = {
    name       = "external-dns-cloudflare"
    namespace  = kubernetes_namespace_v1.external_dns_cloudflare.metadata[0].name
    repository = "https://kubernetes-sigs.github.io/external-dns/"
    helm = {
      isOci    = false
      chart    = "external-dns"
      revision = var.versions["external-dns"]
    }
    values_override = templatefile("${local.helm_values_config_path}/external-dns-values-cloudflare.yml",
      {
        CF_API_TOKEN = var.cloudflare_api_token
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  create_kv        = false
  vault_mount_path = null
}

# Requires to be logged in via gcloud auth login
#module "gce_csi_driver" {
#  source = "./modules/gce_csi_driver"
#  service_account_dir = path.cwd
#  kubeconfig_path = abspath(module.kubernetes_cluster.kubeconfig_path)
#}

resource "random_password" "mautrix_slack_as_token" {
  length  = 64
  special = false
  numeric = false
  lower   = true
  upper   = true
}

resource "random_password" "mautrix_slack_hs_token" {
  length  = 64
  special = false
  numeric = false
  lower   = true
  upper   = true
}