output "namespaces_helm" {
  value = kubernetes_namespace_v1.application_helm
}

output "namespaces_git" {
  value = kubernetes_namespace_v1.application
}