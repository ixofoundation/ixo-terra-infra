output "tunnel_token" {
  description = "Cloudflared tunnel token for the partner's server — share this with the partner to run cloudflared"
  value       = cloudflare_tunnel.supamoto.tunnel_token
  sensitive   = true
}

output "tunnel_id" {
  description = "Cloudflare tunnel ID"
  value       = cloudflare_tunnel.supamoto.id
}

output "postgres_service_host" {
  description = "K8s DNS hostname for bots to use as their Postgres host"
  value       = "${var.partner_name}-postgres.${var.namespace}.svc.cluster.local"
}
