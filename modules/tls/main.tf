module "certmanager_release" {
  source  = "terraform-module/release/helm"
  version = "2.8.1"
  app = {
    name         = "cert-manager"
    chart        = "cert-manager"
    version      = var.cert_manager_version
    force_update = true
    deploy       = 1
  }
  namespace  = kubernetes_namespace_v1.cert_manager.metadata[0].name
  repository = "https://charts.jetstack.io"
}

resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}