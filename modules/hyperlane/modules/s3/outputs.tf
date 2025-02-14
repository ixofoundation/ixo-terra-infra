output "validator_bucket_id" {
  value = aws_s3_bucket.validator_bucket.id
}

output "validator_bucket_arn" {
  value = aws_s3_bucket.validator_bucket.arn
}

output "configs_bucket_id" {
  value = aws_s3_bucket.configs_bucket.id
}

output "configs_bucket_arn" {
  value = aws_s3_bucket.configs_bucket.arn
}