# Cloudflare private network tunnels — connect ixo's K8s cluster to partner
# Postgres DBs via Cloudflare Zero Trust, with no inbound ports or VPN required.
# Mainnet only.
module "cloudflare_supamoto_tunnel" {
  count  = terraform.workspace == "mainnet" ? 1 : 0
  source = "./modules/cloudflare-partner-tunnel"

  cloudflare_account_id   = var.cloudflare_account_id
  cloudflare_api_token    = var.cloudlfare_supamoto_ecs_tunnel
  cloudflare_zone_id      = var.cloudflare_ixo_earth_zone_id
  environment             = terraform.workspace
  partner_name            = "supamoto"
  pg_cname                = "supamoto-pg"
  docker_postgres_service = "matrix_postgres"
  namespace               = "supamoto-tunnel"

  providers = {
    cloudflare     = cloudflare
    cloudflare.dns = cloudflare.dns
  }
}

module "cloudflare_digihub_tunnel" {
  count  = terraform.workspace == "mainnet" ? 1 : 0
  source = "./modules/cloudflare-partner-tunnel"

  cloudflare_account_id   = var.cloudflare_account_id
  cloudflare_api_token    = var.cloudlfare_supamoto_ecs_tunnel
  cloudflare_zone_id      = var.cloudflare_ixo_earth_zone_id
  environment             = terraform.workspace
  partner_name            = "digihub"
  pg_cname                = "digihub-pg"
  docker_postgres_service = "matrix_postgres"
  namespace               = "digihub-tunnel"

  providers = {
    cloudflare     = cloudflare
    cloudflare.dns = cloudflare.dns
  }
}

# Reverse direction of the partner tunnels: cloudflared runs in our cluster and
# exposes ixo-postgres (via pgbouncer) at workers-pg.ixo.earth so Cloudflare
# Workers can connect through Hyperdrive, authenticated with an Access service
# token. Currently used by the supamoto-bot worker (supamoto-bot db/user).
# Deployed on all environments; hostname is workers-pg.ixo.earth on mainnet and
# workers-pg-<env>.ixo.earth elsewhere.
module "cloudflare_workers_db_tunnel" {
  source = "./modules/cloudflare-workers-db-tunnel"

  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_zone_id    = var.cloudflare_ixo_earth_zone_id
  environment           = terraform.workspace
  name                  = "workers"
  pg_cname              = terraform.workspace == "mainnet" ? "workers-pg" : "workers-pg-${terraform.workspace}"
  namespace             = "workers-db-tunnel"
  postgres_service_host = "${var.pg_ixo.pg_cluster_name}-pgbouncer.${kubernetes_namespace_v1.ixo-postgres.metadata[0].name}.svc.cluster.local"

  providers = {
    cloudflare     = cloudflare
    cloudflare.dns = cloudflare.dns
  }
}

# AWS VPC module (only created when using AWS)
module "aws_vpc" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  source = "./modules/aws/vpc"

  env_config     = var.environments[terraform.workspace].aws_vpc_config
  project_name   = var.org
  environment    = terraform.workspace
  is_development = coalesce(var.environments[terraform.workspace].is_development, false)
  vpc_cidr       = "10.0.0.0/16"
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
    initial_node_pool_quantity  = 7
    initial_node_pool_scaler    = false
    initial_node_pool_min_nodes = 1
    initial_node_pool_max_nodes = 1
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
    node_disk_size          = 50
    node_desired_capacity   = var.environments[terraform.workspace].is_development != true ? 3 : 3
    node_max_capacity       = var.environments[terraform.workspace].is_development != true ? 10 : 5
    node_min_capacity       = var.environments[terraform.workspace].is_development != true ? 3 : 1
    node_key_name           = null
    node_security_group_ids = null
  }
}

module "argocd" {
  depends_on = [module.kubernetes_cluster]
  source     = "./modules/argocd"
  hostnames = {
    (terraform.workspace) = local.dns_for_environment[terraform.workspace]["prometheus_stack"]
  }
  github_client_id         = var.oidc_argo.clientId
  github_client_secret     = var.oidc_argo.clientSecret
  argo_version             = var.versions["argocd"]
  org                      = var.org
  cert_manager_enabled  = var.environments[terraform.workspace].application_configs["cert_manager"].enabled
  vault_mount_path      = local.vault_mount_path
  image_updater_enabled = var.environments[terraform.workspace].application_configs["argocd_image_updater"].enabled
  git_repositories = [
    {
      name       = "ixofoundation"
      repository = var.ixo_helm_chart_repository
    }
  ]
  applications_helm = [
  ]
}

