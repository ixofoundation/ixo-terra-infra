# AWS VPC module (only created when using AWS)
module "aws_vpc" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  source = "./modules/aws/vpc"
  
  env_config = var.environments[terraform.workspace].aws_vpc_config
  project_name    = var.org
  environment     = terraform.workspace
  is_development  = coalesce(var.environments[terraform.workspace].is_development, false)
  vpc_cidr        = "10.0.0.0/16"
  availability_zones = [
    "${var.environments[terraform.workspace].aws_region}a",
    "${var.environments[terraform.workspace].aws_region}b",
    "${var.environments[terraform.workspace].aws_region}c"
  ]
}

module "kubernetes_cluster" {
  source         = "./modules/kubernetes_cluster"
  cloud_provider = var.cloud_provider
  depends_on     = [module.aws_vpc]
  # TODO instance types by cloud provider can be moved into variables.tf per environment
  vultr = {
    cluster_firewall            = lookup(var.environments[terraform.workspace], "cluster_firewall", false)
    cluster_label               = "ixo-cluster-${terraform.workspace}"
    initial_node_pool_label     = terraform.workspace == "mainnet" ? "ixo-main" : "ixo-${terraform.workspace}"
    initial_node_pool_plan      = "vhf-3c-8gb"
    k8_version                  = var.versions["kubernetes_cluster"]
    cluster_region              = local.region_ids["Amsterdam"]
    ha_controlplanes            = false
    initial_node_pool_quantity  = 5
    initial_node_pool_scaler    = true
    initial_node_pool_min_nodes = 5
    initial_node_pool_max_nodes = 6
  }
  
