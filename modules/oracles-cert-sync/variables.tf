variable "cloudflare_api_token" {
  description = "CloudFlare API token with Zone:DNS:Edit and Zone:SSL and Certificates:Edit permissions for oracles.work"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "CloudFlare Zone ID for oracles.work"
  type        = string
}

variable "acme_email" {
  description = "Email address for Let's Encrypt ACME registration"
  type        = string
  default     = "admin@ixo.world"
}
