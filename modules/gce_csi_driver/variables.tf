# Path to directory holding Service Account, Directory must include file `cloud-sa.json`
variable "service_account_dir" {
  type = string
}

variable "driver_version" {
  type    = string
  default = "stable-master"
}

variable "kubeconfig_path" {
  type = string
}