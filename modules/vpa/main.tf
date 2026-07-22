terraform {
  required_providers {
    kubectl = {
      source = "alekc/kubectl"
    }
  }
}

resource "kubectl_manifest" "vpa_crd" {
  yaml_body = file("${path.module}/crds/vpa-crd-verticalpodautoscaler.yml")
}

resource "kubectl_manifest" "vpa_checkpoint_crd" {
  yaml_body = file("${path.module}/crds/vpa-crd-verticalpodautoscalercheckpoint.yml")
}
