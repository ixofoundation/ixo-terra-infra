output "kubeconfig_path" {
  depends_on = [local_file.kubeconfig]
  value = local.kubeconfig_filename
}