locals {
  kubeconfig_filename = "${path.module}/kubeconfig_${terraform.workspace}.yaml"
}