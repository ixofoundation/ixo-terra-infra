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
  description = "Cloudflare Zone ID for the domain — used to create the CNAME record for the TCP tunnel hostname"
  type        = string
}

variable "environment" {
  description = "Deployment environment (mainnet, testnet, devnet)"
  type        = string
}

variable "domain" {
  description = "Domain to create the pg_cname hostname under (e.g. ixo.earth)"
  type        = string
  default     = "ixo.earth"
}

variable "namespace" {
  description = "Kubernetes namespace to deploy the cloudflared access proxy into"
  type        = string
}

variable "partner_name" {
  description = "Short identifier for the partner (e.g. supamoto, digihub) — used in cloud resource names and K8s service names"
  type        = string
}

variable "pg_cname" {
  description = "Subdomain prefix for the Cloudflare tunnel TCP endpoint (e.g. supamoto-pg, digihub-pg)"
  type        = string
}

variable "docker_postgres_service" {
  description = "Docker Swarm DNS service name for the partner's Postgres (resolved inside their cloudflared container)"
  type        = string
  default     = "matrix_postgres"
}
