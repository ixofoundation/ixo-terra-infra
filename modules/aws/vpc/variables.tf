variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "env_config" {
  description = "Environment configuration"
  type = object({
    nat_gateway_enabled = bool
    flow_logs_enabled = bool
    retention_days = number
    az_count = number
  })
}

variable "is_development" {
  type = bool
  default = null
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to create subnets in"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "subnet_bits" {
  description = "Number of bits to add to the VPC CIDR for subnet CIDR calculation"
  type        = number
  default     = 8
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Whether to enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain VPC Flow Logs"
  type        = number
  default     = 30
} 