terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}

resource "kubernetes_config_map_v1" "init_sql" {
  for_each = { for cluster in var.clusters : cluster.pg_cluster_namespace => cluster }
  metadata {
    name      = "${each.value.pg_cluster_name}-init-sql"
    namespace = each.value.pg_cluster_namespace
  }

  data = {
    "init.sql" = each.value.initSql != null ? each.value.initSql : ""
  }
}

resource "kubectl_manifest" "cluster" {
  for_each   = { for cluster in var.clusters : cluster.pg_cluster_namespace => cluster }
  depends_on = [kubernetes_config_map_v1.init_sql]
  yaml_body = templatefile("${path.module}/crds/cluster.yml",
    {
      pg_cluster_name      = each.value.pg_cluster_name
      pg_namespace         = each.value.pg_cluster_namespace
      pg_image             = each.value.pg_image
      pg_image_tag         = each.value.pg_image_tag
      pg_version           = each.value.pg_version
      pg_instances         = each.value.pg_instances
      pg_users             = each.value.pg_users
      pgbackrest_image     = each.value.pgbackrest_image
      pgbackrest_image_tag = each.value.pgbackrest_image_tag
      pgbackrest_repos     = each.value.pgbackrest_repos
    }
  )
}

resource "time_sleep" "wait_for_secret" {
  for_each        = { for cluster_key, cluster in var.clusters : cluster_key => yamldecode(cluster.pg_users) if cluster.pg_users != "" }
  depends_on      = [kubectl_manifest.cluster]
  create_duration = "5s"
}

data "kubernetes_secret_v1" "user_secret" {
  depends_on = [time_sleep.wait_for_secret]
  for_each   = { for idx, count in local.iterate_usernames : idx => count }
  //noinspection HILUnresolvedReference
  metadata {
    name      = "${each.value.pg_cluster_name}-pguser-${each.value.username}"
    namespace = each.value.pg_cluster_namespace
  }
}