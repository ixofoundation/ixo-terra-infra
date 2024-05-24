terraform {
  required_providers {
    kubectl = {
      source = "alekc/kubectl"
    }
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
  }
}

resource "kubectl_manifest" "pod_logs" {
  yaml_body = templatefile("${path.module}/crds/pod_logs.yml",
    {
      name            = var.name
      namespace       = kubernetes_namespace_v1.this.metadata[0].name
      matchNamespaces = var.matchNamespaces
    }
  )
}

resource "kubectl_manifest" "logs_instance" {
  yaml_body = templatefile("${path.module}/crds/logs_instance.yml",
    {
      name      = var.name
      namespace = kubernetes_namespace_v1.this.metadata[0].name
    }
  )
}

resource "kubectl_manifest" "agent" {
  yaml_body = templatefile("${path.module}/crds/agent.yml",
    {
      name      = var.name
      namespace = kubernetes_namespace_v1.this.metadata[0].name
    }
  )
}

resource "kubernetes_service_account_v1" "sa" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }
}

resource "kubernetes_cluster_role" "cr" {
  metadata {
    name = var.name
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "nodes/metrics", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    non_resource_urls = ["/metrics", "/metrics/cadvisor"]
    verbs             = ["get"]
  }
}

resource "kubernetes_cluster_role_binding" "crb" {
  metadata {
    name = var.name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cr.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = var.name
    namespace = var.namespace
  }
}