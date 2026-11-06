output "kubeconfig_path" {
  value = var.cloud_provider == "aws" ? module.aws_cluster[0].kubeconfig_path : null
}

output "endpoint" {
  value = var.cloud_provider == "aws" ? module.aws_cluster[0].endpoint : null
}

output "cluster_ca_certificate" {
  value = var.cloud_provider == "aws" ? module.aws_cluster[0].cluster_ca_certificate : null
}

# IRSA plumbing. null off AWS, which has no OIDC provider — callers must guard on
# var.cloud_provider rather than assume a value.
output "oidc_provider_arn" {
  value = var.cloud_provider == "aws" ? module.aws_cluster[0].oidc_provider_arn : null
}

output "oidc_provider_url" {
  value = var.cloud_provider == "aws" ? module.aws_cluster[0].oidc_provider_url : null
}
