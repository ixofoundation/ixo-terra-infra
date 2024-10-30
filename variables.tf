variable "vultr_api_key" {
  description = "Vultr API Key" # Set locally TF_VAR_vultr_api_key
  default     = ""
}

variable "cloudflare_api_token" {
  description = "CloudFlare Api Token" # TF_VAR_cloudflare_api_token
  default     = ""
}

variable "additional_manual_synthetic_monitoring_endpoints" {
  type = map(list(string))
  default = {
    devnet = [
      "https://devnet-blocksync.ixo.earth",
      "https://signx.devnet.ixo.earth",
      "https://devnet.ixo.earth/rpc/"
    ]
    testnet = [
      "https://payments.testnet.emerging.eco",
      "https://blockscan-pandora.ixo.earth",
      "https://signx.testnet.ixo.earth",
      "https://testnet.ixo.earth/rpc/"
    ]
    mainnet = [
      "https://coincache.ixo.earth",
      "https://relayer.assistant.ixo.earth",
      "https://blocksync.ixo.earth",
      "https://reclaim.ixo.earth",
      "https://signx.ixo.earth",
      "https://ixo.rpc.m.stavr.tech",
      "https://impacthub.ixo.world/rpc/"
    ]
  }
}

variable "environments" {
  description = "Environment specific configurations"
  type        = map(any)
  default = {
    devnet = {
      cluster_firewall     = true
      rpc_url              = "https://devnet.ixo.earth/rpc/"
      ipfs_service_mapping = "https://devnet-blocksync-graphql.ixo.earth/api/ipfs/" #TODO this possibly could be moved to local cluster address
      domain               = "ixo.earth"
      domain2              = "ixo.earth"
      enabled_services = {
        ixo_cellnode                         = true
        ixo_blocksync                        = true
        ixo_blocksync_core                   = true
        ixo_feegrant_nest                    = true
        ixo_did_resolver                     = true
        ixo_faucet                           = true
        ixo_matrix_state_bot                 = true
        ixo_matrix_appservice_rooms          = true
        claims_credentials_ecs               = true
        claims_credentials_prospect          = true
        claims_credentials_carbon            = true
        claims_credentials_umuzi             = true
        claims_credentials_claimformprotocol = false
        claims_credentials_did               = false
        ixo_deeplink_server                  = false
        ixo_kyc_server                       = false
        ixo_faq_assistant                    = false
        ixo_coin_server                      = false
        ixo_stake_reward_claimer             = false
        ixo_ussd                             = false
        ixo_whizz                            = false
        auto_approve_offset                  = false
        ixo_iot_data                         = false
        ixo_notification_server              = false
        ixo_guru                             = false
        ixo_trading_bot_server               = false
      }
    }
    testnet = {
      cluster_firewall     = true
      rpc_url              = "https://testnet.ixo.earth/rpc/"
      domain               = "ixo.earth"
      domain2              = "ixo.earth"
      ipfs_service_mapping = "https://testnet-blocksync-graphql.ixo.earth/api/ipfs/"
      enabled_services = {
        ixo_cellnode                         = true
        ixo_blocksync                        = true
        ixo_blocksync_core                   = true
        ixo_feegrant_nest                    = true
        ixo_did_resolver                     = true
        ixo_faucet                           = true
        ixo_matrix_state_bot                 = true
        ixo_matrix_appservice_rooms          = true
        claims_credentials_ecs               = true
        claims_credentials_prospect          = true
        claims_credentials_carbon            = true
        claims_credentials_umuzi             = false
        claims_credentials_claimformprotocol = false
        claims_credentials_did               = true
        ixo_deeplink_server                  = false
        ixo_kyc_server                       = true
        ixo_faq_assistant                    = false
        ixo_coin_server                      = false
        ixo_stake_reward_claimer             = false
        ixo_ussd                             = false
        ixo_whizz                            = false
        auto_approve_offset                  = true
        ixo_iot_data                         = false
        ixo_notification_server              = false
        ixo_guru                             = false
        ixo_trading_bot_server               = false
      }
    }
    mainnet = {
      cluster_firewall     = true
      rpc_url              = "https://impacthub.ixo.world/rpc/"
      domain               = "ixo.world"
      domain2              = "ixo.earth"
      ipfs_service_mapping = "https://blocksync-graphql.ixo.earth/api/ipfs/"
      enabled_services = {
        ixo_cellnode                         = true
        ixo_blocksync                        = true
        ixo_blocksync_core                   = true
        ixo_feegrant_nest                    = true
        ixo_did_resolver                     = true
        ixo_faucet                           = false
        ixo_matrix_state_bot                 = true
        ixo_matrix_appservice_rooms          = true
        claims_credentials_ecs               = true
        claims_credentials_prospect          = false
        claims_credentials_carbon            = true
        claims_credentials_umuzi             = false
        claims_credentials_claimformprotocol = true
        claims_credentials_did               = true
        ixo_deeplink_server                  = true
        ixo_kyc_server                       = true
        ixo_faq_assistant                    = true
        ixo_coin_server                      = true
        ixo_stake_reward_claimer             = true
        ixo_ussd                             = false
        ixo_whizz                            = true
        auto_approve_offset                  = true
        ixo_iot_data                         = true
        ixo_notification_server              = true
        ixo_guru                             = true
        ixo_trading_bot_server               = true
      }
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
    devnet  = "devsecops-415617"
    testnet = "devsecops-415617"
    mainnet = "devsecops-415617"
  }
}

variable "hostnames" {
  description = "Environment specific hostnames configurations"
  type        = map(string)
  default = {
    devnet         = "devnetkb.ixo.earth"
    devnet_vault   = "vault.devnet.ixo.earth"
    devnet_dex     = "dex.devnet.ixo.earth"
    devnet_matrix  = "devmx.ixo.earth"
    testnet        = "testnetkb.ixo.earth"
    testnet_world  = "testnetkb.ixo.world"
    testnet_vault  = "vault.testnet.ixo.earth"
    testnet_dex    = "dex.testnet.ixo.earth"
    testnet_matrix = "testmx.ixo.earth"
    mainnet        = "mainnetkb.ixo.earth"
    mainnet_vault  = "vault.mainnet.ixo.earth"
    mainnet_dex    = "dex.mainnet.ixo.earth"
    mainnet_matrix = "mx.ixo.earth"
    mainnet_world  = "mainnet.ixo.world"
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