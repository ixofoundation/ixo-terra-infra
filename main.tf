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

# TODO Migrate Vault to OIDC issuer for root token to have Terraform create Mounts securely when moving to CI/CD.
resource "vault_mount" "ixo" {
  depends_on = [module.gcp_kms_vault, module.vault_init, module.argocd]
  path       = local.vault_core_mount
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
    namespace = module.argocd.namespaces_helm["nfs-provisioner"].metadata[0].name
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

#resource "kubernetes_persistent_volume_claim_v1" "shared_ops_storage" {
#  depends_on = [module.argocd]
#  metadata {
#    name      = "${var.org}-shared-ops-storage"
#    namespace = kubernetes_namespace_v1.ixo_core.metadata[0].name
#    labels = {
#      "app.kubernetes.io/name" = "${var.org}-shared-ops-storage"
#    }
#  }
#  spec {
#    access_modes = ["ReadWriteMany"]
#    resources {
#      requests = {
#        storage = "100Gi"
#      }
#    }
#    storage_class_name = "nfs"
#  }
#}

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