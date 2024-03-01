variable "namespace" {
  type = string
}

variable "name" {
  type = string
}

variable "init_params" {
  type = object(
    {
      key_shares    = number
      key_threshold = number
    }
  )
}

variable "kube_config_path" {
  type = string
}

variable "kubernetes_host" {
  type = string
}

variable "argo_namespace" {
  type = string
}

variable "argo_policy" {
  type = string
}