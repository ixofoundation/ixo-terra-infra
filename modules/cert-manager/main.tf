terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}

resource "kubectl_manifest" "issuer" {
  yaml_body = templatefile("${path.module}/crds/issuer.yml", {})
}