  aws = {
    cluster_name            = "ixo-cluster-${terraform.workspace}"
    cluster_version         = var.versions["kubernetes_cluster"]
    region                  = var.environments[terraform.workspace].aws_region
    environment             = terraform.workspace
    project_name            = var.org
    endpoint_public_access  = coalesce(var.environments[terraform.workspace].is_development, false) ? true : false
    public_access_cidrs     = coalesce(var.environments[terraform.workspace].is_development, false) ? ["0.0.0.0/0"] : ["10.0.0.0/16"]
    cluster_log_types       = var.environments[terraform.workspace].is_development != true ? ["api", "audit"] : ["api", "audit", "authenticator", "controllerManager", "scheduler"]
    node_instance_types     = ["t3.medium"]
    node_ami_type           = "AL2023_x86_64_STANDARD"
    node_capacity_type      = "ON_DEMAND"
    node_disk_size          = var.environments[terraform.workspace].is_development != true ? 800 : 600
    node_desired_capacity   = var.environments[terraform.workspace].is_development != true ? 3 : 3
    node_max_capacity       = var.environments[terraform.workspace].is_development != true ? 10 : 5
    node_min_capacity       = var.environments[terraform.workspace].is_development != true ? 3 : 1
    node_key_name           = null
    node_security_group_ids = null
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
  cert_manager_enabled = var.environments[terraform.workspace].application_configs["cert_manager"].enabled
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
    values_override = templatefile("${local.helm_values_config_path}/chromadb-values.yml", {
      storage_class = var.storage_classes["bulk"]
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
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
  vault_mount_path = local.vault_mount_path
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
  vault_mount_path = local.vault_mount_path
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
  vault_mount_path = local.vault_mount_path
}

module "redis" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["redis"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "redis"
    namespace = kubernetes_namespace_v1.redis.metadata[0].name
    helm = {
      isOci             = true
      chart             = "redis"
      revision          = var.versions["redis"]
    }
    repository = "registry-1.docker.io/bitnamicharts"
    values_override = templatefile("${local.helm_values_config_path}/redis-values.yml", {
      storage_class = local.storage_class_for_environment[terraform.workspace]["redis"]
      storage_size = local.storage_size_for_environment[terraform.workspace]["redis"]
      redis_secret_name = kubernetes_secret_v1.redis_secret[0].metadata[0].name
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "surrealdb" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["surrealdb"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "surrealdb"
    namespace = kubernetes_namespace_v1.surrealdb.metadata[0].name
    helm = {
      isOci    = false
      chart    = "surrealdb"
      revision = var.versions["surrealdb"]
    }
    repository = "https://helm.surrealdb.com"
    values_override = templatefile("${local.helm_values_config_path}/surrealdb-values.yml", {
      storage_class      = local.storage_class_for_environment[terraform.workspace]["surrealdb"]
      storage_size       = local.storage_size_for_environment[terraform.workspace]["surrealdb"]
      surrealdb_password = random_password.surrealdb_password.result
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
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
      storage_class = var.storage_classes["bulk"]
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
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
#   vault_mount_path = local.vault_mount_path
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
  vault_mount_path = local.vault_mount_path
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
  vault_mount_path = local.vault_mount_path
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
        gcs_bucket = google_storage_bucket.loki_logs_backups[0].name
        service_account = indent(8, module.gcp_kms_loki.gcp_key_secret_data["key.json"])
        storage_class = var.storage_classes["bulk"]
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
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
  vault_mount_path = local.vault_mount_path
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
  vault_mount_path = local.vault_mount_path
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
      ignoreDifferences = local.matrix_ignore_differences
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
        gcs_bucket_url  = google_storage_bucket.matrix_backups[0].url
        storage_class   = var.storage_classes["bulk"]
        livekit_host    = local.dns_for_environment[terraform.workspace]["matrix_livekit"]
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "matrix_livekit" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["matrix_livekit"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "matrix-livekit"
    namespace = kubernetes_namespace_v1.matrix_livekit.metadata[0].name
    repository = var.ixo_terra_infra_repository
    path = "charts/matrix_livekit"
    values_override = templatefile("${local.helm_values_config_path}/matrix-livekit-values.yml", {
      host = local.dns_for_environment[terraform.workspace]["matrix_livekit"]
      vault_mount = local.vault_mount_path
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  create_kv        = true
  kv_defaults = {
    LIVEKIT_URL = ""
    LIVEKIT_KEY = ""
    LIVEKIT_SECRET = ""
  }
  vault_mount_path = local.vault_mount_path
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
  vault_mount_path = local.vault_mount_path
}

module "descheduler" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["descheduler"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name       = "descheduler"
    namespace  = kubernetes_namespace_v1.descheduler.metadata[0].name
    repository = "https://kubernetes-sigs.github.io/descheduler/"
    helm = {
      isOci    = false
      chart    = "descheduler"
      revision = var.versions["descheduler"]
    }
    values_override = templatefile("${local.helm_values_config_path}/descheduler-values.yml", {})
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
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
        storage_class = var.storage_classes["bulk"]
      })
    argo_namespace   = module.argocd.argo_namespace
    vault_mount_path = local.vault_mount_path
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "matrix_admin" {
  count      = var.environments[terraform.workspace].application_configs["matrix_admin"].enabled ? 1 : 0
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
  vault_mount_path = local.vault_mount_path
}

# Creates a cert-manager issuer for the cluster.
module "cert-issuer" {
  count      = var.environments[terraform.workspace].application_configs["cert_manager"].enabled ? 1 : 0
  depends_on = [module.argocd, module.cert_manager]
  source     = "./modules/cert-manager"
}

module "postgres-operator" { # Sets up Cluster Instances
  count      = var.environments[terraform.workspace].application_configs["postgres_operator_crunchydata"].enabled ? 1 : 0
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
      pg_instances         = templatefile("${local.postgres_operator_config_path}/ixo-postgres-instances.yml", {
        storage_size = var.environments[terraform.workspace].application_configs["postgres_operator_crunchydata"].storage_size
      })
      pg_users             = local.pg_users_yaml
      pg_usernames         = local.pg_users_usernames
      pgbackrest_image     = var.pg_ixo.pgbackrest_image
      pgbackrest_image_tag = var.pg_ixo.pgbackrest_image_tag
      pgbackrest_repos = templatefile("${local.postgres_operator_config_path}/ixo-postgres-backups-repos.yml",
        {
          gcs_bucket = google_storage_bucket.postgres_backups[0].name
        }
      )
      pgmonitoring_image     = var.pg_ixo.pgmonitoring_image
      pgmonitoring_image_tag = var.pg_ixo.pgmonitoring_image_tag
      initSql                = file("${path.root}/config/sql/ixo-init.sql")
      enable_pg_cron         = true
      pg_cron_database       = "firecrawl"
    }
  ]
  gcs_key = file("${path.root}/credentials.json")
}

# module "hyperlane_validator" {
#   source = "./modules/hyperlane"
#   count      = var.environments[terraform.workspace].application_configs["hyperlane_validator"].enabled ? 1 : 0
#   providers = {
#     aws = aws
#   }
#   aws_region = var.environments[terraform.workspace].aws_region
#   environment = terraform.workspace
#   chain_names = var.environments[terraform.workspace].hyperlane.chain_names
#   metadata_chains = var.environments[terraform.workspace].hyperlane.metadata_chains
# }

module "ixo_loki_logs" {
  count      = var.environments[terraform.workspace].application_configs["loki"].enabled ? 1 : 0
  depends_on = [module.argocd]
  source     = "./modules/loki_logs"

  matchNamespaces = [
    kubernetes_namespace_v1.ixo_core.metadata[0].name,
    kubernetes_namespace_v1.ingress_nginx.metadata[0].name,
    kubernetes_namespace_v1.matrix.metadata[0].name,
    kubernetes_namespace_v1.ixo-postgres.metadata[0].name,
    kubernetes_namespace_v1.falco_security.metadata[0].name
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
  depends_on = [module.argocd, module.vault]
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
  vault_mount_path = local.vault_mount_path
}

module "ghost" {
  source = "./modules/argocd_application"
  count      = var.environments[terraform.workspace].application_configs["ghost"].enabled ? 1 : 0
  depends_on = [module.argocd, kubernetes_secret_v1.ghost_mysql_secret]
  application = {
    name       = "ghost"
    namespace  = kubernetes_namespace_v1.ghost.metadata[0].name
    repository = "registry-1.docker.io/bitnamicharts"
    helm = {
      isOci    = true
      chart    = "ghost"
      revision = var.versions["ghost"]
    }
    values_override = templatefile("${local.helm_values_config_path}/ghost-values.yml", {
      host = local.dns_for_environment[terraform.workspace]["ghost"]
      ghost_password = random_password.ghost_password.result
      ghost_smtp_user = var.ixo_ghost_mailgun_user
      ghost_smtp_password = var.ixo_ghost_mailgun_password
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
  create_kv        = false
}

module "neo4j" { # TODO move to its own sub-module as it requires a Ingress resource.
  count      = var.environments[terraform.workspace].application_configs["neo4j"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "neo4j"
    namespace  = kubernetes_namespace_v1.neo4j.metadata[0].name
    repository = "https://neo4j.github.io/helm-charts"
    helm = {
      isOci    = false
      chart    = "neo4j"
      revision = var.versions["neo4j"]
    }
    values_override = templatefile("${local.helm_values_config_path}/neo4j.yml", {
      storage_class = var.storage_classes["bulk"]
      storage_size = "100Gi"
      org = var.org
      password = random_password.neo4j_password.result
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
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

module "falco_security" {
  count      = var.environments[terraform.workspace].application_configs["falco_security"].enabled ? 1 : 0
  depends_on = [module.argocd]
  source = "./modules/argocd_application"
  application = {
    name       = "falco-security"
    namespace  = kubernetes_namespace_v1.falco_security.metadata[0].name
    repository = "https://falcosecurity.github.io/charts"
    helm = {
      isOci    = false
      chart    = "falco"
      revision = var.versions["falco_security"]
    }
    values_override = templatefile("${local.helm_values_config_path}/falco-values.yml", {
      storage_class = var.environments[terraform.workspace].application_configs["falco_security"].storage_class
      storage_size = var.environments[terraform.workspace].application_configs["falco_security"].storage_size
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
  create_kv        = false
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

module "nomic_embedding" {
  count  = var.environments[terraform.workspace].application_configs["nomic_embedding"].enabled ? 1 : 0
  source = "./modules/nomic_embedding"
  
  application_name = "nomic-embedding"
  namespace        = "nomic-embedding"
  create_namespace = true
  llama_batch_size = 2048
  # Backend selection (corrected for actual model availability):
  # - "llama_cpp": Exact model nomic-embed-text-v2-moe, 800MB-1.2GB memory (RECOMMENDED)
  # - "vllm": vLLM V1 with native embedding support, 2-3GB memory  
  # Note: Ollama does NOT have the V2 MoE model, only the older V1.5
  backend = "llama_cpp"
  
  # Resource configuration optimized for your 1-2GB constraint
  # llama.cpp backend will use these values automatically
  
  # Storage configuration (for model caching)
  storage_class = var.storage_classes["bulk"]
  
  # External access configuration
  enable_ingress = true
  host          = local.dns_for_environment[terraform.workspace]["nomic_embedding"]
  enable_tls    = true
  
  ingress_annotations = {
    "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    "nginx.ingress.kubernetes.io/proxy-read-timeout" = "300"
    "nginx.ingress.kubernetes.io/proxy-send-timeout" = "300"
  }
}