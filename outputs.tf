output "ixo_aws_iam_login_urls" {
  value = var.environments[terraform.workspace].enabled_services["ixo_aws_iam"] ? module.ixo_aws_iam[0].login_urls : null
}

output "ixo_aws_iam_login_passwords" {
  value = var.environments[terraform.workspace].enabled_services["ixo_aws_iam"] ? module.ixo_aws_iam[0].login_temp_passwords : null
  sensitive = true
}