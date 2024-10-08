module "kubernetes_cluster" {
  source                  = "./modules/kubernetes_cluster"
  cluster_firewall        = lookup(var.environments[terraform.workspace], "cluster_firewall", false)
  cluster_label           = "ixo-cluster-${terraform.workspace}"
  initial_node_pool_label = "ixo-${terraform.workspace}"
  initial_node_pool_plan  = "vhf-3c-8gb"
  k8_version              = var.versions["kubernetes_cluster"]
  cluster_region          = local.region_ids["Amsterdam"]
}

module "argocd" {
  depends_on           = [module.kubernetes_cluster]
  source               = "./modules/argocd"
  hostnames            = var.hostnames
  github_client_id     = var.oidc_argo.clientId
  github_client_secret = var.oidc_argo.clientSecret
  argo_version         = var.versions["argocd"]
  org                  = var.org
  git_repositories = [
    {
      name       = "ixofoundation"
      repository = local.ixo_helm_chart_repository
    }
  ]
  applications_helm = [
    {
      name              = "cert-manager"
      namespace         = "cert-manager"
      chart             = "cert-manager"
      repository        = "https://charts.jetstack.io"
      revision          = var.versions["cert-manager"]
      ignoreDifferences = local.cert_manager_ignore_differences
      values_override   = templatefile("${local.helm_values_config_path}/cert-manager-values.yml", {})
    },
    {
      name              = "nginx-ingress-controller"
      namespace         = "ingress-nginx"
      chart             = "ingress-nginx"
      revision          = var.versions["nginx-ingress-controller"]
      repository        = "https://kubernetes.github.io/ingress-nginx"
      ignoreDifferences = local.nginx_ignore_differences
      values_override = templatefile("${local.helm_values_config_path}/nginx-ingress-controller-values.yml",
        {
          host = terraform.workspace == "testnet" || terraform.workspace == "mainnet" ? "${var.hostnames[terraform.workspace]}, ${var.hostnames["${terraform.workspace}_world"]}" : var.hostnames[terraform.workspace]
        }
      )
    },
    { # We use a fork of the main Operator helm chart to enable feature gates.
      name            = "postgres-operator"
      namespace       = "postgres-operator"
      chart           = "pgo"
      revision        = var.versions["postgres-operator"]
      repository      = "https://github.com/ixofoundation/postgres-operator-examples"
      path            = "helm/install"
      isHelm          = false
      values_override = templatefile("${local.helm_values_config_path}/postgres-operator-values.yml", {})
    },
    {
      name              = "prometheus-stack"
      namespace         = "prometheus"
      chart             = "kube-prometheus-stack"
      revision          = var.versions["prometheus-stack"]
      repository        = "https://prometheus-community.github.io/helm-charts"
      ignoreDifferences = local.prometheus_stack_ignore_differences
      values_override = templatefile("${local.helm_values_config_path}/prometheus.yml", {
        host                = var.hostnames[terraform.workspace]
        blackbox_targets    = yamlencode(local.synthetic_monitoring_endpoints)
        grafana_oidc_secret = random_password.grafana_dex_oidc_secret.result
        dex_host            = var.hostnames["${terraform.workspace}_dex"]
        org                 = var.org
        environment         = terraform.workspace
      })
    },
    {
      name       = "external-dns"
      namespace  = "external-dns"
      chart      = "external-dns"
      revision   = var.versions["external-dns"]
      repository = "https://kubernetes-sigs.github.io/external-dns/"
      values_override = templatefile("${local.helm_values_config_path}/external-dns-values.yml", {
        VULTR_API_KEY = var.vultr_api_key
      })
    },
    {
      name       = "dex"
      namespace  = "dex"
      chart      = "dex"
      revision   = var.versions["dex"]
      repository = "https://charts.dexidp.io"
      values_override = templatefile("${local.helm_values_config_path}/dex-values.yml",
        {
          vault_host           = var.hostnames["${terraform.workspace}_vault"]
          host                 = var.hostnames["${terraform.workspace}_dex"]
          github_client_id     = var.oidc_vault.clientId
          github_client_secret = var.oidc_vault.clientSecret
          vault_oidc_secret    = random_password.vault_dex_oidc_secret.result
          grafana_oidc_secret  = random_password.grafana_dex_oidc_secret.result
          grafana_host         = "${var.hostnames[terraform.workspace]}/grafana"
          org                  = var.org
        }
      )
    },
    {
      name              = "vault"
      namespace         = "vault"
      chart             = "vault"
      revision          = var.versions["vault"]
      repository        = "https://helm.releases.hashicorp.com"
      ignoreDifferences = local.vault_ignore_differences
      values_override = templatefile("${local.helm_values_config_path}/vault-values.yml",
        {
          project         = var.gcp_project_ids[terraform.workspace]
          key_ring        = module.gcp_kms_vault.key_ring_name
          crypto_key      = module.gcp_kms_vault.crypto_key_name
          gcp_secret_name = module.gcp_kms_vault.gcp_key_secret_name
          replicas        = 2
          host            = var.hostnames["${terraform.workspace}_vault"]
        }
      )
    },
    {
      name              = "loki"
      namespace         = "loki"
      chart             = "loki"
      revision          = var.versions["loki"]
      repository        = "https://grafana.github.io/helm-charts"
      values_override   = templatefile("${local.helm_values_config_path}/loki-values.yml", {})
      ignoreDifferences = local.loki_ignore_differences
    },
    {
      name            = "prometheus-blackbox-exporter"
      namespace       = "prometheus-blackbox-exporter"
      chart           = "prometheus-blackbox-exporter"
      revision        = var.versions["prometheus-blackbox-exporter"]
      repository      = "https://prometheus-community.github.io/helm-charts"
      values_override = templatefile("${local.helm_values_config_path}/prometheus-blackbox.yml", {})
    },
    {
      name       = "tailscale"
      namespace  = "tailscale"
      chart      = "tailscale-operator"
      revision   = var.versions["tailscale"]
      repository = "https://pkgs.tailscale.com/helmcharts"
      values_override = templatefile("${local.helm_values_config_path}/tailscale-values.yml",
        {
          clientId     = var.oidc_tailscale.clientId
          clientSecret = var.oidc_tailscale.clientSecret
          environment  = terraform.workspace
        }
      )
    },
    {
      name       = "matrix"
      namespace  = var.pg_matrix.namespace
      chart      = "matrix-synapse"
      revision   = var.versions["matrix"]
      repository = "https://ananace.gitlab.io/charts"
      values_override = templatefile("${local.helm_values_config_path}/matrix-values.yml",
        {
          pg_host         = "${var.pg_matrix.pg_cluster_name}-primary.matrix-synapse.svc.cluster.local"
          pg_username     = "synapse"
          pg_cluster_name = var.pg_matrix.pg_cluster_name
          host            = var.hostnames["${terraform.workspace}_matrix"]
          kv_mount        = local.vault_core_mount
          app_name        = "matrix"
          gcs_bucket_url  = google_storage_bucket.matrix_backups.url
        }
      )
    },
    {
      name              = "nfs-provisioner"
      namespace         = "nfs"
      chart             = "nfs-server-provisioner"
      revision          = "1.8.0"
      repository        = "https://kubernetes-sigs.github.io/nfs-ganesha-server-and-external-provisioner"
      ignoreDifferences = local.nfs_provisioner_ignore_differences
      values_override   = templatefile("${local.helm_values_config_path}/nfs-values.yml", {})
    },
    {
      name       = "metrics-server"
      namespace  = "metrics-server"
      chart      = "metrics-server"
      revision   = var.versions["metrics-server"]
      repository = "https://kubernetes-sigs.github.io/metrics-server/"
    },
  ]
}

