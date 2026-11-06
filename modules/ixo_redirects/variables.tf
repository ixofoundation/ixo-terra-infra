variable "nginx_namespace" {
  type = string
}

variable "hosts" {
  description = "Hostnames that only redirect; each needs a matching $host block in the nginx server-snippets."
  type        = list(string)
}

variable "tls_secret_name" {
  type = string
}

variable "name" {
  type    = string
  default = "blockscan-rerouting"
}