module "argocd_image_updater" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["argocd_image_updater"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "argocd-image-updater"
    namespace = module.argocd.argo_namespace
    helm = {
      isOci    = false
      chart    = "argocd-image-updater"
      revision = "1.2.4"
    }
    repository      = "https://argoproj.github.io/argo-helm"
    values_override = file("${local.helm_values_config_path}/argocd-image-updater-values.yml")
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "chromadb" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["chromadb"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "chromadb"
    namespace = kubernetes_namespace_v1.chromadb.metadata[0].name
    helm = {
      isOci    = false
      chart    = "chromadb"
      revision = var.versions["chromadb"]
    }
    repository = "https://amikos-tech.github.io/chromadb-chart/"
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

# IXO-3541: resolve this workspace's VKE VPC subnet for set-real-ip-from
data "vultr_instances" "vke_nodes" {
  filter {
    name   = "region"
    values = [local.region_ids["Amsterdam"]]
  }
}

data "vultr_vpc" "vke_network" {
  count = length(try(local.vke_node_probe.vpc_ids, [])) > 0 ? 1 : 0
  filter {
    name   = "id"
    values = [local.vke_node_probe.vpc_ids[0]]
  }
}

# IXO-3541: resolve the ingress LB's public IP. The Service status stops exposing the IP once
# the vultr-loadbalancer-hostname annotation is set, so we look the LB up at Vultr directly.
# The CCM names LBs with Kubernetes' default LB name: "a" + Service UID (dashes stripped),
# truncated to 32 chars. Requires the ingress Service to already exist in the environment —
# only add an env to proxy_protocol_environments after its ingress controller is deployed.
data "kubernetes_service_v1" "ingress_nginx_lb" {
  count = local.enable_proxy_protocol ? 1 : 0
  metadata {
    name      = "nginx-ingress-controller"
    namespace = "ingress-nginx"
  }
}

data "vultr_load_balancer" "ingress" {
  count = local.enable_proxy_protocol ? 1 : 0
  filter {
    name   = "label"
    values = [substr("a${replace(data.kubernetes_service_v1.ingress_nginx_lb[0].metadata[0].uid, "-", "")}", 0, 32)]
  }
}

# IXO-3541: A record for the vultr-loadbalancer-hostname annotation. Must exist and resolve
# BEFORE the ingress Service flips to PROXY protocol, otherwise in-cluster clients cannot
# reach the ingress at all. DNS-only (not proxied) — Cloudflare must not terminate this.
resource "cloudflare_record" "ingress_lb" {
  count    = local.enable_proxy_protocol ? 1 : 0
  provider = cloudflare.dns
  zone_id  = var.cloudflare_ixo_earth_zone_id
  name     = trimsuffix(local.ingress_lb_hostname, ".ixo.earth")
  content  = data.vultr_load_balancer.ingress[0].ipv4
  type     = "A"
  proxied  = false
  ttl      = 300
}

module "ingress_nginx" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["ingress_nginx"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "nginx-ingress-controller"
    namespace = kubernetes_namespace_v1.ingress_nginx.metadata[0].name
    helm = {
      isOci             = true
      chart             = "nginx-ingress"
      revision          = var.versions["nginx-ingress-controller"]
      ignoreDifferences = local.nginx_ignore_differences
    }
    repository = "ghcr.io/nginx/charts"
    values_override = templatefile("${local.helm_values_config_path}/f5-nginx-ingress-controller-values.yml",
      {
        host                  = local.dns_for_environment[terraform.workspace]["prometheus_stack"]
        enable_proxy_protocol = local.enable_proxy_protocol # IXO-3541
        lb_hostname           = local.ingress_lb_hostname
        set_real_ip_from      = local.vke_private_subnet
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
    name       = "postgres-operator"
    namespace  = kubernetes_namespace_v1.postgres_operator.metadata[0].name
    repository = "registry.developers.crunchydata.com/crunchydata"
    helm = {
      isOci    = true
      chart    = "pgo"
      revision = var.versions["postgres-operator"]
    }
    #path            = "helm/install"
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
      isOci    = true
      chart    = "redis"
      revision = var.versions["redis"]
    }
    repository = "registry-1.docker.io/bitnamicharts"
    values_override = templatefile("${local.helm_values_config_path}/redis-values.yml", {
      storage_class     = local.storage_class_for_environment[terraform.workspace]["redis"]
      storage_size      = local.storage_size_for_environment[terraform.workspace]["redis"]
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
      host                      = local.dns_for_environment[terraform.workspace]["prometheus_stack"]
      blackbox_targets          = yamlencode(local.synthetic_monitoring_endpoints)
      grafana_oidc_secret       = random_password.grafana_dex_oidc_secret.result
      dex_host                  = local.dns_for_environment[terraform.workspace]["dex"]
      org                       = var.org
      environment               = terraform.workspace
      additional_scrape_metrics = var.additional_prometheus_scrape_metrics[terraform.workspace]
      storage_class             = var.storage_classes["bulk"]
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

module "vault_argocd_watcher" {
  depends_on = [module.argocd, module.vault]
  count      = var.environments[terraform.workspace].application_configs["vault_argocd_watcher"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name       = "vault-argocd-watcher"
    namespace  = kubernetes_namespace_v1.vault_argocd_watcher.metadata[0].name
    repository = "https://github.com/ixoworld/vault-argocd-watcher"
    path       = "chart/vault-argocd-watcher"
    values_override = templatefile(
      "${local.helm_values_config_path}/vault-argocd-watcher.yml",
      {
        vault_mount    = local.vault_mount_path
        argo_namespace = module.argocd.argo_namespace
        watched_apps   = local.vault_watched_apps
      }
    )
  }
  create_kv        = var.environments[terraform.workspace].application_configs["vault_argocd_watcher"].create_kv
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
    repository = "https://grafana.github.io/helm-charts"
    values_override = templatefile("${local.helm_values_config_path}/loki-values.yml",
      {
        service_account = indent(8, module.gcp_kms_loki.gcp_key_secret_data["key.json"])
        gcs_bucket      = google_storage_bucket.loki_logs_backups[0].name
        storage_class   = var.storage_classes["bulk"]
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
      isOci             = false
      chart             = "matrix-synapse"
      revision          = var.versions["matrix"]
      ignoreDifferences = local.matrix_ignore_differences
    }
    repository = "https://ananace.gitlab.io/charts"
    values_override = templatefile("${local.helm_values_config_path}/matrix-values.yml",
      {
        pg_host                  = "${var.pg_matrix.pg_cluster_name}-primary.matrix-synapse.svc.cluster.local"
        pg_username              = "synapse"
        pg_cluster_name          = var.pg_matrix.pg_cluster_name
        host                     = local.dns_for_environment[terraform.workspace]["matrix"]
        kv_mount                 = var.vault_core_mount
        app_name                 = "matrix"
        gcs_bucket_url           = google_storage_bucket.matrix_backups[0].url
        storage_class            = var.storage_classes["bulk"]
        livekit_host             = local.dns_for_environment[terraform.workspace]["matrix_livekit"]
        matrix_whatsapp_enabled  = var.environments[terraform.workspace].application_configs["ixo_matrix_whatsapp"].enabled
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
    name       = "matrix-livekit"
    namespace  = kubernetes_namespace_v1.matrix_livekit.metadata[0].name
    repository = var.ixo_terra_infra_repository
    path       = "charts/matrix_livekit"
    values_override = templatefile("${local.helm_values_config_path}/matrix-livekit-values.yml", {
      host        = local.dns_for_environment[terraform.workspace]["matrix_livekit"]
      vault_mount = local.vault_mount_path
    })
  }
  argo_namespace = module.argocd.argo_namespace
  create_kv      = var.environments[terraform.workspace].application_configs["matrix_livekit"].create_kv
  kv_defaults = {
    LIVEKIT_URL    = ""
    LIVEKIT_KEY    = ""
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

module "external_secrets" {
  depends_on = [module.argocd, module.vault_init]
  count      = var.environments[terraform.workspace].application_configs["external_secrets"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name       = "external-secrets"
    namespace  = kubernetes_namespace_v1.external_secrets.metadata[0].name
    repository = "https://charts.external-secrets.io"
    helm = {
      isOci    = false
      chart    = "external-secrets"
      revision = var.versions["external-secrets"]
    }
    values_override = templatefile("${local.helm_values_config_path}/external-secrets-values.yml",
      {
        vault_mount = local.vault_mount_path
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "reloader" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["reloader"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name       = "reloader"
    namespace  = kubernetes_namespace_v1.reloader.metadata[0].name
    repository = "https://stakater.github.io/stakater-charts"
    helm = {
      isOci    = false
      chart    = "reloader"
      revision = var.versions["reloader"]
    }
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "vpa_crds" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["vpa"].enabled ? 1 : 0
  source     = "./modules/vpa"
}

module "vpa" {
  depends_on = [module.argocd, module.vpa_crds]
  count      = var.environments[terraform.workspace].application_configs["vpa"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name       = "vpa"
    namespace  = kubernetes_namespace_v1.vpa.metadata[0].name
    repository = "https://charts.fairwinds.com/stable"
    helm = {
      isOci    = false
      chart    = "vpa"
      revision = var.versions["vpa"]
      skipCrds = true
    }
    values_override = templatefile("${local.helm_values_config_path}/vpa-values.yml", {})
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
      host          = local.dns_for_environment[terraform.workspace]["uptime_kuma"]
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

# Issues and auto-renews wildcard Let's Encrypt certs for *.devnet.oracles.work
# and *.testnet.oracles.work, then syncs them to CloudFlare custom certificates
# so external CloudFlare Workers can serve HTTPS on those subdomains.
module "oracles_cert_sync" {
  count      = var.environments[terraform.workspace].application_configs["oracles_cert_sync"].enabled ? 1 : 0
  depends_on = [module.cert-issuer]
  source     = "./modules/oracles-cert-sync"

  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id   = var.cloudflare_oracles_zone_id
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
      enable_pgbouncer       = false # Synapse manages its own connection pooling
    },
    {
      # IXO Cluster
      pg_cluster_name      = var.pg_ixo.pg_cluster_name
      pg_cluster_namespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
      pg_image             = var.pg_ixo.pg_image
      pg_image_tag         = var.pg_ixo.pg_image_tag
      pg_version           = var.pg_ixo.pg_version
      pg_instances = templatefile("${local.postgres_operator_config_path}/ixo-postgres-instances.yml", {
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
      enable_pgbouncer       = true
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
  source          = "./modules/gcp_kms"
  name            = "vault-${terraform.workspace}"
  namespace       = "vault"
  rotation_period = terraform.workspace == "mainnet" ? "7776000s" : "15552000s"
}

module "gcp_kms_matrix" {
  depends_on      = [module.matrix]
  source          = "./modules/gcp_kms"
  name            = "matrix-${terraform.workspace}"
  namespace       = kubernetes_namespace_v1.matrix.metadata[0].name
  rotation_period = terraform.workspace == "mainnet" ? "7776000s" : "15552000s"
}

module "gcp_kms_loki" {
  source          = "./modules/gcp_kms"
  name            = "loki-${terraform.workspace}"
  namespace       = kubernetes_namespace_v1.loki.metadata[0].name
  rotation_period = terraform.workspace == "mainnet" ? "7776000s" : "15552000s"
}

module "gcp_kms_core" {
  depends_on      = [module.argocd]
  source          = "./modules/gcp_kms"
  name            = "core-${terraform.workspace}"
  namespace       = kubernetes_namespace_v1.ixo_core.metadata[0].name
  rotation_period = terraform.workspace == "mainnet" ? "7776000s" : "15552000s"
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
  source     = "./modules/argocd_application"
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
      host                = local.dns_for_environment[terraform.workspace]["ghost"]
      ghost_password      = random_password.ghost_password.result
      ghost_smtp_user     = var.ixo_ghost_mailgun_user
      ghost_smtp_password = var.ixo_ghost_mailgun_password
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
  create_kv        = var.environments[terraform.workspace].application_configs["ghost"].create_kv
}

module "neo4j" { # TODO move to its own sub-module as it requires a Ingress resource.
  count  = var.environments[terraform.workspace].application_configs["neo4j"].enabled ? 1 : 0
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
      storage_class = var.storage_classes["fast"]
      storage_size  = "20Gi"
      org           = var.org
      password      = random_password.neo4j_password.result
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
  create_kv        = var.environments[terraform.workspace].application_configs["external_dns"].create_kv
  vault_mount_path = null
}

module "falco_security" {
  count      = var.environments[terraform.workspace].application_configs["falco_security"].enabled ? 1 : 0
  depends_on = [module.argocd]
  source     = "./modules/argocd_application"
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
      storage_size  = var.environments[terraform.workspace].application_configs["falco_security"].storage_size
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
  create_kv        = var.environments[terraform.workspace].application_configs["falco_security"].create_kv
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

resource "random_password" "matrix_whatsapp_as_token" {
  length  = 64
  special = false
  numeric = false
  lower   = true
  upper   = true
}

resource "random_password" "matrix_whatsapp_hs_token" {
  length  = 64
  special = false
  numeric = false
  lower   = true
  upper   = true
}

module "searxng" {
  count  = var.environments[terraform.workspace].application_configs["searxng"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "searxng"
    namespace  = kubernetes_namespace_v1.searxng.metadata[0].name
    repository = var.ixo_helm_chart_repository # TODO fork and update to our own repository as it is not maintainted.
    path       = "charts/${terraform.workspace}/ixoworld/searxng"
    isHelm     = false
    values_override = templatefile("${local.helm_values_config_path}/searxng-values.yml", {
      vault_mount = local.vault_mount_path
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
  create_kv        = var.environments[terraform.workspace].application_configs["searxng"].create_kv
  kv_defaults = {
    SECRET_KEY = ""
  }
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
  host           = local.dns_for_environment[terraform.workspace]["nomic_embedding"]
  enable_tls     = true

  ingress_annotations = {
    "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    "nginx.org/proxy-read-timeout"   = "300"
    "nginx.org/proxy-send-timeout"   = "300"
    "acme.cert-manager.io/http01-edit-in-place" = "true"
  }
}