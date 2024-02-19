locals {
  ixo_helm_chart_repository      = "https://github.com/ixofoundation/ixo-helm-charts"
  jetstack_helm_chart_repository = "https://charts.jetstack.io"
  postgres_operator_config_path  = "${path.root}/config/yml/postgres-operator"
  helm_values_config_path        = "${path.root}/config/yml/helm_values"
  region_ids                     = { for city, id in var.region_ids : id => city }
}