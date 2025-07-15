terraform {
  required_providers {
    kubectl = {
      source = "alekc/kubectl"
    }
  }
}

resource "vault_kv_secret_v2" "this" {
  lifecycle {
    ignore_changes = [data_json]
  }
  count               = var.create_kv ? 1 : 0
  mount               = var.vault_mount_path
  name                = var.application.name
  cas                 = 1
  delete_all_versions = true
  data_json           = jsonencode(var.kv_defaults)
  custom_metadata {
    max_versions = 5
  }
}

# # Create ArgoCD repository Secret for OCI registries
# resource "kubernetes_secret_v1" "oci_repository_secret" {
#   count = local.isHelm && var.application.helm.isOci ? 1 : 0
  
#   metadata {
#     name      = "${var.application.name}-oci-repo"
#     namespace = var.argo_namespace
#     labels = {
#       "argocd.argoproj.io/secret-type" = "repository"
#     }
#   }
  
#   type = "Opaque"
  
#   data = {
#     url       = var.application.repository
#     name      = "${var.application.name}-oci"
#     type      = "helm"
#     enableOCI = "true"
#     username  = var.oci_repository_credentials.username != null ? var.oci_repository_credentials.username : ""
#     password  = var.oci_repository_credentials.password != null ? var.oci_repository_credentials.password : ""
#   }
# }

# Create Argo Git Application
resource "kubectl_manifest" "application" {
  # depends_on = [kubernetes_secret_v1.oci_repository_secret]
  
  yaml_body = local.isHelm == true ? templatefile("${path.module}/crds/argo-application-helm.yml",
    {
      name           = var.application.name
      namespace      = var.application.namespace
      argo_namespace = var.argo_namespace
      workspace      = terraform.workspace
      isOci          = var.application.helm.isOci
      chart          = var.application.helm.chart
      revision       = var.application.helm.revision
      ignoreDifferences = var.application.helm.ignoreDifferences != null ? var.application.helm.ignoreDifferences : "[]"
      repository     = var.application.repository
      helm_values    = var.application.values_override != null ? var.application.values_override : ""
    }
    ) : templatefile("${path.module}/crds/argo-application.yml",
    {
      name           = var.application.name
      namespace      = var.application.namespace
      argo_namespace = var.argo_namespace
      workspace      = terraform.workspace
      repository     = var.application.repository
      helm_values    = var.application.values_override != null ? var.application.values_override : ""
      path           = var.application.path
    }
  )
}