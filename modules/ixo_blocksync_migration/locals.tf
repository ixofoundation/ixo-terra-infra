locals {
  blocksync_pod     = try(data.kubernetes_resources.blocksync_pod.objects[0], null)
  db_name           = var.db_info.useAlt ? "${var.db_info.pgUsername}_alt" : var.db_info.pgUsername
  database_endpoint = "postgresql://${var.db_info.pgUsername}:${var.db_info.pgPassword}@${var.db_info.pgCluster}-primary.${var.db_info.pgNamespace}.svc.cluster.local/${local.db_name}"
}