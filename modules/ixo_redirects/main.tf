resource "kubernetes_ingress_v1" "redirect" {
  metadata {
    name      = "ixo-rerouting"
    namespace = var.nginx_namespace
    annotations = {
      "cert-manager.io/cluster-issuer" : "letsencrypt-staging"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts       = ["blockscantest.${terraform.workspace}.ixo.earth"]
      secret_name = "blockscan.${terraform.workspace}-tls"
    }
    rule {
      host = "blockscantest.${terraform.workspace}.ixo.earth"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "ingress-nginx-controller"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}