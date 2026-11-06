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

variable "kubeconfig_name" {
  description = "Suffix of the generated kubeconfig file; defaults to environment. Two workspaces sharing an environment name would otherwise overwrite each other's kubeconfig."
  type        = string
  default     = null
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

variable "authentication_mode" {
  description = "EKS authentication mode. Null leaves access_config unmanaged. Leaving CONFIG_MAP is one-way."
  type        = string
  default     = null

  validation {
    condition     = var.authentication_mode == null || contains(["CONFIG_MAP", "API_AND_CONFIG_MAP", "API"], coalesce(var.authentication_mode, "CONFIG_MAP"))
    error_message = "authentication_mode must be null, CONFIG_MAP, API_AND_CONFIG_MAP or API."
  }
}

variable "cluster_admin_arns" {
  description = "IAM principal ARNs given AmazonEKSClusterAdminPolicy at cluster scope via access entries. Never the cluster creator, whose entry EKS creates itself."
  type        = list(string)
  default     = []
}

variable "env_config" {
  description = "Environment configuration"
  type = object({
    node_instance_types = list(string)
    desired_capacity    = number
    min_capacity        = number
    max_capacity        = number
    disk_size           = number
  })
}

variable "ebs_csi_driver_version" {
  description = "Version of the EBS CSI driver addon"
  type        = string
  default     = null # Use latest available version when null
}

variable "cluster_autoscaler_chart_version" {
  description = "Version of the cluster autoscaler Helm chart"
  type        = string
  default     = null # Use latest available version when null
}
variable "aws_profile" {
  description = "AWS_PROFILE set in the kubeconfig's exec env (with the static AWS_* key vars blanked). Null leaves the exec env as the caller's."
  type        = string
  default     = null
}

variable "aws_cli_path" {
  description = "Command the kubeconfig execs for `aws eks get-token`."
  type        = string
  default     = "/usr/local/bin/aws"
}

variable "service_ipv4_cidr" {
  description = "Kubernetes service CIDR. ForceNew on the cluster; null leaves the EKS default."
  type        = string
  default     = null
}

variable "storage_class_parameters" {
  description = "Extra parameters merged into every EBS StorageClass (e.g. encrypted). StorageClass parameters are immutable, so changing this replaces the classes."
  type        = map(string)
  default     = {}
}

variable "on_demand_node_count" {
  description = "Size of an additional ON_DEMAND node group next to the main one. 0 = no such group."
  type        = number
  default     = 0
}

variable "on_demand_node_instance_types" {
  description = "Instance types for the ON_DEMAND node group."
  type        = list(string)
  default     = ["t3a.xlarge"]
}

variable "db_nodes_per_az" {
  description = "ON_DEMAND database nodes per AZ (tainted ixo.world/pool=db, launch template only). 0 = no DB groups."
  type        = number
  default     = 0
}

variable "db_node_instance_types" {
  description = "Instance types for the database node groups."
  type        = list(string)
  default     = ["t3a.large"]
}

variable "node_launch_template_tags" {
  description = "Tags for node instances, root volumes and ENIs via a launch template. Empty = no launch template (node groups as before)."
  type        = map(string)
  default     = {}
}

variable "node_root_volume_type" {
  description = "Root EBS volume type in the node launch template (keep what the nodes have today)."
  type        = string
  default     = "gp3" # EKS's generated AL2023 template
}

variable "node_metadata_hop_limit" {
  description = "IMDSv2 hop limit in the node launch template (EKS's generated AL2023 template uses 1, verified live)."
  type        = number
  default     = 1
}

variable "node_legacy_groups" {
  description = "Keep the original (pre-launch-template) node groups. Set false once the -lt groups have taken over: count 0 destroys them (no state move)."
  type        = bool
  default     = true
}
