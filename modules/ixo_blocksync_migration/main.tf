data "kubernetes_resources" "blocksync_pod" {
  api_version    = "v1"
  kind           = "Pod"
  namespace      = var.namespace
  label_selector = "app.kubernetes.io/name=${var.existing_blocksync_pod_label_name}"
}

resource "kubernetes_pod_v1" "this" {
  metadata {
    name      = "blocksync-migration"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = "blocksync-migration"
      "app.kubernetes.io/part-of" = "ixo"
    }
  }
  spec {
    container {
      name  = "blocksync-migration"
      image = local.blocksync_pod.spec.containers[0].image
      dynamic "env" {
        for_each = { for env_var in local.blocksync_pod.spec.containers[0].env : env_var.name => env_var.value }
        content {
          name  = env.key
          value = env.key == "DATABASE_URL" ? local.database_endpoint : env.value
        }
      }
    }
  }
}