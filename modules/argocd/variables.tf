variable "argo_version" {
  type = string
  default = "6.0.3"
}

variable "argo_chart_repository" {
  type = string
}

variable "applications" {
  type = list(
    object(
      {
        name = string
        namespace = string
      }
    )
  )
}