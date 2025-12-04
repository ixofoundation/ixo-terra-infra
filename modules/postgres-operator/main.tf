terraform {
  required_providers {
    kubectl = {
      source = "alekc/kubectl"
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

resource "kubernetes_config_map_v1" "promtail_postgres" {
  for_each = { for cluster in var.clusters : cluster.pg_cluster_namespace => cluster }
  metadata {
    name      = "promtail-config"
    namespace = each.value.pg_cluster_namespace
  }

  data = {
    "promtail.yaml" = <<-EOT
      server:
        http_listen_port: 9080
        grpc_listen_port: 0

      positions:
        filename: /tmp/positions.yaml

      clients:
        - url: http://loki.loki.svc.cluster.local:3100/loki/api/v1/push

      scrape_configs:
        - job_name: postgres-logs
          static_configs:
            - targets:
                - localhost
              labels:
                job: ixo-postgres/ixo-postgres-promtail
                __path__: /pgdata/*/log/postgresql*.log
                cluster: ixo
                name: ixo-postgres-promtail
                app_kubernetes_io_name: ixo-postgres-promtail
                app_kubernetes_io_part_of: ixo
    EOT
  }
}

resource "kubernetes_secret_v1" "gcs_secret_key" {
  for_each = { for cluster in var.clusters : cluster.pg_cluster_namespace => cluster }
  metadata {
    name      = "${each.value.pg_cluster_name}-gcs-pgbackrest-secret"
    namespace = each.value.pg_cluster_namespace
  }
  data = {
    "gcs-key.json" : var.gcs_key
  }
}

resource "kubectl_manifest" "cluster" {
  for_each   = { for cluster in var.clusters : cluster.pg_cluster_namespace => cluster }
  depends_on = [kubernetes_config_map_v1.init_sql, kubernetes_secret_v1.gcs_secret_key, kubernetes_config_map_v1.promtail_postgres]
  yaml_body = templatefile("${path.module}/crds/cluster.yml",
    {
      pg_cluster_name        = each.value.pg_cluster_name
      pg_namespace           = each.value.pg_cluster_namespace
      pg_image               = each.value.pg_image
      pg_image_tag           = each.value.pg_image_tag
      pg_version             = each.value.pg_version
      pg_instances           = each.value.pg_instances
      pg_users               = each.value.pg_users
      pgbackrest_image       = each.value.pgbackrest_image
      pgbackrest_image_tag   = each.value.pgbackrest_image_tag
      pgbackrest_repos       = each.value.pgbackrest_repos
      pgmonitoring_image     = each.value.pgmonitoring_image != null ? each.value.pgmonitoring_image : ""
      pgmonitoring_image_tag = each.value.pgmonitoring_image_tag != null ? each.value.pgmonitoring_image_tag : ""
      enable_pg_cron         = each.value.enable_pg_cron != null ? each.value.enable_pg_cron : false
      pg_cron_database       = each.value.pg_cron_database != null ? each.value.pg_cron_database : "postgres"
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