terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}

resource "kubectl_manifest" "cluster" {
  yaml_body = templatefile("${path.module}/crds/cluster.yml",
    {
      pg_cluster_name      = var.cluster.pg_cluster_name
      pg_namespace         = var.cluster.pg_cluster_namespace
      pg_image             = var.cluster.pg_image
      pg_image_tag         = var.cluster.pg_image_tag
      pg_version           = var.cluster.pg_version
      pg_instances         = var.cluster.pg_instances
      pgbackrest_image     = var.cluster.pgbackrest_image
      pgbackrest_image_tag = var.cluster.pgbackrest_image_tag
      pgbackrest_repos     = var.cluster.pgbackrest_repos
    }
  )
}