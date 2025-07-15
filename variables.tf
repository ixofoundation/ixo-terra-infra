variable "vultr_api_key" {
  description = "Vultr API Key" # Set locally TF_VAR_vultr_api_key
  default     = ""
}

variable "cloudflare_api_token" {
  description = "CloudFlare Api Token" # TF_VAR_cloudflare_api_token
  default     = ""
}

variable "additional_manual_synthetic_monitoring_endpoints" {
  description = "Additional manual synthetic monitoring endpoints for each environment"
  type        = map(list(string))
}

# variables.tf
variable "storage_classes" {
  description = "Storage class mappings for different performance tiers"
  type = map(string)
  
  validation {
    condition = alltrue([
      contains(keys(var.storage_classes), "standard"),
      contains(keys(var.storage_classes), "fast"),
      contains(keys(var.storage_classes), "bulk"),
      contains(keys(var.storage_classes), "shared")
    ])
    error_message = "storage_classes must contain all required keys: standard, fast, bulk, shared"
  }
  
  validation {
    condition = length(setsubtract(keys(var.storage_classes), ["standard", "fast", "bulk", "shared"])) == 0
    error_message = "storage_classes can only contain these keys: standard, fast, bulk, shared"
  }
}

# IXO Infra Defaults
variable "environments" {
  description = "Environment specific configurations"
  type = map(object({
    cluster_firewall = bool
    is_development = optional(bool) # If true, this environment is treated as a development environment.
    aws_region      = string
    aws_iam_users   = list(string)
    rpc_url         = optional(string)
    ipfs_service_mapping = optional(string)
    aws_vpc_config = object({
      nat_gateway_enabled = bool
      flow_logs_enabled = bool
      retention_days = number
      az_count = number
    })
    aws_eks_config = optional(object({
      node_instance_types = list(string)
      desired_capacity = number
      min_capacity = number
      max_capacity = number
      disk_size = number
    }))
    hyperlane = object({
      chain_names     = list(string)
      metadata_chains = list(string)
    })
    application_configs = map(object({
      enabled = bool
      domain  = optional(string)
      dns_endpoint = optional(string)
      dns_prefix = optional(string)
      storage_class = optional(string)
      storage_size = optional(string)
    }))
  }))

  validation { # Validation should be updated when new services are added that require storage
    condition = alltrue([
      for env_name, env_config in var.environments : alltrue([
        for app_name, app_config in env_config.application_configs : 
          contains([
            "ixo-matrix-appservice-rooms",
            "ixo-matrix-state-bot", 
            "ixo-matrix-bids-bot",
            "ixo-matrix-claims-bot",
            "observable-framework-builder"
          ], app_name) && app_config.enabled ? (
            app_config.storage_class != null && app_config.storage_class != "" &&
            app_config.storage_size != null && app_config.storage_size != ""
          ) : true
      ])
    ])
    error_message = <<-EOF
  The following applications require both storage_class and storage_size when enabled:
  - ixo-matrix-appservice-rooms
  - ixo-matrix-state-bot
  - ixo-matrix-bids-bot
  - ixo-matrix-claims-bot
  - observable-framework-builder
  EOF
  }

  validation {
    condition = alltrue([
      for env_name, env_config in var.environments : alltrue([
        for app_name, app_config in env_config.application_configs : 
          contains([
            "ixo-matrix-appservice-rooms",
            "ixo-matrix-state-bot", 
            "ixo-matrix-bids-bot",
            "ixo-matrix-claims-bot",
            "observable-framework-builder"
          ], app_name) && app_config.enabled && app_config.storage_class != null && app_config.storage_class != "" ? 
            contains(["standard", "fast", "bulk", "shared"], app_config.storage_class) : true
      ])
    ])
    error_message = "storage_class values for matrix and observable applications must be one of: standard, fast, bulk, shared"
  }
}

variable "versions" {
  description = "Versions for all services"
  type        = map(string)
}

