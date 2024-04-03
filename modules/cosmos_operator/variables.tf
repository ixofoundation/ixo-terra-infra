variable "kubeconfig_path" {
  type = string
  default = ""
}

variable "cosmos_operator" {
  type = object(
    {
      image = string
      tag = string
    }
  )
}