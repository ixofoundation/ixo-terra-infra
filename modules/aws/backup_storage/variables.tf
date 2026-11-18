variable "bucket_name" {
  description = "S3 bucket for this env's backups (S3 names are global)"
  type        = string
}

variable "environment" {
  description = "Environment tag value"
  type        = string
}

variable "role_name_prefix" {
  description = "Prefix of the per-writer IAM role names"
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

# One IRSA role per writer, limited to its prefix. expiration_days = null leaves deletes to the
# writer (pgBackRest expire); noncurrent_days bounds what versioning keeps after a delete.
variable "writers" {
  description = "Backup writers: key => namespace, ServiceAccounts, bucket prefix and lifecycle"
  type = map(object({
    namespace        = string
    service_accounts = list(string)
    prefix           = string
    expiration_days  = optional(number)
    noncurrent_days  = optional(number, 7)
  }))
}

variable "write_vpce_id" {
  description = "If set, object writes and deletes are denied unless they arrive through this S3 gateway endpoint"
  type        = string
  default     = null
}
