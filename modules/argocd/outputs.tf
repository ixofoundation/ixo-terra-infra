output "namespaces_helm" {
  value = kubernetes_namespace_v1.application_helm
}

output "namespaces_git" {
  value = kubernetes_namespace_v1.application
}

output "argo_namespace" {
  value = kubernetes_namespace_v1.app-argocd.metadata[0].name
}