variable "clusters" {
  type = list(object(
    {
      pg_cluster_name        = string
      pg_cluster_namespace   = string
      pg_image               = string
      pg_image_tag           = string
      pg_version             = string
      pg_instances           = string
      pg_users               = string
      pg_usernames           = list(string)
      pgbackrest_image       = string
      pgbackrest_image_tag   = string
      pgbackrest_repos       = string
      pgmonitoring_image     = optional(string)
      pgmonitoring_image_tag = optional(string)
      initSql                = optional(string)
      enable_pg_cron         = optional(bool, false)
      pg_cron_database       = optional(string, "postgres")
      enable_pgbouncer       = optional(bool, false)
      # Switches the cluster from the pgmonitor exporter to the OpenTelemetry collector.
      # Mandatory before moving to Postgres 18. Also replaces the promtail sidecar, so
      # metrics AND logs cut over together. Requires the OpenTelemetryMetrics and
      # OpenTelemetryLogs feature gates on the operator.
      enable_otel = optional(bool, false)

      # How often the ccp_backrest_* metrics (pgbackrest backup/archive status) are
      # collected, when enable_otel is true. The operator's own built-in default is 5s,
      # which calls `pgbackrest info` - a full GCS repo listing - every 5 seconds per
      # instance with no caching. Backup status cannot change faster than backups run
      # (weekly full, daily diff), so this is overridden to a much longer interval. See
      # crds/cluster.yml and crds/pgbackrest-metrics-queries.yaml.
      pgbackrest_metrics_interval = optional(string, "300s")

      # Patroni synchronous_mode (non-strict). Only meaningful on a cluster with at least
      # one standby; a single-instance cluster degrades to asynchronous either way. See the
      # root variables.tf for the trade-off. failsafe_mode is set unconditionally in
      # crds/cluster.yml and is not gated by this.
      enable_sync_replication = optional(bool, false)

      # pgBackRest repo1 retention. type "time" makes retention_full a number of DAYS
      # (predictable even when a scheduled full fails); "count" makes it a number of full
      # backups. Expiry is permanent and runs at the end of a backup.
      retention_type = optional(string, "count")
      retention_full = optional(number, 4)

      # When set, adds a GCS repo2 as a durable off-cluster copy alongside repo1.
      # Note archive-push writes WAL to ALL repos, so WAL is duplicated to repo2.
      gcs_repo2_bucket     = optional(string, "")
      repo2_retention_type = optional(string, "time")
      repo2_retention_full = optional(number, 365)

      # Stops the cluster. Required for the duration of a major version upgrade, because
      # pg_upgrade needs exclusive access to the data directory. Full downtime while true.
      shutdown = optional(bool, false)

      # When set, a PGUpgrade resource is created alongside the cluster and the cluster is
      # annotated to consent to it. Creating it is safe while the cluster is running — the
      # upgrade job waits for shutdown = true before doing anything.
      upgrade = optional(object({
        name            = string
        from_version    = number
        to_version      = number
        transfer_method = optional(string, "Copy")
        cpu_request     = optional(string, "500m")
        memory_request  = optional(string, "512Mi")
        memory_limit    = optional(string, "2Gi")
      }))
    }
    )
  )
}

variable "gcs_key" {
  type = string
}