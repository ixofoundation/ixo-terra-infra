variable "clusters" {
  type = list(object(
    {
      pg_cluster_name      = string
      pg_cluster_namespace = string
      pg_image             = string
      pg_image_tag         = string
      pg_version           = string
      pg_instances         = string
      pg_users             = string
      pg_usernames         = list(string)
      pgbackrest_image     = string
      pgbackrest_image_tag = string
      pgbackrest_repos     = string
      initSql              = optional(string)
    }
    )
  )
}