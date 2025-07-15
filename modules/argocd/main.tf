terraform {
  required_providers {
    kubectl = {
      source = "alekc/kubectl"
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
    templatefile("${path.module}/argo-values.yml", {
      host                 = var.hostnames[terraform.workspace]
      environment          = terraform.workspace
      AVP_VERSION          = "1.16.1"
      HELM_VERSION         = "3.14.2"
      github_client_id     = var.github_client_id
      github_client_secret = var.github_client_secret
      org                  = var.org
      cert_manager_enabled = var.cert_manager_enabled
    })
  ]
  namespace  = kubernetes_namespace_v1.app-argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
}

resource "time_sleep" "wait_for_argocd" {
  depends_on = [module.argocd_release]
  create_duration = "10s"
}

resource "kubernetes_secret_v1" "repo_server" {
  depends_on = [time_sleep.wait_for_argocd]
  metadata {
    annotations = {
      "kubernetes.io/service-account.name" = "argocd-repo-server"
    }
    namespace = kubernetes_namespace_v1.app-argocd.metadata[0].name

    generate_name = "argocd-repo-server-"
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

resource "kubernetes_namespace_v1" "app-argocd" {
  metadata {
    name = "app-argocd"
  }
}

resource "kubernetes_secret_v1" "repository" {
  depends_on = [time_sleep.wait_for_argocd]
  for_each   = { for repo in var.git_repositories : repo.name => repo }
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

# Create Argo Helm Applications
resource "kubectl_manifest" "application_helm" {
  depends_on = [kubernetes_namespace_v1.application_helm, time_sleep.wait_for_argocd]
  for_each   = { for app in var.applications_helm : app.name => app }
  yaml_body = templatefile(each.value.isHelm == false ? "${path.module}/crds/argo-application.yml" : "${path.module}/crds/argo-application-helm.yml",
    {
      name              = each.value.name
      namespace         = each.value.namespace
      repository        = each.value.repository
      revision          = each.value.revision
      chart             = each.value.chart
      helm_values       = each.value.values_override != null ? each.value.values_override : ""
      argo_namespace    = kubernetes_namespace_v1.app-argocd.metadata[0].name
      isOci             = each.value.oci != null ? each.value.oci : false
      ignoreDifferences = each.value.ignoreDifferences != null ? each.value.ignoreDifferences : "[]"
      path              = each.value.path != null ? each.value.path : ""
    }
  )
}