# This resource creates an S3 bucket used to store validator signatures.
# The `force_destroy` attribute is set to true to allow the bucket to be destroyed even if it contains objects.
resource "aws_s3_bucket" "configs_bucket" {
  bucket = "${var.validator_name}-configs"
  force_destroy = true  # Enables deletion of non-empty bucket during destroy operation
}

# This resource applies a public access block configuration to the validator signatures bucket.
# It prevents public ACLs from being applied to the bucket and ignores any public ACLs already on the bucket.
resource "aws_s3_bucket_public_access_block" "configs_bucket_public_access_block" {
  bucket = aws_s3_bucket.configs_bucket.id

  block_public_acls       = true  # Blocks public ACLs from being added to the bucket
  ignore_public_acls      = true  # Ignores any public ACLs currently associated with the bucket
  block_public_policy     = true  # Allows public bucket policies (not recommended for sensitive data)
  restrict_public_buckets = true  # Allows unrestricted public access to the bucket (not recommended for sensitive data)
}

# This resource defines a bucket policy that allows public read access to the bucket and its objects.
# It also grants additional permissions to a specific IAM role to delete and put objects in the bucket.
resource "aws_s3_bucket_policy" "configs_bucket_policy" {
  bucket = aws_s3_bucket.configs_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          "AWS" = var.ecs_task_role_arn
        },
        Action = [
          "s3:GetObject",  # Allows retrieval of objects from the bucket
          "s3:ListBucket"  # Allows listing of the objects within the bucket
        ],
        Resource = [
          "${aws_s3_bucket.configs_bucket.arn}",  # Bucket ARN
          "${aws_s3_bucket.configs_bucket.arn}/*"  # All objects within the bucket
        ]
      },
      {
        Effect = "Allow",
        Principal = {
          AWS = var.ecs_task_role_arn  # IAM user ARN of validator
        },
        Action = [
          "s3:PutObject",  # Allows uploading of new objects to the bucket
          "s3:GetObject",  # Allows retrieval of objects from the bucket
          "s3:ListBucket",  # Allows listing of the objects within the bucket
          "s3:DeleteObject",  # Allows deletion of objects within the bucket
        ],
        Resource = [
          "${aws_s3_bucket.configs_bucket.arn}",  # Bucket ARN
          "${aws_s3_bucket.configs_bucket.arn}/*"  # All objects within the bucket
        ]
      }
    ]
  })
}

# This resource enables versioning for the S3 bucket to keep multiple versions of an object in the same bucket.
# Versioning is useful for data retention and recovery, as it allows you to recover from unintended user actions and application failures.
resource "aws_s3_bucket_versioning" "configs_bucket_versioning" {
  bucket = aws_s3_bucket.configs_bucket.id
  versioning_configuration {
    status = "Enabled"  # Enables versioning for the specified bucket
  }
}