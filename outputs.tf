output "ixo_aws_iam_login_urls" {
  value = var.environments[terraform.workspace].application_configs["ixo_aws_iam"].enabled ? module.ixo_aws_iam[0].login_urls : null
}

output "ixo_aws_iam_login_passwords" {
  value     = var.environments[terraform.workspace].application_configs["ixo_aws_iam"].enabled ? module.ixo_aws_iam[0].login_temp_passwords : null
  sensitive = true
}

output "ixo_postgres_user_passwords" {
  value     = module.postgres-operator[0].database_password
  sensitive = true
}

output "supamoto_tunnel_token" {
  value     = module.cloudflare_supamoto_tunnel[0].tunnel_token
  sensitive = true
}

output "digihub_tunnel_token" {
  value     = module.cloudflare_digihub_tunnel[0].tunnel_token
  sensitive = true
}

# Hyperdrive config inputs for Cloudflare Workers → ixo-postgres (see cloudflare_workers_db_tunnel)
output "workers_db_tunnel_hostname" {
  value = module.cloudflare_workers_db_tunnel.postgres_hostname
}

output "workers_db_tunnel_access_client_id" {
  value = module.cloudflare_workers_db_tunnel.access_client_id
}

output "workers_db_tunnel_access_client_secret" {
  value     = module.cloudflare_workers_db_tunnel.access_client_secret
  sensitive = true
}
