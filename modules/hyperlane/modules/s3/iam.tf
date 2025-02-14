resource "aws_iam_policy" "s3_access_policy" {
  name        = "${var.validator_name}-s3-policy"
  description = "Allow ECS tasks to access S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.configs_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.configs_bucket.bucket}/*",
          "arn:aws:s3:::${aws_s3_bucket.validator_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.validator_bucket.bucket}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3_policy_attachment" {
  role       = var.ecs_task_role_name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}