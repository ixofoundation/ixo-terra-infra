module "argocd_release" {
  source  = "terraform-module/release/helm"
  version = "2.8.1"
  app = {
    name         = "argocd"
    chart        = "argo-cd"
    version      = "6.0.3"
    force_update = true
    deploy = 1
  }
  values = [templatefile("${path.module}/argo-values.yml", {})]
  namespace  = kubernetes_namespace_v1.app-argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
}

resource "kubernetes_namespace_v1" "app-argocd" {
  metadata {
    name = "app-argocd"
  }
}