terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}

module "argocd_release" {
  source  = "terraform-module/release/helm"
  version = "2.8.1"
  app = {
    name         = "argocd"
    chart        = "argo-cd"
    version      = var.argo_version
    force_update = true
    deploy       = 1
  }
  values = [
    templatefile("${path.module}/argo-values.yml", {})
  ]
  namespace  = kubernetes_namespace_v1.app-argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
}

resource "kubernetes_namespace_v1" "app-argocd" {
  metadata {
    name = "app-argocd"
  }
}

resource "kubernetes_secret_v1" "repository" {
  for_each = { for repo in var.git_repositories : repo.name => repo }
  metadata {
    name      = each.value["name"]
    namespace = kubernetes_namespace_v1.app-argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" : "repository"
    }
  }
  data = {
    type : "git"
    url : each.value["repository"]
    githubAppID : 1
    githubAppInstallationID : 2
  }
}

# Git Applications Create Namespaces
resource "kubernetes_namespace_v1" "application" {
  for_each = { for app in var.applications : app.name => app }
  metadata {
    name = each.value.namespace
  }
}

# Helm Applications Create Namespaces
resource "kubernetes_namespace_v1" "application_helm" {
  for_each = { for app in var.applications_helm : app.name => app }
  metadata {
    name = each.value.namespace
  }
}

# Create Argo Git Applications
resource "kubectl_manifest" "application" {
  depends_on = [kubernetes_namespace_v1.application, module.argocd_release]
  for_each   = { for app in var.applications : app.name => app }
  yaml_body = templatefile("${path.module}/crds/argo-application.yml",
    {
      name           = each.value.name
      namespace      = each.value.namespace
      owner          = each.value.owner
      argo_namespace = kubernetes_namespace_v1.app-argocd.metadata[0].name
      workspace      = terraform.workspace
      repository     = each.value.repository
      helm_values    = each.value.values_override != null ? each.value.values_override : ""
      path           = each.value.path != null ? each.value.path : "charts/${terraform.workspace}/${each.value.owner}/${each.value.namespace}"
    }
  )
}

# Create Argo Helm Applications
resource "kubectl_manifest" "application_helm" {
  depends_on = [kubernetes_namespace_v1.application, module.argocd_release]
  for_each   = { for app in var.applications_helm : app.name => app }
  yaml_body = templatefile("${path.module}/crds/argo-application-helm.yml",
    {
      name           = each.value.name
      namespace      = each.value.namespace
      repository     = each.value.repository
      revision       = each.value.revision
      chart          = each.value.chart
      helm_values    = each.value.values_override != null ? each.value.values_override : ""
      argo_namespace = kubernetes_namespace_v1.app-argocd.metadata[0].name
      isOci          = each.value.oci != null ? each.value.oci : false
    }
  )
}