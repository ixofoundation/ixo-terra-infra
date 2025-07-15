data "kubernetes_resources" "blocksync_pod" {
  api_version    = "v1"
  kind           = "Pod"
  namespace      = var.namespace
  label_selector = "app.kubernetes.io/name=${var.existing_blocksync_pod_label_name}"
}

resource "kubernetes_pod_v1" "this" {
  metadata {
    name      = var.migration_pod_name
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"    = var.migration_pod_name
      "app.kubernetes.io/part-of" = "ixo"
    }
  }
  spec {
    container {
      name  = var.migration_pod_name
      image = var.image == "null" ? local.blocksync_pod.spec.containers[0].image : var.image
      dynamic "env" {
        for_each = local.merged_env_vars
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }
}