output "endpoint" {
  value = aws_db_instance.main.address
}

output "port" {
  value = aws_db_instance.main.port
}

output "identifier" {
  value = aws_db_instance.main.identifier
}

output "master_user_secret_arn" {
  value = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "security_group_id" {
  value = aws_security_group.rds.id
}
