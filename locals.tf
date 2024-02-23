locals {
  ixo_helm_chart_repository      = "https://github.com/ixofoundation/ixo-helm-charts"
  jetstack_helm_chart_repository = "https://charts.jetstack.io"
  postgres_operator_config_path  = "${path.root}/config/yml/postgres-operator"
  helm_values_config_path        = "${path.root}/config/yml/helm_values"
  region_ids                     = { for city, id in var.region_ids : id => city }
  pg_users_usernames             = [for user in var.pg_ixo.pg_users : user.username]
  pg_users_yaml = yamlencode(
    [
      for user in var.pg_ixo.pg_users : {
        name      = user.username
        databases = user.databases
        options   = "NOSUPERUSER"
      }
    ]
  )
}