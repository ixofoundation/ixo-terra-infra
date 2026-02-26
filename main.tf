terraform {
  required_version = ">= 1.2.0"

  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "2.19.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "5.18.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "3.25.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "kubernetes" {
  config_path = module.kubernetes_cluster.kubeconfig_path
}

provider "kubectl" {
  config_path      = module.kubernetes_cluster.kubeconfig_path
  load_config_file = true
}

provider "helm" {
  kubernetes {
    config_path = module.kubernetes_cluster.kubeconfig_path
  }
}

provider "vultr" {
  api_key     = var.vultr_api_key
  rate_limit  = 100
  retry_limit = 3
}

# Mock AWS provider to avoid authentication issues during billing suspension
provider "aws" {
  region                      = var.environments[terraform.workspace].aws_region
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
}

# For Initial Cluster Setup, This userpass needs to be manually created.
provider "vault" {
  auth_login_userpass {
    username = "terraform"
  }
  address         = "https://${local.dns_for_environment[terraform.workspace]["vault"]}/"
  skip_tls_verify = true
}

provider "google" {
  project     = var.gcp_project_ids[terraform.workspace]
  credentials = file("${path.root}/credentials.json") #TODO don't use a file and use another method for future CD.
}

resource "kubernetes_namespace_v1" "ixo_core" {
  depends_on = [module.kubernetes_cluster]
  metadata {
    name = "core"
  }
}

resource "kubernetes_namespace_v1" "ixo-postgres" {
  depends_on = [module.kubernetes_cluster]
  metadata {
    name = "ixo-postgres"
  }
}

#resource "kubernetes_namespace_v1" "hummingbot" {
#  depends_on = [module.kubernetes_cluster]
#  metadata {
#    name = "hummingbot"
#  }
#}

# TODO Migrate Vault to OIDC issuer for root token to have Terraform create Mounts securely when moving to CI/CD.
resource "vault_mount" "ixo" {
  depends_on = [module.gcp_kms_vault, module.vault_init, module.argocd]
  path       = local.vault_mount_path
  type       = "kv-v2"
  options = {
    version = "2"
    type    = "kv-v2"
  }
  description = "IXO Core Services KV Secrets"
}

resource "kubernetes_persistent_volume_claim_v1" "common" {
  depends_on = [module.argocd]
  metadata {
    name      = "${var.org}-core-common-storage"
    namespace = kubernetes_namespace_v1.ixo_core.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "${var.org}-core-common-storage"
    }
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "100Gi"
      }
    }
    storage_class_name = var.storage_classes["shared"]
  }
}

resource "kubernetes_persistent_volume_claim_v1" "common_matrix" {
  depends_on = [module.argocd]
  metadata {
    name      = "${var.org}-core-common-matrix-storage"
    namespace = kubernetes_namespace_v1.matrix.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "${var.org}-core-common-matrix-storage"
    }
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "100Gi"
      }
    }
    storage_class_name = var.storage_classes["shared"]
  }
}

resource "kubernetes_pod_v1" "filebrowser" {
  depends_on = [kubernetes_persistent_volume_claim_v1.common]
  metadata {
    name      = "devops-filebrowser"
    namespace = kubernetes_namespace_v1.ixo_core.metadata[0].name
    labels = {
      app = "devops-filebrowser"
    }
  }

  spec {
    container {
      name  = "filebrowser"
      image = "filebrowser/filebrowser:latest"

      args = ["--port", "8080" ]
      
      port {
        container_port = 8080
        name           = "http"
      }

      volume_mount {
        name       = "common-storage"
        mount_path = "/srv"
      }

      security_context {
        run_as_user = 0
      }

      resources {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
      }
    }

    volume {
      name = "common-storage"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim_v1.common.metadata[0].name
      }
    }
  }
}

resource "kubernetes_pod_v1" "filebrowser_matrix" {
  depends_on = [kubernetes_persistent_volume_claim_v1.common_matrix]
  metadata {
    name      = "devops-filebrowser-matrix"
    namespace = kubernetes_namespace_v1.matrix.metadata[0].name
    labels = {
      app = "devops-filebrowser-matrix"
    }
  }

  spec {
    container {
      name  = "filebrowser-matrix"
      image = "filebrowser/filebrowser:latest"

      args = ["--port", "8080" ]
      
      port {
        container_port = 8080
        name           = "http"
      }

      volume_mount {
        name       = "common-matrix-storage"
        mount_path = "/srv"
      }

      security_context {
        run_as_user = 0
      }

      resources {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
      }
    }

    volume {
      name = "common-matrix-storage"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim_v1.common_matrix.metadata[0].name
      }
    }
  }
}

