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
      hosts       = lookup(local.hosts, terraform.workspace, ["blockscan.${terraform.workspace}.ixo.earth"])
      secret_name = "blockscan.${terraform.workspace}-tls"
    }
    dynamic "rule" {
      for_each = terraform.workspace == "testnet" ? [1] : []
      content {
        host = element(lookup(local.hosts, terraform.workspace, ["blockscan.${terraform.workspace}.ixo.earth"]), 1)
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
      host = element(lookup(local.hosts, terraform.workspace, ["blockscan.${terraform.workspace}.ixo.earth"]), 0)
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