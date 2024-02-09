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