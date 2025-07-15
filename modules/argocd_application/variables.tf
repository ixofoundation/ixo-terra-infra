variable "application" {
  type = object(
    {
      name       = string
      namespace  = string
      repository = string
      helm = optional(object({
        isOci             = bool
        chart             = string
        revision          = string
        ignoreDifferences = optional(string)
      }))
      path            = optional(string)
      values_override = optional(string)
    }
  )
}

variable "oci_repository_credentials" {
  type = object({
    username = optional(string)
    password = optional(string)
  })
  default = {
    username = null
    password = null
  }
  description = "Optional: Credentials for OCI repository access. Required when using private OCI registries."
  sensitive = true
}

variable "kv_defaults" {
  default     = {}
  description = "Optional: This is the default vault keys on initial creation of the Secret."
}

#
variable "create_kv" {
  type        = bool
  default     = false
  description = "Optional: If true, will create a Secret on Vault for this app, uses kv_defaults for default values on creation."
}

variable "argo_namespace" {
  type = string
}

variable "vault_mount_path" {
  type = string
}