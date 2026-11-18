variable "vpc_id" {
  type = string
}

variable "route_table_ids" {
  type = list(string)
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "extra_buckets" {
  description = "Extra same-region buckets nodes may read through the endpoint"
  type        = list(string)
  default     = []
}
