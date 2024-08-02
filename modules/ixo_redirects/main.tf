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
      hosts       = terraform.workspace == "testnet" ? ["blockscan.${terraform.workspace}.ixo.earth", "blockscan-pandora.${terraform.workspace}.ixo.earth"] : ["blockscan.${terraform.workspace}.ixo.earth"]
      secret_name = "blockscan.${terraform.workspace}-tls"
    }
    dynamic "rule" {
      for_each = terraform.workspace == "testnet" ? [1] : [0]
      content {
        host = "blockscan-pandora.ixo.earth"
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
    rule {
      host = "blockscan.${terraform.workspace}.ixo.earth"
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