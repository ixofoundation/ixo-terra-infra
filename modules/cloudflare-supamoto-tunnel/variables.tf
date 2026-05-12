variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (found in the Cloudflare dashboard URL)"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Account:Cloudflare Tunnel:Edit and Account:Zero Trust:Edit permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for ixo.earth — used to create the CNAME record for the TCP tunnel hostname"
  type        = string
}

variable "environment" {
  description = "Deployment environment (mainnet, testnet, devnet)"
  type        = string
}

variable "domain" {
  description = "Domain to create the supamoto-pg hostname under (e.g. ixo.earth)"
  type        = string
  default     = "ixo.earth"
}

variable "namespace" {
  description = "Kubernetes namespace to deploy the cloudflared access proxy into"
  type        = string
  default     = "supamoto-tunnel"
}
