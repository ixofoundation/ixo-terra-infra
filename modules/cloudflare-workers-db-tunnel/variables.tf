variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (found in the Cloudflare dashboard URL)"
  type        = string
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
  description = "Kubernetes namespace to deploy the cloudflared tunnel into"
  type        = string
}

variable "name" {
  description = "Short identifier for the consumer (e.g. workers) — used in cloud resource names"
  type        = string
  default     = "workers"
}

variable "pg_cname" {
  description = "Subdomain prefix for the Cloudflare tunnel TCP endpoint (e.g. workers-pg)"
  type        = string
}

variable "postgres_service_host" {
  description = "In-cluster DNS host of the Postgres endpoint to expose (e.g. ixo-postgres-pgbouncer.ixo-postgres.svc.cluster.local)"
  type        = string
}

variable "postgres_port" {
  description = "Postgres port on the in-cluster service"
  type        = number
  default     = 5432
}
