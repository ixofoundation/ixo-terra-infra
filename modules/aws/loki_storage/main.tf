terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Loki chunk storage on S3, read and written by the loki ServiceAccount through IRSA.

resource "aws_s3_bucket" "loki_chunks" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_tag_name
    Environment = var.environment
    Project     = "loki"
  }
}

resource "aws_s3_bucket_public_access_block" "loki_chunks" {
  bucket                  = aws_s3_bucket.loki_chunks.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki_chunks" {
  bucket = aws_s3_bucket.loki_chunks.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Not versioned: Loki's compactor handles retention.
resource "aws_s3_bucket_lifecycle_configuration" "loki_chunks" {
  bucket = aws_s3_bucket.loki_chunks.id

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Backstop expiry in case the compactor does not run.
  rule {
    id     = "expire-chunks-backstop"
    status = "Enabled"
    filter {}
    expiration {
      days = 60
    }
  }
}

data "aws_iam_policy_document" "loki_s3_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "loki_s3" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.loki_chunks.arn]
  }

  # DeleteObject is required: the compactor enforces retention by deleting chunks.
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"]
    resources = ["${aws_s3_bucket.loki_chunks.arn}/*"]
  }
}

resource "aws_iam_role" "loki_s3" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.loki_s3_assume_role.json

  tags = {
    Name        = var.role_name
    Environment = var.environment
    Project     = "loki"
  }
}

resource "aws_iam_role_policy" "loki_s3" {
  name   = "loki-chunks-access"
  role   = aws_iam_role.loki_s3.id
  policy = data.aws_iam_policy_document.loki_s3.json
}
