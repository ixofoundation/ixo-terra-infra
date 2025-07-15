variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Version of the EKS cluster"
  type        = string
  default     = "1.33"
}

variable "region" {
  description = "AWS region for the cluster"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "endpoint_public_access" {
  description = "Enable public access to EKS API server endpoint"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the EKS API server endpoint publicly"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# Node Group Variables
variable "node_instance_types" {
  description = "List of instance types for the EKS node group"
  type        = list(string)
  default     = null
}

variable "node_ami_type" {
  description = "Type of Amazon Machine Image (AMI) associated with the EKS Node Group"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "node_capacity_type" {
  description = "Type of capacity associated with the EKS Node Group (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_disk_size" {
  description = "Disk size in GiB for worker nodes"
  type        = number
  default     = null
}

variable "node_desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
  default     = null
}

variable "node_max_capacity" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = null
}

variable "node_min_capacity" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = null
}

variable "node_key_name" {
  description = "EC2 Key Pair name for SSH access to worker nodes"
  type        = string
  default     = null
}

variable "node_security_group_ids" {
  description = "List of security group IDs to allow SSH access to worker nodes"
  type        = list(string)
  default     = null
} 

variable "env_config" {
  description = "Environment configuration"
  type = object({
    node_instance_types = list(string)
    desired_capacity = number
    min_capacity = number
    max_capacity = number
    disk_size = number
  })
}

variable "ebs_csi_driver_version" {
  description = "Version of the EBS CSI driver addon"
  type        = string
  default     = null  # Use latest available version when null
}

variable "cluster_autoscaler_chart_version" {
  description = "Version of the cluster autoscaler Helm chart"
  type        = string
  default     = null  # Use latest available version when null
}