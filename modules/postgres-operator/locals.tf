locals {
  iterate_usernames = flatten([
    for cluster in var.clusters : [
      for username in cluster.pg_usernames : {
        username             = username
        pg_cluster_name      = cluster.pg_cluster_name
        pg_cluster_namespace = cluster.pg_cluster_namespace
      }
    ]
  ])
}