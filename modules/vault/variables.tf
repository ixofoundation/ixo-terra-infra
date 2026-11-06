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

variable "org" {
  type = string
}
# Creates the raft-snapshot policy and auth role.
variable "raft_snapshot_enabled" {
  type    = bool
  default = false
}

# True where Vault is already initialized (e.g. by a snapshot restore); skips null_resource.init.
variable "vault_already_initialized" {
  type    = bool
  default = false
}

# GitHub team slug for the OIDC group aliases and admin bound claims. Defaults to the workspace name.
variable "oidc_team_segment" {
  type    = string
  default = null
}
