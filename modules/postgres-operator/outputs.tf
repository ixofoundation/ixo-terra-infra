# Output each secret
output "database_password" {
  value = {
    for user_key, secret_data in data.kubernetes_secret_v1.user_secret : regex("pguser-(.*)", secret_data.metadata[0].name)[0] => secret_data.data["password"]
  }
  sensitive = true
}