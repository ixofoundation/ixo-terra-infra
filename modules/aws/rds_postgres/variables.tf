variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  description = "EKS cluster whose nodes may connect"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnets for the DB subnet group"
  type        = list(string)
}

variable "engine_version" {
  description = "Full PostgreSQL version, e.g. 18.6; the major sets the parameter group family"
  type        = string
}

variable "instance_class" {
  type = string
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "allocated_storage" {
  description = "Initial gp3 storage in GB"
  type        = number
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling in GB"
  type        = number
}

variable "backup_retention_days" {
  description = "Automated backup and PITR window"
  type        = number
  default     = 14
}

variable "force_ssl" {
  description = "rds.force_ssl; false lets non-TLS clients connect"
  type        = bool
  default     = true
}
