variable "k8_version" {
  description = "Kubernetes version to be used"
  type        = string
  default     = "v1.29.1+1"
}

variable "cluster_region" {
  description = "Region for the Kubernetes cluster"
  type        = string
  default     = "jnb"
}

variable "cluster_label" {
  description = "Label for the Kubernetes cluster"
  type        = string
  default     = "vke-test"
}

variable "cluster_firewall" {
  description = "Enable Firewall for the Kubernetes cluster"
  type        = bool
  default     = false
}

variable "ha_controlplanes" {
  description = "Enable High Availability for the Kubernetes cluster"
  type        = bool
  default     = false
}

variable "initial_node_pool_plan" {
  description = "Initial Node Pool Plan for the Kubernetes cluster"
  type        = string
  default     = "vc2-1c-2gb"
}

variable "initial_node_pool_quantity" {
  description = "Initial Node Pool Quantity for the Kubernetes cluster"
  type        = number
  default     = 2
}

variable "initial_node_pool_label" {
  description = "Initial Node Pool Label for the Kubernetes cluster"
  type        = string
  default     = "vke-nodepool"
}

variable "initial_node_pool_scaler" {
  description = "Initial Node Pool Autoscaling for the Kubernetes cluster"
  type        = bool
  default     = true
}
variable "initial_node_pool_min_nodes" {
  description = "Initial Node Pool Min Nodes for the Kubernetes cluster"
  type        = number
  default     = 1
}
variable "initial_node_pool_max_nodes" {
  description = "Initial Node Pool Max Nodes for the Kubernetes cluster"
  type        = number
  default     = 3
}