terraform {
  required_version = ">= 1.2.0"

  required_providers {
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
    cloudflare = {
      source                = "cloudflare/cloudflare"
      version               = "~> 4.0"
      configuration_aliases = [cloudflare.dns]
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudlfare_supamoto_ecs_tunnel
}

provider "cloudflare" {
  alias     = "dns"
  api_token = var.cloudflare_api_token
}

provider "kubernetes" {
  config_path = module.kubernetes_cluster.kubeconfig_path
}

provider "kubectl" {
  config_path      = module.kubernetes_cluster.kubeconfig_path
  load_config_file = true
}

provider "helm" {
  kubernetes = {
    config_path = module.kubernetes_cluster.kubeconfig_path
  }
}


provider "aws" {
  region = var.environments[terraform.workspace].aws_region
  # Pin the AWS account so credentials for another account fail the plan.
  allowed_account_ids         = local.env.aws_account_id != null ? [local.env.aws_account_id] : null
  skip_credentials_validation = local.env.aws_account_id == null
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = local.env.aws_account_id == null

  dynamic "default_tags" {
    for_each = length(local.env.aws_default_tags) > 0 ? [1] : []
    content {
      tags = local.env.aws_default_tags
    }
  }
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

  # Fails the plan if an enabled app renders another env's live hostname (dns_guard_* in locals.tf).
  lifecycle {
    precondition {
      condition = length(local.dns_guard_violations) == 0
      error_message = join("\n", concat([
        "Cross-environment DNS hostname(s) on workspace '${terraform.workspace}'.",
        "",
        "These enabled apps render a hostname that does not carry this workspace's DNS",
        "segment (${coalesce(local.dns_guard_segment, "none")}), so they name another",
        "environment's live records. external-dns on this cluster runs registry: noop",
        "with no ownership TXT records, so applying this would OVERWRITE those live",
        "records with this cluster's load balancer and move live traffic.",
        "",
        "Offending apps (app = rendered host):",
        ], local.dns_guard_violations, [
        "",
        "Fix: give each one a literal dns_endpoint carrying this workspace's own segment",
        "in the workspace var-file (the prometheus_stack precedent), or a dns_prefix,",
        "which has the segment spliced in automatically. Do not disable this guard to",
        "get a plan through. Taking over the live hostname deliberately at cutover is a",
        "per-app line in dns_cutover_apps in the workspace var-file.",
      ]))
    }
  }
}

resource "kubernetes_namespace_v1" "ixo-postgres" {
  depends_on = [module.kubernetes_cluster]
  metadata {
    name = "ixo-postgres"
  }
}


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
  count      = local.live_overrides.common_storage_enabled ? 1 : 0
  depends_on = [module.argocd]
  metadata {
    name      = local.live_overrides.common_storage.name
    namespace = kubernetes_namespace_v1.ixo_core.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = local.live_overrides.common_storage.name
    }
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = local.live_overrides.common_storage.size
      }
    }
    storage_class_name = local.live_overrides.common_storage.storage_class
  }
}

resource "kubernetes_persistent_volume_claim_v1" "common_matrix" {
  count      = local.live_overrides.common_matrix_storage ? 1 : 0
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
  count      = local.live_overrides.devops_filebrowser ? 1 : 0
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

      args = ["--port", "8080"]

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
        claim_name = kubernetes_persistent_volume_claim_v1.common[0].metadata[0].name
      }
    }
  }
}

resource "kubernetes_pod_v1" "filebrowser_matrix" {
  count      = local.live_overrides.devops_filebrowser ? 1 : 0
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

      args = ["--port", "8080"]

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
        claim_name = kubernetes_persistent_volume_claim_v1.common_matrix[0].metadata[0].name
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

# Disabled: its AWS account was closed.
resource "aws_iam_openid_connect_provider" "github_oidc" {
  count = 0
  url   = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # GitHub's current thumbprint (verify if needed)
}

resource "google_storage_bucket" "postgres_backups" {
  count         = var.environments[terraform.workspace].application_configs["postgres_operator_crunchydata"].enabled ? 1 : 0
  location      = "US"
  name          = "${var.org}-${local.global_resource_name}-core-postgres"
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
      # Objects are COLDLINE from creation via the bucket's default storage class; this
      # moves them to ARCHIVE once they are unlikely to be read. Note ARCHIVE's 365-day
      # minimum duration starts at the transition, not at object creation, so objects
      # removed by the Delete rule above are billed for the remainder of that minimum.
      age = 60
    }
  }

  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
    condition {
      # Catches anything uploaded with an explicit class instead of the bucket default.
      matches_storage_class = ["STANDARD", "NEARLINE"]
    }
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      # pgBackRest expire deletes files, which versioning then keeps as noncurrent
      # versions. See the matrix bucket for why ARCHIVE is excluded.
      days_since_noncurrent_time = 30
      matches_storage_class      = ["STANDARD", "NEARLINE", "COLDLINE"]
    }
  }
}

