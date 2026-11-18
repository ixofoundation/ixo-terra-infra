output "bucket_name" {
  value = aws_s3_bucket.loki_chunks.bucket
}

output "role_arn" {
  value = aws_iam_role.loki_s3.arn
}
