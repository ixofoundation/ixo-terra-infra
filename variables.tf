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

variable "versions" {
  description = "Versions for all services"
  type        = map(string)
}

variable "gcp_project_ids" {
  description = "Project IDs for GCP"
  type        = map(string)
  default = {
    devnet = "devsecops-415617"
    test   = ""
    main   = ""
  }
}

variable "hostnames" {
  description = "Environment specific hostnames configurations"
  type        = map(string)
  default = {
    devnet        = "devnetkb.ixo.earth"
    devnet_vault  = "vault.devnet.ixo.earth"
    devnet_dex    = "dex.devnet.ixo.earth"
    devnet_matrix = "devmx.ixo.earth"
    test          = "testkb.ixo.earth"
    main          = "mainkb.ixo.earth"
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
      pg_cluster_name = string
      pg_image        = string
      pg_image_tag    = string
      pg_users = list(
        object(
          {
            username  = string
            databases = list(string)
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