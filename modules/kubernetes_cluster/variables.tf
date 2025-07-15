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

variable "aws" {
  description = "AWS-specific configuration"
  type = object({
    cluster_name            = string
    cluster_version         = string
    region                  = string
    environment             = string
    project_name            = string
    endpoint_public_access  = optional(bool)
    public_access_cidrs     = optional(list(string))
    cluster_log_types       = optional(list(string))
    node_instance_types     = optional(list(string))
    node_ami_type           = optional(string)
    node_capacity_type      = optional(string)
    node_disk_size          = optional(number)
    node_desired_capacity   = optional(number)
    node_max_capacity       = optional(number)
    node_min_capacity       = optional(number)
    node_key_name           = optional(string)
    node_security_group_ids = optional(list(string))
    env_config = optional(object({
      node_instance_types = list(string)
      desired_capacity = number
      min_capacity = number
      max_capacity = number
      disk_size = number
    }))
  })
  default = {
    cluster_name            = "ixo-cluster"
    cluster_version         = "1.33"
    region                  = "us-west-2"
    environment             = "devnet"
    project_name            = "ixo"
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
    cluster_log_types       = ["api", "audit"]
    node_instance_types     = ["t3.medium"]
    node_ami_type           = "AL2023_x86_64_STANDARD"
    node_capacity_type      = "ON_DEMAND"
    node_disk_size          = 20
    node_desired_capacity   = 2
    node_max_capacity       = 4
    node_min_capacity       = 1
    node_key_name           = null
    node_security_group_ids = null
    env_config = {
      node_instance_types = ["t3.medium"]
      desired_capacity    = 2
      min_capacity        = 1
      max_capacity        = 4
      disk_size           = 20
    }
  }
}