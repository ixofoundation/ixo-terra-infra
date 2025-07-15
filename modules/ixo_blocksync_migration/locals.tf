locals {
  blocksync_pod     = try(data.kubernetes_resources.blocksync_pod.objects[0], null)
  db_name           = var.db_info.useAlt ? "${var.db_info.pgUsername}_alt" : var.db_info.pgUsername
  database_endpoint = "postgresql://${var.db_info.pgUsername}:${var.db_info.pgPassword}@${var.db_info.pgCluster}-primary.${var.db_info.pgNamespace}.svc.cluster.local/${local.db_name}"
  
  # Create base environment variables from existing pod
  base_env_vars = { for env_var in local.blocksync_pod.spec.containers[0].env : env_var.name => env_var.value }
  
  # Merge base environment variables with overrides
  # Priority: DATABASE_URL (from database_endpoint) > env_overrides > base environment variables
  merged_env_vars = merge(
    local.base_env_vars,
    var.env_overrides,
    {
      DATABASE_URL = local.database_endpoint
    }
  )
}