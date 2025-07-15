variable "existing_blocksync_pod_label_name" {
  type = string
}

variable "migration_pod_name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "image" {
  type = string
  default = "null"
}

variable "db_info" {
  type = object({
    pgUsername  = string
    pgPassword  = string
    pgCluster   = string
    pgNamespace = string
    useAlt      = bool
  })
}

variable "env_overrides" {
  type        = map(string)
  default     = {}
  description = "Map of environment variable names to override with custom values"
}