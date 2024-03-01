terraform {
  required_version = ">= 1.2.0"

  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "2.19.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "5.18.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "3.25.0"
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

# For Initial Cluster Setup, This userpass needs to be manually created.
provider "vault" {
  auth_login_userpass {
    username = "terraform"
  }
  address = "https://${var.hostnames["${terraform.workspace}_vault"]}/"
}

provider "google" {
  project     = var.gcp_project_ids[terraform.workspace]
  credentials = file("${path.root}/credentials.json")
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
  path       = "ixo_core"
  type       = "kv-v2"
  options = {
    version = "2"
    type    = "kv-v2"
  }
  description = "IXO Core Services KV Secrets"
}