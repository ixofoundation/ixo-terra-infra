terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Backup bucket for one env: pgBackRest repos, Vault raft snapshots and Synapse media,
# each writer on its own prefix through IRSA.

resource "aws_s3_bucket" "backups" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
    Project     = "backups"
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  depends_on = [aws_s3_bucket_versioning.backups]
  bucket     = aws_s3_bucket.backups.id

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  dynamic "rule" {
    for_each = var.writers
    content {
      id     = "${rule.key}-retention"
      status = "Enabled"
      filter {
        prefix = "${rule.value.prefix}/"
      }
      # Without a day count, only clean up delete markers left after noncurrent expiry.
      expiration {
        days                         = rule.value.expiration_days
        expired_object_delete_marker = rule.value.expiration_days == null ? true : null
      }
      noncurrent_version_expiration {
        noncurrent_days = rule.value.noncurrent_days
      }
    }
  }
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.backups.arn, "${aws_s3_bucket.backups.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  dynamic "statement" {
    for_each = var.write_vpce_id == null ? [] : [1]
    content {
      sid       = "DenyWritesOutsideVpce"
      effect    = "Deny"
      actions   = ["s3:PutObject", "s3:DeleteObject", "s3:DeleteObjectVersion"]
      resources = ["${aws_s3_bucket.backups.arn}/*"]
      principals {
        type        = "*"
        identifiers = ["*"]
      }
      condition {
        test     = "StringNotEquals"
        variable = "aws:SourceVpce"
        values   = [var.write_vpce_id]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "backups" {
  depends_on = [aws_s3_bucket_public_access_block.backups]
  bucket     = aws_s3_bucket.backups.id
  policy     = data.aws_iam_policy_document.bucket.json
}

data "aws_iam_policy_document" "assume" {
  for_each = var.writers
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
      values   = [for sa in each.value.service_accounts : "system:serviceaccount:${each.value.namespace}:${sa}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "access" {
  for_each = var.writers
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.backups.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = [each.value.prefix, "${each.value.prefix}/*"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:GetBucketLocation"]
    resources = [aws_s3_bucket.backups.arn]
  }

  # DeleteObject is needed by pgBackRest expire.
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"]
    resources = ["${aws_s3_bucket.backups.arn}/${each.value.prefix}/*"]
  }
}

resource "aws_iam_role" "writer" {
  for_each           = var.writers
  name               = "${var.role_name_prefix}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.assume[each.key].json

  tags = {
    Name        = "${var.role_name_prefix}-${each.key}"
    Environment = var.environment
    Project     = "backups"
  }
}

resource "aws_iam_role_policy" "writer" {
  for_each = var.writers
  name     = "backup-prefix-access"
  role     = aws_iam_role.writer[each.key].id
  policy   = data.aws_iam_policy_document.access[each.key].json
}
