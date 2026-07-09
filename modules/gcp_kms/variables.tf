variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "rotation_period" {
  type    = string
  default = "15552000s" # 180 days
}