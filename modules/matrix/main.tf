module "matrix_release" {
  source  = "terraform-module/release/helm"
  version = "2.8.1"
  app = {
    name         = "matrix"
    chart        = "matrix-synapse"
    version      = var.matrix_version
    force_update = true
    deploy       = 1
  }
  values = [
    templatefile("${path.module}/matrix-values.yml", {})
  ]
  namespace  = kubernetes_namespace_v1.matrix.metadata[0].name
  repository = "https://ananace.gitlab.io/charts"
}

resource "kubernetes_namespace_v1" "matrix" {
  metadata {
    name = "matrix"
  }
}