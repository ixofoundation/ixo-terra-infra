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

resource "kubernetes_secret_v1" "github" {
  metadata {
    name      = "github-repo"
    namespace = kubernetes_namespace_v1.app-argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" : "repository"
    }
  }
  data = {
    type : "git"
    url : var.argo_chart_repository
    githubAppID : 1
    githubAppInstallationID : 2
  }
}

resource "kubernetes_namespace_v1" "application" {
  for_each = { for app in var.applications : app.name => app }
  metadata {
    name = each.value["namespace"]
  }
}

resource "kubectl_manifest" "application" {
  depends_on = [kubernetes_namespace_v1.application]
  for_each   = { for app in var.applications : app.name => app }
  yaml_body = templatefile("${path.module}/argo-application.yml",
    {
      name           = each.value["name"]
      namespace      = each.value["namespace"]
      argo_namespace = kubernetes_namespace_v1.app-argocd.metadata[0].name
      workspace      = terraform.workspace
      repository     = var.argo_chart_repository
    }
  )
}