output "bucket_name" {
  value = aws_s3_bucket.backups.bucket
}

output "role_arns" {
  value = { for k, r in aws_iam_role.writer : k => r.arn }
}
