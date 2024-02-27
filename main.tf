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

resource "kubernetes_namespace_v1" "ixo-postgres" {
  depends_on = [module.kubernetes_cluster]
  metadata {
    name = "ixo-postgres"
  }
}