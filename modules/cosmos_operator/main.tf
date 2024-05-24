terraform {
  required_providers {
    kubectl = {
      source = "alekc/kubectl"
    }
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = "ixo-cosmos"
  }
}

resource "null_resource" "deploy_operator" {
  provisioner "local-exec" {
    command     = "export KUBECONFIG=${var.kubeconfig_path} && make deploy IMG=\"${var.cosmos_operator.image}:${var.cosmos_operator.tag}\""
    working_dir = "${path.module}/cosmos-operator"
  }
}

resource "kubectl_manifest" "full_node" {
  depends_on = [null_resource.deploy_operator]
  yaml_body = templatefile("${path.module}/crds/cosmos_full_node.yml",
    {
      namespace = kubernetes_namespace_v1.this.metadata[0].name
    }
  )
}