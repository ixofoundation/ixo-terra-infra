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