variable "gcp_project_ids" {
  description = "Project IDs for GCP"
  type        = map(string)
  default = {
    devnet  = "devsecops-415617"
    testnet = "devsecops-415617"
    mainnet = "devsecops-415617"
  }
}

variable "org" {
  type    = string
  default = "ixofoundation"
  validation {
    condition = length(var.org) > 0
    error_message = "Organization name must be provided."
  }
}

variable "cloud_provider" {
  type = string
  description = "Cloud provider to use for the kubernetes cluster and configurations involved"
  default = "vultr"
  validation {
    condition = contains(["vultr", "aws"], var.cloud_provider)
    error_message = "Invalid cloud provider. Must be one of: vultr, aws"
  }
}

variable "oidc_argo" {
  type = map(string)
  default = {
    clientId     = ""
    clientSecret = ""
  }
}

variable "oidc_vault" {
  type = map(string)
  default = {
    clientId     = ""
    clientSecret = ""
  }
}

variable "oidc_tailscale" {
  type        = map(string)
  default     = {
    clientId     = ""
    clientSecret = ""
  }
  description = "OIDC configuration for Tailscale. Required when Tailscale is enabled in any environment."
}

variable "pg_matrix" {
  type = object(
    {
      pg_cluster_name = string
      pg_image        = string
      pg_image_tag    = string
      pg_users = list(
        object(
          {
            username  = string
            databases = list(string)
            options   = optional(string)
          }
        )
      )
      namespace              = string
      pg_version             = number
      pgbackrest_image       = string
      pgbackrest_image_tag   = string
      pgmonitoring_image     = optional(string)
      pgmonitoring_image_tag = optional(string)
    }
  )
}

variable "pg_ixo" {
  type = object(
    {
      pg_cluster_name = string
      pg_image        = string
      pg_image_tag    = string
      pg_users = list(
        object(
          {
            username  = string
            databases = list(string)
            options   = optional(string)
          }
        )
      )
      pg_version             = number
      pgbackrest_image       = string
      pgbackrest_image_tag   = string
      pgmonitoring_image     = optional(string)
      pgmonitoring_image_tag = optional(string)
    }
  )
}

variable "additional_prometheus_scrape_metrics" {
  type        = map(string)
  description = "Additional prometheus scrape metrics config in yml."
  default = {
    devnet  = null
    testnet = null
    mainnet = null
  }
}

variable "region_ids" {
  type = map(string)
  default = {
    ams = "Amsterdam"
    atl = "Atlanta"
    blr = "Bangalore"
    bom = "Mumbai"
    cdg = "Paris"
    del = "Delhi NCR"
    dfw = "Dallas"
    ewr = "New Jersey"
    fra = "Frankfurt"
    hnl = "Honolulu"
    icn = "Seoul"
    itm = "Osaka"
    jnb = "Johannesburg"
    lax = "Los Angeles"
    lhr = "London"
    mad = "Madrid"
    man = "Manchester"
    mel = "Melbourne"
    mex = "Mexico City"
    mia = "Miami"
    nrt = "Tokyo"
    ord = "Chicago"
    sao = "São Paulo"
    scl = "Santiago"
    sea = "Seattle"
    sgp = "Singapore"
    sjc = "Silicon Valley"
    sto = "Stockholm"
    syd = "Sydney"
    tlv = "Tel Aviv"
    waw = "Warsaw"
    yto = "Toronto"
  }
}

variable "domains" {
  description = "Map of domain identifiers to actual domain names"
  type        = map(string)
  
  validation {
    condition = length(var.domains) > 0
    error_message = "At least one domain mapping must be provided."
  }
}

variable "ixo_helm_chart_repository" {
  description = "Git repository URL for IXO Helm charts"
  type        = string
  default     = "https://github.com/ixofoundation/ixo-helm-charts"
}

variable "ixo_terra_infra_repository" {
  description = "Git repository URL for IXO Terraform infrastructure"
  type        = string
  default     = "https://github.com/ixofoundation/ixo-terra-infra"
}

variable "vault_core_mount" {
  description = "Vault mount path for core IXO services"
  type        = string
  default     = "ixo_core"
}
