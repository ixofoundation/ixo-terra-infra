variable "vultr_api_key" {
  description = "Vultr API Key" # Set locally TF_VAR_vultr_api_key
  default     = ""
}

variable "environments" {
  description = "Environment specific configurations"
  type        = map(any)
  default = {
    devnet = {
      cluster_firewall = true
      // other devnet specific variables...
    }
    testnet = {
      cluster_firewall = true
      // other testnet specific variables...
    }
    main = {
      cluster_firewall = true
      // other main specific variables...
    }
  }
}

variable "pg_matrix" {
  type = object(
    {
      pg_cluster_name      = string
      pg_image             = string
      pg_image_tag         = string
      namespace            = string
      pg_version           = number
      pgbackrest_image     = string
      pgbackrest_image_tag = string
    }
  )
}

variable "pg_ixo" {
  type = object(
    {
      pg_cluster_name      = string
      pg_image             = string
      pg_image_tag         = string
      pg_version           = number
      pgbackrest_image     = string
      pgbackrest_image_tag = string
    }
  )
}