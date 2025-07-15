# Vultr cluster module
module "vultr_cluster" {
  count  = var.cloud_provider == "vultr" ? 1 : 0
  source = "./modules/vultr"

  # Pass all Vultr-specific variables
  cluster_region              = var.vultr.cluster_region
  cluster_label               = var.vultr.cluster_label
  k8_version                  = var.vultr.k8_version
  cluster_firewall            = var.vultr.cluster_firewall
  ha_controlplanes            = var.vultr.ha_controlplanes
  initial_node_pool_quantity  = var.vultr.initial_node_pool_quantity
  initial_node_pool_plan      = var.vultr.initial_node_pool_plan
  initial_node_pool_label     = var.vultr.initial_node_pool_label
  initial_node_pool_scaler    = var.vultr.initial_node_pool_scaler
  initial_node_pool_min_nodes = var.vultr.initial_node_pool_min_nodes
  initial_node_pool_max_nodes = var.vultr.initial_node_pool_max_nodes
}

# AWS EKS cluster module
module "aws_cluster" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  source = "./modules/aws"

  # Pass AWS-specific variables
  cluster_name            = var.aws.cluster_name
  cluster_version         = var.aws.cluster_version
  region                  = var.aws.region
  environment             = var.aws.environment
  project_name            = var.aws.project_name
  endpoint_public_access  = var.aws.endpoint_public_access
  public_access_cidrs     = var.aws.public_access_cidrs
  cluster_log_types       = var.aws.cluster_log_types
  node_instance_types     = var.aws.node_instance_types
  node_ami_type           = var.aws.node_ami_type
  node_capacity_type      = var.aws.node_capacity_type
  node_disk_size          = var.aws.node_disk_size
  node_desired_capacity   = var.aws.node_desired_capacity
  node_max_capacity       = var.aws.node_max_capacity
  node_min_capacity       = var.aws.node_min_capacity
  node_key_name           = var.aws.node_key_name
  node_security_group_ids = var.aws.node_security_group_ids
  env_config              = var.aws.env_config
}