resource "random_password" "vault_dex_oidc_secret" {
  length  = 16
  special = false
}

resource "random_password" "grafana_dex_oidc_secret" {
  length  = 16
  special = false
}

resource "kubernetes_namespace_v1" "external_dns_cloudflare" {
  metadata {
    name = "external-dns-cloudflare"
  }
}

resource "aws_iam_openid_connect_provider" "github_oidc" {
  count = terraform.workspace == "mainnet" ? 1 : 0
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # GitHub's current thumbprint (verify if needed)
}

resource "google_storage_bucket" "postgres_backups" {
  lifecycle {
    ignore_changes = [ lifecycle_rule ]
  }
  count = var.environments[terraform.workspace].application_configs["postgres_operator_crunchydata"].enabled ? 1 : 0
  location = "US"
  name     = "${var.org}-${terraform.workspace}-core-postgres"
  storage_class = "COLDLINE"
  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 365 # Objects older than 365 days will be deleted
    }
  }

  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "ARCHIVE"
    }
    condition {
      age = 60 # Objects older than 60 days will be moved to NEARLINE storage class to save on costs.
    }
  }
}

resource "google_storage_bucket" "matrix_backups" {
  count = var.environments[terraform.workspace].application_configs["matrix"].enabled ? 1 : 0
  location = "US"
  name     = "${var.org}-${terraform.workspace}-matrix"
  storage_class = "COLDLINE"
  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 365 # Objects older than 365 days will be deleted
    }
  }

  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "ARCHIVE"
    }
    condition {
      age = 60 # Objects older than 60 days will be moved to NEARLINE storage class to save on costs.
    }
  }

  lifecycle {
    ignore_changes = [ lifecycle_rule ]
  }
}

resource "google_storage_bucket" "loki_logs_backups" {
  count = var.environments[terraform.workspace].application_configs["loki"].enabled ? 1 : 0
  location = "US"
  name     = "${var.org}-${terraform.workspace}-loki-logs"
  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 730 # Objects older than 730 days will be deleted
    }
  }

  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
    condition {
      age = 60 # Objects older than 60 days will be moved to NEARLINE storage class to save on costs.
    }
  }
}

resource "kubernetes_secret_v1" "redis_secret" {
  depends_on = [module.argocd]
  count = var.environments[terraform.workspace].application_configs["redis"].enabled ? 1 : 0
  metadata {
    name = "redis-secret"
    namespace = kubernetes_namespace_v1.redis.metadata[0].name
  }
  data = {
    redis-password = random_password.redis_password.result
  }
}

resource "random_password" "redis_password" {
  length  = 12
  special = false
}

resource "random_password" "ghost_db_root_password" {
  length  = 16
  special = false
}

resource "random_password" "ghost_db_user_password" {
  length  = 16
  special = false
}

resource "random_password" "neo4j_password" {
  length  = 16
  special = false
}

resource "random_password" "ghost_password" {
  length  = 16
  special = false
}

resource "random_password" "surrealdb_password" {
  length  = 16
  special = false
}

resource "kubernetes_secret_v1" "ghost_mysql_secret" {
  metadata {
    name = "ghost-mysql-secret"
    namespace = kubernetes_namespace_v1.ghost.metadata[0].name
  }
  data = {
    mysql-root-password = random_password.ghost_db_root_password.result
    mysql-password = random_password.ghost_db_user_password.result
  }
}

resource "kubernetes_ingress_v1" "neo4j" {
  count      = var.environments[terraform.workspace].application_configs["neo4j"].enabled ? 1 : 0
  depends_on = [module.neo4j]
  metadata {
    name      = "neo4j"
    namespace = kubernetes_namespace_v1.neo4j.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"           = "letsencrypt-staging"
      "nginx.org/proxy-read-timeout"             = "3600"
      "nginx.org/proxy-send-timeout"             = "3600"
      "nginx.org/proxy-connect-timeout"          = "3600"
      "nginx.org/websocket-services"             = "neo4j"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts       = ["${local.dns_for_environment[terraform.workspace]["neo4j"]}"]
      secret_name = "neo4j-tls"
    }
    rule {
      host = local.dns_for_environment[terraform.workspace]["neo4j"]
      http {
        path {
          path = "/"
          backend {
            service {
              name = "neo4j"
              port {
                number = 7474
              }
            }
          }
        }
      }
    }
  }
}

