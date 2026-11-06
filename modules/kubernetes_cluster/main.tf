# AWS EKS cluster module
module "aws_cluster" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  source = "./modules/aws"

  # Pass AWS-specific variables
  cluster_name                  = var.aws.cluster_name
  cluster_version               = var.aws.cluster_version
  region                        = var.aws.region
  environment                   = var.aws.environment
  kubeconfig_name               = var.aws.kubeconfig_name
  project_name                  = var.aws.project_name
  endpoint_public_access        = var.aws.endpoint_public_access
  public_access_cidrs           = var.aws.public_access_cidrs
  cluster_log_types             = var.aws.cluster_log_types
  node_instance_types           = var.aws.node_instance_types
  node_ami_type                 = var.aws.node_ami_type
  node_capacity_type            = var.aws.node_capacity_type
  node_disk_size                = var.aws.node_disk_size
  node_desired_capacity         = var.aws.node_desired_capacity
  node_max_capacity             = var.aws.node_max_capacity
  node_min_capacity             = var.aws.node_min_capacity
  node_key_name                 = var.aws.node_key_name
  node_security_group_ids       = var.aws.node_security_group_ids
  authentication_mode           = var.aws.authentication_mode
  cluster_admin_arns            = var.aws.cluster_admin_arns
  aws_profile                   = var.aws.aws_profile
  aws_cli_path                  = var.aws.aws_cli_path
  service_ipv4_cidr             = var.aws.service_ipv4_cidr
  storage_class_parameters      = var.aws.storage_class_parameters
  node_launch_template_tags     = var.aws.node_launch_template_tags
  node_legacy_groups            = var.aws.node_legacy_groups
  node_root_volume_type         = var.aws.node_root_volume_type
  on_demand_node_count          = var.aws.on_demand_node_count
  on_demand_node_instance_types = var.aws.on_demand_node_instance_types
  db_nodes_per_az               = var.aws.db_nodes_per_az
  db_node_instance_types        = var.aws.db_node_instance_types
  env_config                    = var.aws.env_config
}