resource "google_storage_bucket" "matrix_backups" {
  count         = var.environments[terraform.workspace].application_configs["matrix"].enabled ? 1 : 0
  location      = "US"
  name          = "${var.org}-${local.global_resource_name}-matrix"
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
      age = 60 # Objects older than 60 days will be moved to ARCHIVE storage class to save on costs.
    }
  }

  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
    condition {
      # Catches anything uploaded with an explicit class instead of the bucket default.
      matches_storage_class = ["STANDARD", "NEARLINE"]
    }
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      # Versioning keeps every overwritten or deleted object as a noncurrent version, and
      # nothing removed them: the old in-container Synapse zip backup re-uploaded the
      # day's zip on every OOM restart, leaving ~20TB of noncurrent versions across the
      # matrix buckets. 30 days is free under COLDLINE's 90-day minimum. ARCHIVE is
      # excluded because its 365-day minimum is billed whether it is deleted early or not,
      # so deleting it early would lose the copy and save nothing.
      days_since_noncurrent_time = 30
      matches_storage_class      = ["STANDARD", "NEARLINE", "COLDLINE"]
    }
  }
}

# Vault raft snapshots, in their own bucket.
resource "google_storage_bucket" "vault_snapshots" {
  count = local.vault_snapshot_enabled ? 1 : 0
  # Not "US" like the buckets above it; see vault_snapshot_location in variables.tf.
  location = var.environments[terraform.workspace].application_configs["vault"].vault_snapshot_location
  name     = "${var.org}-${local.global_resource_name}-vault-snapshots"
  # Small objects, short retention.
  storage_class = "STANDARD"

  # Every object is timestamped, so nothing is ever overwritten. Versioning is here only
  # so an accidental delete is recoverable for a week.
  versioning {
    enabled = true
  }

  # No per-object ACLs, no public access.
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = var.environments[terraform.workspace].application_configs["vault"].vault_snapshot_retention_days
    }
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      days_since_noncurrent_time = 7
    }
  }
}

# Snapshot job SA: create + read, no delete (rclone lists the destination before upload).
resource "google_storage_bucket_iam_member" "vault_snapshots_writer" {
  for_each = local.vault_snapshot_enabled && local.vault_snapshot_writer_sa_email != null ? toset([
    "roles/storage.objectCreator",
    "roles/storage.objectViewer",
  ]) : toset([])

  bucket = google_storage_bucket.vault_snapshots[0].name
  role   = each.value
  member = "serviceAccount:${local.vault_snapshot_writer_sa_email}"
}

resource "google_storage_bucket" "loki_logs_backups" {
  count    = var.environments[terraform.workspace].application_configs["loki"].enabled ? 1 : 0
  location = "US"
  name     = "${var.org}-${local.global_resource_name}-loki-logs"
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
  count      = var.environments[terraform.workspace].application_configs["redis"].enabled ? 1 : 0
  metadata {
    name      = "redis-secret"
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
    name      = "ghost-mysql-secret"
    namespace = kubernetes_namespace_v1.ghost.metadata[0].name
  }
  data = {
    mysql-root-password = random_password.ghost_db_root_password.result
    mysql-password      = random_password.ghost_db_user_password.result
  }
}

