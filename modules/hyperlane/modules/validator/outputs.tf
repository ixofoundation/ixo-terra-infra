output "validator_info" {
  value = {
    aws_access_key_id     = module.iam_kms.aws_access_key_id,
    //aws_secret_access_key = module.iam_kms.aws_secret_access_key,
    aws_s3_bucket_id      = module.s3.validator_bucket_id,
    aws_region            = var.aws_region,
  }
}