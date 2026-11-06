variable "namespace" {
  description = "Kubernetes namespace to deploy the cloudflared access proxy into (must match the bots' configured DB host)"
  type        = string
}

variable "partner_name" {
  description = "Short identifier for the partner (e.g. supamoto) — the service is <partner_name>-postgres"
  type        = string
}

variable "hostname" {
  description = "Cloudflare Access TCP hostname of the partner tunnel (e.g. supamoto-pg.ixo.earth)"
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
