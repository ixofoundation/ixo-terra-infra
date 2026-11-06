terraform {
  required_providers {
    kubectl = {
      source = "alekc/kubectl"
    }
  }
}

# Ingress for redirect-only hosts (rewrites in f5-nginx-ingress-controller-values.yml).
# ssl-redirect off so the HTTP-01 challenge is not bounced to https.
resource "kubectl_manifest" "redirect" {
  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = var.name
      namespace = var.nginx_namespace
      annotations = {
        "cert-manager.io/cluster-issuer"            = "letsencrypt-staging"
        "acme.cert-manager.io/http01-edit-in-place" = "true"
        "ingress.kubernetes.io/ssl-redirect"        = "false"
      }
    }
    spec = {
      ingressClassName = "nginx"
      tls              = [{ hosts = var.hosts, secretName = var.tls_secret_name }]
      rules = [for h in var.hosts : {
        host = h
        http = {
          paths = [{
            path     = "/"
            pathType = "Prefix"
            backend  = { service = { name = "nginx-ingress-controller", port = { number = 80 } } }
          }]
        }
      }]
    }
  })
}
