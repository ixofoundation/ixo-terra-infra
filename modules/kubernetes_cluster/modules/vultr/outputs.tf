output "kubeconfig_path" {
  #depends_on = [local_file.kubeconfig]
  value = local.kubeconfig_filename
}

output "endpoint" {
  value = vultr_kubernetes.k8.endpoint
}

output "cluster_ca_certificate" {
  value = vultr_kubernetes.k8.cluster_ca_certificate
}