output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = local.kubeconfig_filename
  depends_on  = [local_file.kubeconfig]
}

output "endpoint" {
  description = "Endpoint for the EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_id" {
  description = "The name/id of the EKS cluster"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_version" {
  description = "The Kubernetes version for the cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_security_group_id" {
  description = "The cluster security group ID"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "The node group security group ID"
  value       = aws_security_group.node_group.id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "node_group_iam_role_arn" {
  description = "IAM role ARN of the EKS node group"
  value       = aws_iam_role.node_group.arn
}

output "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC identity provider, for IRSA role trust policies"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_provider_url" {
  description = "Issuer URL of the cluster's IAM OIDC identity provider, without the https:// scheme"
  value       = replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")
}
