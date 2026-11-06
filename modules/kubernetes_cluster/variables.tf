variable "cloud_provider" {
  description = "Cloud provider (aws)"
  type        = string
  default     = "aws"
}

variable "aws" {
  description = "AWS-specific configuration"
  type = object({
    cluster_name                  = string
    kubeconfig_name               = optional(string)
    cluster_version               = string
    region                        = string
    environment                   = string
    project_name                  = string
    endpoint_public_access        = optional(bool)
    public_access_cidrs           = optional(list(string))
    cluster_log_types             = optional(list(string))
    node_instance_types           = optional(list(string))
    node_ami_type                 = optional(string)
    node_capacity_type            = optional(string)
    node_disk_size                = optional(number)
    node_desired_capacity         = optional(number)
    node_max_capacity             = optional(number)
    node_min_capacity             = optional(number)
    node_key_name                 = optional(string)
    node_security_group_ids       = optional(list(string))
    authentication_mode           = optional(string)
    cluster_admin_arns            = optional(list(string), [])
    aws_profile                   = optional(string)
    aws_cli_path                  = optional(string, "/usr/local/bin/aws")
    service_ipv4_cidr             = optional(string)
    storage_class_parameters      = optional(map(string), {})
    node_launch_template_tags     = optional(map(string), {})
    node_legacy_groups            = optional(bool, true)
    node_root_volume_type         = optional(string, "gp3")
    on_demand_node_count          = optional(number, 0)
    on_demand_node_instance_types = optional(list(string), ["t3a.xlarge"])
    db_nodes_per_az               = optional(number, 0)
    db_node_instance_types        = optional(list(string), ["t3a.large"])
    env_config = optional(object({
      node_instance_types = list(string)
      desired_capacity    = number
      min_capacity        = number
      max_capacity        = number
      disk_size           = number
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