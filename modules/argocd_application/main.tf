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

# Create Argo Git Application
resource "kubectl_manifest" "application" {
  yaml_body = local.isHelm == true ? templatefile("${path.module}/crds/argo-application-helm.yml",
    {
      name                     = var.application.name
      namespace                = var.application.namespace
      argo_namespace           = var.argo_namespace
      workspace                = terraform.workspace
      isOci                    = var.application.helm.isOci
      chart                    = var.application.helm.chart
      revision                 = var.application.helm.revision
      ignoreDifferences        = var.application.helm.ignoreDifferences != null ? var.application.helm.ignoreDifferences : "[]"
      skipCrds                 = var.application.helm.skipCrds
      respectIgnoreDifferences = var.application.helm.respectIgnoreDifferences
      repository               = var.application.repository
      helm_values              = var.application.values_override != null ? var.application.values_override : ""
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
      auto_sync      = var.application.auto_sync
    }
  )
}

resource "kubectl_manifest" "image_updater" {
  count = local.image_updater_enabled ? 1 : 0
  yaml_body = templatefile("${path.module}/crds/image-updater.yml", {
    name           = var.application.name
    argo_namespace = var.argo_namespace
    image          = var.image_updater.image
    strategy       = var.image_updater.strategy
    # placeholder value — this resource has count = 0 when _allow_tags is null,
    # but templatefile() is still evaluated during plan and errors on null
    # (coalesce() rejects "" too, so use a ternary with a non-empty placeholder)
    allow_tags = local._allow_tags != null ? local._allow_tags : "unused"
  })
}