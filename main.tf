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
  config_path    = module.kubernetes_cluster.kubeconfig_path
}

provider "kubectl" {
  config_path = module.kubernetes_cluster.kubeconfig_path
  load_config_file       = true
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

module "kubernetes_cluster" {
  source                  = "./modules/kubernetes_cluster"
  cluster_firewall        = lookup(var.environments[terraform.workspace], "cluster_firewall", false)
  cluster_label           = "ixo-cluster-${terraform.workspace}"
  initial_node_pool_label = "ixo-${terraform.workspace}"
}

module "argocd" {
  depends_on = [module.kubernetes_cluster]
  source = "./modules/argocd"
  argo_chart_repository = "https://github.com/ixofoundation/ixo-helm-charts"
  applications = [
    {
      name = "cellnode"
      namespace = "ixo-cellnode"
      owner = "ixofoundation"
    }
  ]
}

module "matrix" {
  source = "./modules/matrix"
}