module "matrix_admin" {
  source = "./modules/argocd_application"
  application = {
    name       = "matrix-admin"
    namespace  = var.pg_matrix.namespace
    owner      = "ixofoundation"
    repository = local.ixo_terra_infra_repository
    path       = "charts/matrix-admin"
    values_override = templatefile("${local.helm_values_config_path}/matrix-admin.yml",
      {
        matrix_host = var.hostnames["${terraform.workspace}_matrix"]
        app_name    = "matrix-admin"
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = vault_mount.ixo.path
}

#module "hummingbot" {
#  source = "./modules/argocd_application"
#  application = {
#    name = "hummingbot"
#    namespace = kubernetes_namespace_v1.hummingbot.metadata[0].name
#    owner = "hummingbot"
#    repository = local.ixo_helm_chart_repository
#    path = "charts/${terraform.workspace}/hummingbot/deploy"
#  }
#  argo_namespace   = module.argocd.argo_namespace
#  vault_mount_path = vault_mount.ixo.path
#}

module "cert-issuer" {
  depends_on = [module.argocd]
  source     = "./modules/cert-manager"
}

module "postgres-operator" {
  depends_on = [module.argocd]
  source     = "./modules/postgres-operator"
  clusters = [
    {
      # Matrix Postgres Cluster
      pg_cluster_name        = var.pg_matrix.pg_cluster_name
      pg_cluster_namespace   = var.pg_matrix.namespace
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

module "ixo_loki_logs" {
  depends_on = [module.argocd]
  source     = "./modules/loki_logs"

  matchNamespaces = [
    kubernetes_namespace_v1.ixo_core.metadata[0].name,
    module.argocd.namespaces_helm["nginx-ingress-controller"].metadata[0].name,
    module.argocd.namespaces_helm["matrix"].metadata[0].name,
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
  source    = "./modules/gcp_kms"
  name      = "matrix-${terraform.workspace}"
  namespace = module.argocd.namespaces_helm["matrix"].metadata[0].name
}

module "gcp_kms_core" {
  source    = "./modules/gcp_kms"
  name      = "core-${terraform.workspace}"
  namespace = kubernetes_namespace_v1.ixo_core.metadata[0].name
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
  dex_host                 = var.hostnames["${terraform.workspace}_dex"]
  oidc_client_secret       = random_password.vault_dex_oidc_secret.result
  vault_host               = var.hostnames["${terraform.workspace}_vault"]
  vault_terraform_password = var.vultr_api_key
  org                      = var.org
}

module "matrix_init" {
  source = "./modules/matrix"

  kube_config_path = module.kubernetes_cluster.kubeconfig_path
  namespace        = module.argocd.namespaces_helm["matrix"].metadata[0].name
  vault_mount_path = vault_mount.ixo.path
}

module "external_dns_cloudflare" {
  count  = terraform.workspace == "testnet" || terraform.workspace == "mainnet" ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "external-dns-cloudflare"
    namespace  = kubernetes_namespace_v1.external_dns_cloudflare.metadata[0].name
    owner      = ""
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

#module "cosmos" {
#  source          = "./modules/cosmos_operator"
#  kubeconfig_path = abspath(module.kubernetes_cluster.kubeconfig_path)
#  cosmos_operator = {
#    image = "ghcr.io/strangelove-ventures/cosmos-operator"
#    tag   = "v0.21.8"
#  }
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