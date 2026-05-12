output "supamoto_tunnel_token" {
  description = "Cloudflared tunnel token for Supamoto's server (already running — informational only)"
  value       = cloudflare_tunnel.supamoto.tunnel_token
  sensitive   = true
}

output "supamoto_tunnel_id" {
  description = "Cloudflare tunnel ID for the Supamoto-side connector"
  value       = cloudflare_tunnel.supamoto.id
}

output "postgres_service_host" {
  description = "K8s DNS hostname for bots to use as their Postgres host"
  value       = "supamoto-postgres.${var.namespace}.svc.cluster.local"
}
