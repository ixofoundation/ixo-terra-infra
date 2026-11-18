terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

locals {
  identifier = "${var.project_name}-${var.environment}-postgres"
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Nodes carry the EKS-managed cluster SG (the launch template sets none), so pods reach RDS through it.
data "aws_eks_cluster" "main" {
  name = var.cluster_name
}

# Destroying the key makes every snapshot unrecoverable, hence prevent_destroy.
resource "aws_kms_key" "rds" {
  description             = "${local.identifier} storage, snapshots, master secret and Performance Insights"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = merge(local.tags, { Name = "${local.identifier}-kms" })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${local.identifier}"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_db_subnet_group" "main" {
  name       = local.identifier
  subnet_ids = var.subnet_ids
  tags       = merge(local.tags, { Name = local.identifier })
}

resource "aws_security_group" "rds" {
  name        = "${local.identifier}-sg"
  description = "Postgres from the EKS nodes only"
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = "${local.identifier}-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "eks_nodes" {
  security_group_id            = aws_security_group.rds.id
  description                  = "Postgres from EKS nodes and pods"
  referenced_security_group_id = data.aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  tags                         = local.tags
}

resource "aws_db_parameter_group" "main" {
  name   = local.identifier
  family = "postgres${split(".", var.engine_version)[0]}"
  tags   = local.tags

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements,pgaudit,pg_cron"
    apply_method = "pending-reboot"
  }

  # RDS allows one pg_cron database; firecrawl is the only user.
  parameter {
    name         = "cron.database_name"
    value        = "firecrawl"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "rds.force_ssl"
    value = var.force_ssl ? "1" : "0"
  }
}

resource "aws_db_instance" "main" {
  identifier     = local.identifier
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class
  multi_az       = var.multi_az

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  username                      = "ixo_admin"
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.rds.key_id

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.main.name
  publicly_accessible    = false

  backup_retention_period   = var.backup_retention_days
  backup_window             = "01:00-02:00"
  maintenance_window        = "sun:03:00-sun:04:00"
  copy_tags_to_snapshot     = true
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.identifier}-final"

  auto_minor_version_upgrade = false
  apply_immediately          = false

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id       = aws_kms_key.rds.arn

  tags = merge(local.tags, { Name = local.identifier })
}
