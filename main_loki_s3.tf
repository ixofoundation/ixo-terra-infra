# Loki chunk storage on S3 (AWS only).

locals {
  loki_s3_enabled = var.environments[terraform.workspace].application_configs["loki"].enabled && var.cloud_provider == "aws"
}

resource "aws_s3_bucket" "loki_chunks" {
  count  = local.loki_s3_enabled ? 1 : 0
  bucket = coalesce(local.env.loki_bucket_name, "${var.org}-${local.cloud_resource_name}-loki-chunks")

  tags = {
    Name        = "${var.org}-${local.cloud_resource_name}-loki-chunks"
    Environment = local.global_resource_name
    Project     = "loki"
  }
}

resource "aws_s3_bucket_public_access_block" "loki_chunks" {
  count                   = local.loki_s3_enabled ? 1 : 0
  bucket                  = aws_s3_bucket.loki_chunks[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki_chunks" {
  count  = local.loki_s3_enabled ? 1 : 0
  bucket = aws_s3_bucket.loki_chunks[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Not versioned: Loki's compactor handles retention.
resource "aws_s3_bucket_lifecycle_configuration" "loki_chunks" {
  count  = local.loki_s3_enabled ? 1 : 0
  bucket = aws_s3_bucket.loki_chunks[0].id

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

# IRSA role for the loki ServiceAccount (annotated in loki-values-s3.yml).
data "aws_iam_policy_document" "loki_s3_assume_role" {
  count = local.loki_s3_enabled ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.kubernetes_cluster.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.kubernetes_cluster.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${kubernetes_namespace_v1.loki.metadata[0].name}:loki"]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.kubernetes_cluster.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "loki_s3" {
  count = local.loki_s3_enabled ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.loki_chunks[0].arn]
  }

  # DeleteObject is required: the compactor enforces retention by deleting chunks.
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"]
    resources = ["${aws_s3_bucket.loki_chunks[0].arn}/*"]
  }
}

resource "aws_iam_role" "loki_s3" {
  count              = local.loki_s3_enabled ? 1 : 0
  name               = "ixo-${local.cloud_resource_name}-loki-s3"
  assume_role_policy = data.aws_iam_policy_document.loki_s3_assume_role[0].json

  tags = {
    Name        = "ixo-${local.cloud_resource_name}-loki-s3"
    Environment = local.global_resource_name
    Project     = "loki"
  }
}

resource "aws_iam_role_policy" "loki_s3" {
  count  = local.loki_s3_enabled ? 1 : 0
  name   = "loki-chunks-access"
  role   = aws_iam_role.loki_s3[0].id
  policy = data.aws_iam_policy_document.loki_s3[0].json
}
