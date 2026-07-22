output "tunnel_id" {
  description = "Cloudflare tunnel ID"
  value       = cloudflare_tunnel.workers_db.id
}

output "postgres_hostname" {
  description = "Public hostname to use as the Hyperdrive origin host"
  value       = "${var.pg_cname}.${var.domain}"
}

output "access_client_id" {
  description = "Access service token client ID — paste into the Hyperdrive config's Client ID field"
  value       = cloudflare_access_service_token.hyperdrive.client_id
}

output "access_client_secret" {
  description = "Access service token client secret — paste into the Hyperdrive config's Client Secret field"
  value       = cloudflare_access_service_token.hyperdrive.client_secret
  sensitive   = true
}
