output "ixo_aws_iam_login_urls" {
  value = var.environments[terraform.workspace].application_configs["ixo_aws_iam"].enabled ? module.ixo_aws_iam[0].login_urls : null
}

output "ixo_aws_iam_login_passwords" {
  value = var.environments[terraform.workspace].application_configs["ixo_aws_iam"].enabled ? module.ixo_aws_iam[0].login_temp_passwords : null
  sensitive = true
}

output "ixo_postgres_user_passwords" {
  value = module.postgres-operator[0].database_password
  sensitive = true
}