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

variable "warp_routing_enabled" {
  description = "Enable WARP routing on the tunnel (private-network routes reachable from WARP clients)."
  type        = bool
  default     = false
}

variable "namespace" {
  description = "Kubernetes namespace to deploy the cloudflared access proxy into (must match the bots' configured DB host)"
  type        = string
}

variable "cloudflared_version" {
  description = "cloudflare/cloudflared image tag (pinned: a fresh cluster otherwise pulls whatever latest is)"
  type        = string
  default     = "2026.10.7"
}

variable "tailscale_hostname" {
  description = "Tailnet device name for direct developer access to the partner's Postgres; null skips the Tailscale Service (needs the tailscale operator)"
  type        = string
  default     = null
}
