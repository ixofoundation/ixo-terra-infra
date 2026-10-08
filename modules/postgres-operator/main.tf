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
                __path__: /pgdata/logs/postgres/postgresql*.log
                cluster: ixo
                name: ixo-postgres-promtail
                app_kubernetes_io_name: ixo-postgres-promtail
                app_kubernetes_io_part_of: ixo
    EOT
  }
}

resource "kubernetes_config_map_v1" "pgbackrest_metrics_queries" {
  for_each = { for cluster in var.clusters : cluster.pg_cluster_namespace => cluster if cluster.enable_otel }
  metadata {
    name      = "${each.value.pg_cluster_name}-pgbackrest-metrics-queries"
    namespace = each.value.pg_cluster_namespace
  }

  data = {
    "queries.yaml" = file("${path.module}/crds/pgbackrest-metrics-queries.yaml")
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
  depends_on = [kubernetes_config_map_v1.init_sql, kubernetes_secret_v1.gcs_secret_key, kubernetes_config_map_v1.promtail_postgres, kubernetes_config_map_v1.pgbackrest_metrics_queries]
  yaml_body = templatefile("${path.module}/crds/cluster.yml",
    {
      pg_cluster_name             = each.value.pg_cluster_name
      pg_namespace                = each.value.pg_cluster_namespace
      pg_image                    = each.value.pg_image
      pg_image_tag                = each.value.pg_image_tag
      pg_version                  = each.value.pg_version
      pg_instances                = each.value.pg_instances
      pg_users                    = each.value.pg_users
      pgbackrest_image            = each.value.pgbackrest_image
      pgbackrest_image_tag        = each.value.pgbackrest_image_tag
      pgbackrest_repos            = each.value.pgbackrest_repos
      pgmonitoring_image          = each.value.pgmonitoring_image != null ? each.value.pgmonitoring_image : ""
      pgmonitoring_image_tag      = each.value.pgmonitoring_image_tag != null ? each.value.pgmonitoring_image_tag : ""
      enable_pg_cron              = each.value.enable_pg_cron != null ? each.value.enable_pg_cron : false
      pg_cron_database            = each.value.pg_cron_database != null ? each.value.pg_cron_database : "postgres"
      enable_pgbouncer            = each.value.enable_pgbouncer != null ? each.value.enable_pgbouncer : false
      enable_sync_replication     = each.value.enable_sync_replication != null ? each.value.enable_sync_replication : false
      enable_otel                 = each.value.enable_otel != null ? each.value.enable_otel : false
      pgbackrest_metrics_interval = each.value.pgbackrest_metrics_interval != null ? each.value.pgbackrest_metrics_interval : "300s"
      shutdown                    = each.value.shutdown != null ? each.value.shutdown : false
      retention_full              = each.value.retention_full != null ? each.value.retention_full : 4
      retention_type              = each.value.retention_type != null ? each.value.retention_type : "count"
      gcs_repo2_bucket            = each.value.gcs_repo2_bucket != null ? each.value.gcs_repo2_bucket : ""
      repo2_retention_type        = each.value.repo2_retention_type != null ? each.value.repo2_retention_type : "time"
      repo2_retention_full        = each.value.repo2_retention_full != null ? each.value.repo2_retention_full : 365
      upgrade_name                = try(each.value.upgrade.name, "")
      environment                 = terraform.workspace
    }
  )
}

# Declarative major version upgrade. The operator takes no action until the referenced
# cluster is shut down, so this may be created in advance. Removing it after a completed
# upgrade does not revert the cluster.
resource "kubectl_manifest" "pgupgrade" {
  for_each = {
    for cluster in var.clusters : cluster.pg_cluster_namespace => cluster
    if cluster.upgrade != null
  }
  depends_on = [kubectl_manifest.cluster]
  yaml_body = templatefile("${path.module}/crds/pgupgrade.yml",
    {
      upgrade_name    = each.value.upgrade.name
      pg_namespace    = each.value.pg_cluster_namespace
      pg_cluster_name = each.value.pg_cluster_name
      from_version    = each.value.upgrade.from_version
      to_version      = each.value.upgrade.to_version
      transfer_method = each.value.upgrade.transfer_method
      cpu_request     = each.value.upgrade.cpu_request
      memory_request  = each.value.upgrade.memory_request
      memory_limit    = each.value.upgrade.memory_limit
    }
  )
}

resource "time_sleep" "wait_for_secret" {
  for_each   = { for cluster_key, cluster in var.clusters : cluster_key => yamldecode(cluster.pg_users) if cluster.pg_users != "" }
  depends_on = [kubectl_manifest.cluster]

  # Recreated whenever the user list changes
  triggers = {
    users = sha1(jsonencode(each.value))
  }

  # The operator needs time to create the secret for a newly added user before the
  # user_secret data sources below are read.
  create_duration = "30s"
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