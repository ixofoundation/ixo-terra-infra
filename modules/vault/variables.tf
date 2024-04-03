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

variable "dex_host" {
  type = string
}

variable "oidc_client_secret" {
  type = string
}

variable "vault_host" {
  type = string
}

variable "vault_terraform_password" {
  type = string
}

variable "org" {
  type = string
}