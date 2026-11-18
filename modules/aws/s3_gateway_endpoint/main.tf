terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# S3 gateway endpoint on the private route tables: same-region S3 traffic skips the NAT.
# The policy allows this account's buckets plus the AWS/upstream buckets nodes pull from;
# any other same-region bucket is denied through the endpoint.

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "s3_endpoint" {
  statement {
    sid       = "OwnAccountBuckets"
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # ECR image layers, Amazon Linux package repos, registry.k8s.io's regional blob mirror.
  statement {
    sid     = "UpstreamReadOnly"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = concat([
      "arn:aws:s3:::prod-${data.aws_region.current.name}-starport-layer-bucket/*",
      "arn:aws:s3:::al2023-repos-${data.aws_region.current.name}-de612dc2/*",
      "arn:aws:s3:::amazonlinux-2-repos-${data.aws_region.current.name}/*",
      "arn:aws:s3:::prod-registry-k8s-io-${data.aws_region.current.name}/*",
    ], [for b in var.extra_buckets : "arn:aws:s3:::${b}/*"])
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }

  dynamic "statement" {
    for_each = length(var.extra_buckets) > 0 ? [1] : []
    content {
      sid       = "ExtraBucketsList"
      effect    = "Allow"
      actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
      resources = [for b in var.extra_buckets : "arn:aws:s3:::${b}"]
      principals {
        type        = "*"
        identifiers = ["*"]
      }
    }
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids
  policy            = data.aws_iam_policy_document.s3_endpoint.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-s3-gateway"
    Environment = var.environment
    Project     = var.project_name
  }
}