resource "kubernetes_ingress_v1" "neo4j" {
  count      = var.environments[terraform.workspace].application_configs["neo4j"].enabled || local.live_overrides.neo4j_ingress ? 1 : 0
  depends_on = [module.neo4j]
  metadata {
    name      = "neo4j"
    namespace = kubernetes_namespace_v1.neo4j.metadata[0].name
    annotations = merge({
      "cert-manager.io/cluster-issuer"            = "letsencrypt-staging"
      "acme.cert-manager.io/http01-edit-in-place" = "true"
      "nginx.org/proxy-read-timeout"              = "3600"
      "nginx.org/proxy-send-timeout"              = "3600"
      "nginx.org/proxy-connect-timeout"           = "3600"
      "nginx.org/websocket-services"              = "neo4j"
    }, local.live_overrides.neo4j_ssl_redirect_annotation ? { "ingress.kubernetes.io/ssl-redirect" = "false" } : {})
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts       = [local.neo4j_host]
      secret_name = "neo4j-tls"
    }
    rule {
      host = local.neo4j_host
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
  count      = var.environments[terraform.workspace].application_configs["neo4j"].enabled || local.live_overrides.neo4j_bolt_transport ? 1 : 0
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
          enable: ${local.live_overrides.grafana_tls_redirect}
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

# Redirect host for blockscan.devnet.ixo.earth (rewrites in f5-nginx-ingress-controller-values.yml).
# ssl-redirect off so the HTTP-01 challenge is not bounced to https.
resource "kubectl_manifest" "blockscan_devnet_ingress" {
  count = terraform.workspace == "devnet" ? 1 : 0

  depends_on = [module.ingress_nginx]

  yaml_body = <<-YAML
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: blockscan-rerouting
      namespace: ${kubernetes_namespace_v1.ingress_nginx.metadata[0].name}
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-staging
        acme.cert-manager.io/http01-edit-in-place: "true"
        ingress.kubernetes.io/ssl-redirect: "false"
    spec:
      ingressClassName: nginx
      tls:
      - hosts:
        - blockscan.devnet.ixo.earth
        secretName: blockscan-devnet-tls
      rules:
      - host: blockscan.devnet.ixo.earth
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-ingress-controller
                port:
                  number: 80
  YAML
}

# Same for testnet: blockscan.testnet.ixo.earth and blockscan-pandora.ixo.earth.
resource "kubectl_manifest" "blockscan_testnet_ingress" {
  count = terraform.workspace == "testnet" ? 1 : 0

  depends_on = [module.ingress_nginx]

  yaml_body = <<-YAML
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: blockscan-rerouting
      namespace: ${kubernetes_namespace_v1.ingress_nginx.metadata[0].name}
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-staging
        acme.cert-manager.io/http01-edit-in-place: "true"
        ingress.kubernetes.io/ssl-redirect: "false"
    spec:
      ingressClassName: nginx
      tls:
      - hosts:
        - blockscan.testnet.ixo.earth
        - blockscan-pandora.ixo.earth
        secretName: blockscan-testnet-tls
      rules:
      - host: blockscan.testnet.ixo.earth
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-ingress-controller
                port:
                  number: 80
      - host: blockscan-pandora.ixo.earth
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-ingress-controller
                port:
                  number: 80
  YAML
}

# SLACK WEBHOOK URL SECRETS
resource "kubernetes_secret_v1" "slack_webhook_url" {
  metadata {
    name      = "slack-webhook-url"
    namespace = kubernetes_namespace_v1.ixo_core.metadata[0].name
  }
  data = {
    webhook-url = ""
  }
}

resource "kubernetes_secret_v1" "slack_webhook_url_matrix" {
  metadata {
    name      = "slack-webhook-url-matrix"
    namespace = kubernetes_namespace_v1.matrix.metadata[0].name
  }
  data = {
    webhook-url = ""
  }
}

# Grafana admin credentials, for environments that opt in with grafana_admin_secret (see
# variables.tf). Read: kubectl -n prometheus get secret grafana-admin -o jsonpath='{.data.admin-password}' | base64 -d
resource "random_password" "grafana_admin" {
  count   = local.env.grafana_admin_secret ? 1 : 0
  length  = 32
  special = false
}

resource "kubernetes_secret_v1" "grafana_admin" {
  count = local.env.grafana_admin_secret ? 1 : 0
  metadata {
    name      = "grafana-admin"
    namespace = kubernetes_namespace_v1.prometheus_stack.metadata[0].name
  }
  data = {
    admin-user     = "admin"
    admin-password = random_password.grafana_admin[0].result
  }
}

resource "kubernetes_secret_v1" "alertmanager_slack_webhook" {
  metadata {
    name      = "alertmanager-slack-webhook"
    namespace = kubernetes_namespace_v1.prometheus_stack.metadata[0].name
  }
  data = {
    webhook-url = ""
  }
}