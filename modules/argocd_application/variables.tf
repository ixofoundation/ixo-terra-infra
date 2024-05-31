variable "application" {
  type = object(
    {
      name       = string
      namespace  = string
      owner      = string
      repository = string
      helm = optional(object({
        isOci    = bool
        chart    = string
        revision = string
      }))
      path            = optional(string)
      values_override = optional(string)
    }
  )
}

variable "create_kv" {
  type    = bool
  default = false
}

variable "argo_namespace" {
  type = string
}

variable "vault_mount_path" {
  type = string
}