variable "argo_version" {
  type    = string
  default = "6.0.3"
}

variable "applications" {
  type = list(
    object(
      {
        name            = string
        namespace       = string
        owner           = string
        repository      = string
        path            = optional(string)
        values_override = optional(string)
      }
    )
  )
}

variable "applications_helm" {
  type = list(
    object(
      {
        name            = string
        namespace       = string
        repository      = string
        chart           = string
        revision        = string
        values_override = optional(string)
      }
    )
  )
}

variable "git_repositories" {
  type = list(
    object(
      {
        name       = string
        repository = string
      }
    )
  )
}