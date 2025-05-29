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

# Future AWS cluster module
# module "aws_cluster" {
#   count  = var.cloud_provider == "aws" ? 1 : 0
#   source = "./aws"
#   
#   # Pass AWS-specific variables
#   cluster_version = var.aws.cluster_version
#   region         = var.aws.region
#   # ... other AWS variables
# }