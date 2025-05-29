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

# IXO Infra Defaults
variable "environments" {
  description = "Environment specific configurations"
  type = map(object({
    cluster_firewall = bool
    aws_region      = string
    aws_iam_users   = list(string)
    rpc_url         = optional(string)
    ipfs_service_mapping = optional(string)
    hyperlane = object({
      chain_names     = list(string)
      metadata_chains = list(string)
    })
    application_configs = map(object({
      enabled = bool
      domain  = optional(string)
      dns_endpoint = optional(string)
      dns_prefix = optional(string)
    }))
  }))
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
  type = map(string)
  default = {
    clientId     = ""
    clientSecret = ""
  }
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
}

variable "ixo_terra_infra_repository" {
  description = "Git repository URL for IXO Terraform infrastructure"
  type        = string
}

variable "vault_core_mount" {
  description = "Vault mount path for core IXO services"
  type        = string
}
