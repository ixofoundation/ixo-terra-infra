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

provider "aws" {
  region = var.environments[terraform.workspace].aws_region
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

data "kubernetes_service_v1" "nfs" {
  depends_on = [module.argocd]
  metadata {
    name      = "nfs-server-provisioner"
    namespace = kubernetes_namespace_v1.nfs_provisioner.metadata[0].name
  }
}

resource "kubernetes_persistent_volume_claim_v1" "common" {
  depends_on = [module.argocd, data.kubernetes_service_v1.nfs]
  metadata {
    name      = "${var.org}-common-storage"
    namespace = kubernetes_namespace_v1.ixo_core.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "${var.org}-common-storage"
    }
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "40Gi"
      }
    }
    storage_class_name = "nfs"
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
  count = var.environments[terraform.workspace].application_configs["postgres_operator_crunchydata"].enabled ? 1 : 0
  location = "US"
  name     = "${var.org}-${terraform.workspace}-core-postgres"
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
      storage_class = "NEARLINE"
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
      storage_class = "NEARLINE"
    }
    condition {
      age = 60 # Objects older than 60 days will be moved to NEARLINE storage class to save on costs.
    }
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