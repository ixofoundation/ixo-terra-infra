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

module "kubernetes_cluster" {
  source                  = "./modules/kubernetes_cluster"
  cluster_firewall        = lookup(var.environments[terraform.workspace], "cluster_firewall", false)
  cluster_label           = "ixo-cluster-${terraform.workspace}"
  initial_node_pool_label = "ixo-${terraform.workspace}"
}

module "argocd" {
  depends_on = [module.kubernetes_cluster]
  source     = "./modules/argocd"
  git_repositories = [
    {
      name       = "ixofoundation"
      repository = local.ixo_helm_chart_repository
    },
    {
      name       = "matrix-server"
      repository = "https://gitlab.com/ananace/charts.git"
    }
  ]
  applications = [
    {
      name            = "cellnode"
      namespace       = "ixo-cellnode"
      owner           = "ixofoundation"
      repository      = local.ixo_helm_chart_repository
      values_override = templatefile("${local.helm_values_config_path}/ixo-common.yml", { environment = terraform.workspace })
    }
  ]
  applications_helm = [
    {
      name            = "cert-manager"
      namespace       = "cert-manager"
      chart           = "cert-manager"
      repository      = local.jetstack_helm_chart_repository
      revision        = "1.14.2"
      values_override = templatefile("${local.helm_values_config_path}/cert-manager-values.yml", {})
    },
    {
      name       = "nginx-ingress-controller"
      namespace  = "ingress-nginx"
      chart      = "ingress-nginx"
      revision   = "4.9.1"
      repository = "https://kubernetes.github.io/ingress-nginx"
    },
    {
      name       = "postgres-operator"
      namespace  = "postgres-operator"
      chart      = "pgo"
      revision   = "5.5.0"
      repository = "registry.developers.crunchydata.com/crunchydata"
      oci        = true
    }
  ]
}

module "cert-issuer" {
  depends_on = [module.argocd]
  source     = "./modules/cert-manager"
}

module "postgres-operator" {
  depends_on = [module.argocd]
  source     = "./modules/postgres-operator"
  cluster = {
    pg_cluster_name      = "ixo-${terraform.workspace}-cluster"
    pg_cluster_namespace = module.argocd.namespaces["postgres-operator"].metadata[0].name
    pg_image             = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres"
    pg_image_tag         = "ubi8-15.5-0"
    pg_version           = 15
    pg_instances         = file("${local.postgres_operator_config_path}/ixo-postgres-instances.yml")
    pgbackrest_image     = "registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest"
    pgbackrest_image_tag = "ubi8-2.47-2"
    pgbackrest_repos     = file("${local.postgres_operator_config_path}/ixo-postgres-backups-repos.yml")
  }
}

module "matrix" {
  source = "./modules/matrix"
}