# F5 NGINX Ingress Controller: TCP routing for Neo4j Bolt (port 7687).
# Requires GlobalConfiguration listener "neo4j-bolt" (from f5-nginx-ingress-controller-values).
# See: https://docs.nginx.com/nginx-ingress-controller/configuration/transportserver-resource/
# Note: This must be applied AFTER neo4j ingress is applied & certificate is created (neo4j-tls). (same goes for neo4j bolt tls config).
resource "kubectl_manifest" "neo4j_bolt_transport_server" {
  count      = var.environments[terraform.workspace].application_configs["neo4j"].enabled ? 1 : 0
  depends_on = [module.ingress_nginx, module.neo4j]

  yaml_body = <<-YAML
    apiVersion: k8s.nginx.org/v1
    kind: TransportServer
    metadata:
      name: neo4j-bolt
      namespace: ${kubernetes_namespace_v1.neo4j.metadata[0].name}
    spec:
      ingressClassName: nginx
      listener:
        name: neo4j-bolt
        protocol: TCP
      upstreams:
        - name: neo4j-bolt
          service: neo4j
          port: 7687
      action:
        pass: neo4j-bolt
  YAML
}

# NGINX Virtual Server Configuration, TODO improve modularity.
resource "kubectl_manifest" "prometheus_stack_virtual_server" {
  count = var.environments[terraform.workspace].application_configs["prometheus_stack"].enabled ? 1 : 0

  depends_on = [module.ingress_nginx, module.argocd, module.prometheus_stack]

  yaml_body = <<-YAML
    apiVersion: k8s.nginx.org/v1
    kind: VirtualServer
    metadata:
      name: prometheus-stack-host
      namespace: ${kubernetes_namespace_v1.ingress_nginx.metadata[0].name}
    spec:
      host: ${local.prometheus_stack_host}
      ingressClassName: nginx
      tls:
        secret: prometheus-stack-host-tls
        cert-manager:
          cluster-issuer: letsencrypt-staging
        redirect:
          enable: false
      upstreams:
      - name: grafana
        service: ${kubernetes_namespace_v1.prometheus_stack.metadata[0].name}/kube-prometheus-stack-grafana
        port: 80
      routes:
      - path: /argocd
        route: ${module.argocd.argo_namespace}/argocd-route
      - path: /grafana
        route: ${kubernetes_namespace_v1.prometheus_stack.metadata[0].name}/grafana-route
      - path: /
        action:
          pass: grafana
  YAML
}

resource "kubectl_manifest" "argocd_virtual_server_route" {
  count = var.environments[terraform.workspace].application_configs["prometheus_stack"].enabled ? 1 : 0

  depends_on = [module.argocd]

  yaml_body = <<-YAML
    apiVersion: k8s.nginx.org/v1
    kind: VirtualServerRoute
    metadata:
      name: argocd-route
      namespace: ${module.argocd.argo_namespace}
    spec:
      host: ${local.prometheus_stack_host}
      ingressClassName: nginx
      upstreams:
      - name: argocd-server
        service: argocd-server
        port: 443
        tls:
          enable: true
      subroutes:
      - path: /argocd
        action:
          pass: argocd-server
  YAML
}

resource "kubectl_manifest" "grafana_virtual_server_route" {
  count = var.environments[terraform.workspace].application_configs["prometheus_stack"].enabled ? 1 : 0

  depends_on = [module.prometheus_stack]

  yaml_body = <<-YAML
    apiVersion: k8s.nginx.org/v1
    kind: VirtualServerRoute
    metadata:
      name: grafana-route
      namespace: ${kubernetes_namespace_v1.prometheus_stack.metadata[0].name}
    spec:
      host: ${local.prometheus_stack_host}
      ingressClassName: nginx
      upstreams:
      - name: grafana
        service: kube-prometheus-stack-grafana
        port: 80
      subroutes:
      - path: /grafana
        action:
          pass: grafana
  YAML
}

# SLACK WEBHOOK URL SECRETS
resource "kubernetes_secret_v1" "slack_webhook_url" {
  metadata {
    name = "slack-webhook-url"
    namespace = kubernetes_namespace_v1.ixo_core.metadata[0].name
  }
  data = {
    webhook-url = ""
  }
}

resource "kubernetes_secret_v1" "slack_webhook_url_matrix" {
  metadata {
    name = "slack-webhook-url-matrix"
    namespace = kubernetes_namespace_v1.matrix.metadata[0].name
  }
  data = {
    webhook-url = ""
  }
}