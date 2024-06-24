variable "existing_blocksync_pod_label_name" {
  type = string
}

variable "namespace" {
  type = string
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