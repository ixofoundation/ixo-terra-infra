variable "cloud_provider" {
  description = "Cloud provider (vultr, aws, etc.)"
  type        = string
  default     = "vultr"
}

variable "vultr" {
  description = "Vultr-specific configuration"
  type = object({
    k8_version                  = string
    cluster_region              = string
    cluster_label               = string
    cluster_firewall            = bool
    ha_controlplanes            = bool
    initial_node_pool_plan      = string
    initial_node_pool_quantity  = number
    initial_node_pool_label     = string
    initial_node_pool_scaler    = bool
    initial_node_pool_min_nodes = number
    initial_node_pool_max_nodes = number
  })
  default = {
    k8_version                  = "v1.29.1+1"
    cluster_region              = "jnb"
    cluster_label               = "vke-test"
    cluster_firewall            = false
    ha_controlplanes            = false
    initial_node_pool_plan      = "vc2-1c-2gb"
    initial_node_pool_quantity  = 2
    initial_node_pool_label     = "vke-nodepool"
    initial_node_pool_scaler    = true
    initial_node_pool_min_nodes = 2
    initial_node_pool_max_nodes = 4
  }
}

# Future AWS variables will go here:
# variable "aws" {
#   description = "AWS-specific configuration"
#   type = object({
#     cluster_version = string
#     region         = string
#     # ... AWS-specific fields
#   })
#   default = { ... }
# }