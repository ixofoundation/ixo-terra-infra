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

module "kubernetes_cluster" {
  source                  = "./modules/kubernetes_cluster"
  cluster_firewall        = lookup(var.environments[terraform.workspace], "cluster_firewall", false)
  cluster_label           = "ixo-cluster-${terraform.workspace}"
  initial_node_pool_label = "ixo-${terraform.workspace}"
  initial_node_pool_plan  = "vc2-2c-4gb"
  cluster_region          = local.region_ids["Amsterdam"]
}

module "argocd" {
  depends_on = [module.kubernetes_cluster]
  source     = "./modules/argocd"
  hostnames  = var.hostnames
  git_repositories = [
    {
      name       = "ixofoundation"
      repository = local.ixo_helm_chart_repository
    },
    #    {
    #      name       = "matrix-server"
    #      repository = "https://gitlab.com/ananace/charts.git"
    #    }
    #    {
    #      name       = "matrix"
    #      namespace  = var.pg_matrix.namespace
    #      owner      = "ananace"
    #      path       = "charts/matrix-synapse"
    #      repository = "https://gitlab.com/ananace/charts"
    #      values_override = templatefile("${path.root}/config/yml/matrix/matrix-values.yml",
    #        {
    #          pg_host         = "${var.pg_matrix.pg_cluster_name}-primary.matrix-synapse.svc.cluster.local"
    #          pg_username     = "synapse"
    #          pg_cluster_name = var.pg_matrix.pg_cluster_name
    #        }
    #      )
    #    }
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
      values_override = templatefile("${local.helm_values_config_path}/nginx-ingress-controller-values.yml",
        {
          host = var.hostnames[terraform.workspace]
        }
      )
    },
    {
      name            = "postgres-operator"
      namespace       = "postgres-operator"
      chart           = "pgo"
      revision        = "5.5.0"
      repository      = "registry.developers.crunchydata.com/crunchydata"
      values_override = templatefile("${local.helm_values_config_path}/postgres-operator-values.yml", {})
      oci             = true
    },
    {
      name            = "prometheus-stack"
      namespace       = "prometheus"
      chart           = "kube-prometheus-stack"
      revision        = "56.8.0"
      repository      = "https://prometheus-community.github.io/helm-charts"
      values_override = templatefile("${local.helm_values_config_path}/prometheus.yml", {})
    },
    {
      name       = "external-dns"
      namespace  = "external-dns"
      chart      = "external-dns"
      revision   = "1.14.3"
      repository = "https://kubernetes-sigs.github.io/external-dns/"
      values_override = templatefile("${local.helm_values_config_path}/external-dns-values.yml", {
        VULTR_API_KEY = var.vultr_api_key
      })
    }
  ]
}

module "ixo_celnode" {
  source = "./modules/argocd_application"
  application = {
    name       = "cellnode"
    namespace  = "ixo-cellnode"
    owner      = "ixofoundation"
    repository = local.ixo_helm_chart_repository
    values_override = templatefile("${local.helm_values_config_path}/ixo-common.yml",
      {
        environment   = terraform.workspace
        app_name      = "cellnode"
        host          = var.hostnames[terraform.workspace]
        app_namespace = "ixo-cellnode"
        DB_ENDPOINT   = "postgresql://${var.pg_ixo.pg_users[0].username}:${module.postgres-operator.database_password[var.pg_ixo.pg_users[0].username]}@${var.pg_ixo.pg_cluster_name}-primary.${kubernetes_namespace_v1.ixo-postgres.metadata[0].name}.svc.cluster.local"
      }
    )
  }
  argo_namespace = module.argocd.argo_namespace
}

module "cert-issuer" {
  depends_on = [module.argocd]
  source     = "./modules/cert-manager"
}

module "postgres-operator" {
  depends_on = [module.argocd]
  source     = "./modules/postgres-operator"
  clusters = [
    #    {
    #      # Matrix Postgres Cluster
    #      pg_cluster_name      = var.pg_matrix.pg_cluster_name
    #      pg_cluster_namespace = module.argocd.namespaces_git["matrix"].metadata[0].name
    #      pg_image             = var.pg_matrix.pg_image
    #      pg_image_tag         = var.pg_matrix.pg_image_tag
    #      pg_version           = var.pg_matrix.pg_version
    #      pg_instances         = file("${local.postgres_operator_config_path}/matrix-postgres-instances.yml")
    #      pg_users             = file("${local.postgres_operator_config_path}/matrix-postgres-users.yml")
    #      pgbackrest_image     = var.pg_matrix.pgbackrest_image
    #      pgbackrest_image_tag = var.pg_matrix.pgbackrest_image_tag
    #      pgbackrest_repos     = file("${local.postgres_operator_config_path}/matrix-postgres-backups-repos.yml")
    #      initSql              = file("${path.root}/config/sql/matrix-init.sql")
    #    },
    {
      # IXO Cluster
      pg_cluster_name        = var.pg_ixo.pg_cluster_name
      pg_cluster_namespace   = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
      pg_image               = var.pg_ixo.pg_image
      pg_image_tag           = var.pg_ixo.pg_image_tag
      pg_version             = var.pg_ixo.pg_version
      pg_instances           = file("${local.postgres_operator_config_path}/ixo-postgres-instances.yml")
      pg_users               = local.pg_users_yaml
      pg_usernames           = local.pg_users_usernames
      pgbackrest_image       = var.pg_ixo.pgbackrest_image
      pgbackrest_image_tag   = var.pg_ixo.pgbackrest_image_tag
      pgbackrest_repos       = file("${local.postgres_operator_config_path}/ixo-postgres-backups-repos.yml")
      pgmonitoring_image     = var.pg_ixo.pgmonitoring_image
      pgmonitoring_image_tag = var.pg_ixo.pgmonitoring_image_tag
    }
  ]
}