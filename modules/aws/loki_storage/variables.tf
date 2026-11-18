variable "bucket_name" {
  description = "S3 bucket for Loki chunks (S3 names are global)"
  type        = string
}

variable "bucket_tag_name" {
  description = "Name tag of the bucket"
  type        = string
}

variable "role_name" {
  description = "IAM role assumed by the loki ServiceAccount"
  type        = string
}

variable "environment" {
  description = "Environment tag value"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN for IRSA"
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC provider URL (no scheme) for IRSA"
  type        = string
}

variable "namespace" {
  description = "Namespace of the loki ServiceAccount"
  type        = string
}

variable "service_account" {
  description = "Name of the loki ServiceAccount (annotated in loki-values-s3.yml)"
  type        = string
  default     = "loki"
}
