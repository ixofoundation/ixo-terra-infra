terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}

resource "vault_kv_secret_v2" "this" {
  count               = var.create_kv ? 1 : 0
  mount               = var.vault_mount_path
  name                = var.application.name
  cas                 = 1
  delete_all_versions = true
  data_json = jsonencode(
    {
      WEB3_KEY   = "",
      WEB3_PROOF = "",
    }
  )
  custom_metadata {
    max_versions = 5
  }
}

resource "kubernetes_secret_v1" "repository" {
  metadata {
    name      = var.application.name
    namespace = var.argo_namespace
    labels = {
      "argocd.argoproj.io/secret-type" : "repository"
    }
  }
  data = {
    type : "git"
    url : var.application.repository
    githubAppID : 1
    githubAppInstallationID : 2
  }
}

# Create Argo Git Application
resource "kubectl_manifest" "application" {
  yaml_body = templatefile("${path.module}/crds/argo-application.yml",
    {
      name           = var.application.name
      namespace      = var.application.namespace
      owner          = var.application.owner
      argo_namespace = var.argo_namespace
      workspace      = terraform.workspace
      repository     = var.application.repository
      helm_values    = var.application.values_override != null ? var.application.values_override : ""
      path           = var.application.path != null ? var.application.path : "charts/${terraform.workspace}/${var.application.owner}/${var.application.name}"
    }
  )
}