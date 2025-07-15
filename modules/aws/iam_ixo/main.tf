terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_iam_group" "developer" {
  name = "developer"
}

resource "aws_iam_policy" "cloudwatch_read" {
  name        = "CloudWatchReadOnly"
  description = "Allows read access to CloudWatch logs"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "logs:DescribeLogGroups",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:DescribeLogStreams"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_group_policy_attachment" "attach_cloudwatch" {
  group      = aws_iam_group.developer.name
  policy_arn = aws_iam_policy.cloudwatch_read.arn
}

resource "aws_iam_policy" "developer_password_reset" {
  name        = "DeveloperPasswordResetPolicy"
  description = "Allows developers to reset their own password"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow"
        Action   = "iam:ChangePassword"
        Resource = "arn:aws:iam::*:user/*"
      }
    ]
  })
}

resource "aws_iam_group_policy_attachment" "attach_password_reset_policy" {
  group      = aws_iam_group.developer.name
  policy_arn = aws_iam_policy.developer_password_reset.arn
}

resource "aws_iam_policy" "s3_youtrack_access" {
  name        = "S3YoutrackArchiveAccess"
  description = "Allows read/write access to jetbrains-youtrack-archive bucket and S3 list access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListAllMyBuckets"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket"
        ],
        Resource = "arn:aws:s3:::jetbrains-youtrack-archive"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Resource = "arn:aws:s3:::jetbrains-youtrack-archive/*"
      }
    ]
  })
}

resource "aws_iam_group_policy_attachment" "attach_s3_youtrack_policy" {
  group      = aws_iam_group.developer.name
  policy_arn = aws_iam_policy.s3_youtrack_access.arn
}

resource "aws_iam_group_membership" "developer_group_members" {
  name  = "developer-group-membership"
  group = aws_iam_group.developer.name
  users = [for user in aws_iam_user.user : user.name]
}

resource "aws_iam_user" "user" {
  for_each = toset(var.users)
  name     = each.key


  tags = {
    Role = "developer"
  }
}

resource "aws_iam_user_login_profile" "user_login" {
  for_each                = toset(var.users)
  user                    = aws_iam_user.user[each.key].name
  password_reset_required = true
}

output "login_urls" {
  value = { for user in aws_iam_user_login_profile.user_login : user.user => "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console" }
}

output "login_temp_passwords" {
  value = { for user in aws_iam_user_login_profile.user_login : user.user => user.password }
}

data "aws_caller_identity" "current" {}