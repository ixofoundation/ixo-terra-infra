output "kubeconfig_path" {
  value = var.cloud_provider == "vultr" ? module.vultr_cluster[0].kubeconfig_path : null
}

output "endpoint" {
  value = var.cloud_provider == "vultr" ? module.vultr_cluster[0].endpoint : null
}

output "cluster_ca_certificate" {
  value = var.cloud_provider == "vultr" ? module.vultr_cluster[0].cluster_ca_certificate : null
}