output "ecs_user_arn" {
  value = aws_iam_user.ecs_user.arn
}

output "ecs_user_name" {
  value = aws_iam_user.ecs_user.name
}

output "ecs_user_access_key_id_arn" {
  value = aws_ssm_parameter.key_id.arn
}

output "ecs_user_secret_access_key_arn" {
  value = aws_ssm_parameter.key_secret.arn
}

output "validator_execution_role_arn" {
  value = aws_iam_role.ecs_execution_role.arn
}

output "validator_execution_role_name" {
  value = aws_iam_role.ecs_execution_role.name
}

output "validator_task_role_arn" {
  value = aws_iam_role.ecs_task_role.arn
}

output "aws_access_key_id" {
  value = aws_iam_access_key.ecs_user_key.id
}

# output "aws_secret_access_key" {
#   value = aws_iam_access_key.ecs_user_key.secret
# }