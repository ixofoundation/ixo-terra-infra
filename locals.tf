locals {
  # IXO
  ixo_helm_chart_repository = "https://github.com/ixofoundation/ixo-helm-charts"
  vault_core_mount          = "ixo_core"
  synthetic_monitoring_endpoints = [ #TODO investigate if this can be auto configured.
    "https://${var.hostnames[terraform.workspace]}/cellnode",
    "https://${var.hostnames[terraform.workspace]}/blocksync"
  ]

  # Vultr
  region_ids = { for city, id in var.region_ids : id => city }

  # Helm
  helm_values_config_path = "${path.root}/config/yml/helm_values"

  # Postgres Operator
  postgres_operator_config_path = "${path.root}/config/yml/postgres-operator"
  pg_users_usernames            = [for user in var.pg_ixo.pg_users : user.username]
  pg_users_yaml = yamlencode(
    [
      for user in var.pg_ixo.pg_users : {
        name      = user.username
        databases = user.databases
        options   = "NOSUPERUSER"
      }
    ]
  )

  # Argo Helm Ignore Differences
  prometheus_stack_ignore_differences = <<EOT
- group: monitoring.coreos.com
  kind: ServiceMonitor
  jqPathExpressions:
    - .metadata.annotations
    - .spec
    - .spec.endpoints[]?.relabelings[]?.action
- group: monitoring.coreos.com
  kind: PodMonitor
  jqPathExpressions:
    - .metadata.annotations
    - .spec
    - .spec.endpoints[]?.relabelings[]?.action
EOT
  loki_ignore_differences             = <<EOT
- group: monitoring.coreos.com
  kind: ServiceMonitor
  jqPathExpressions:
    - .metadata.annotations
    - .spec
    - .spec.endpoints[]?.relabelings[]?.action
- group: monitoring.coreos.com
  kind: PodMonitor
  jqPathExpressions:
    - .metadata.annotations
    - .spec
    - .spec.endpoints[]?.relabelings[]?.action
EOT
  vault_ignore_differences            = <<EOT
- group: apps
  kind: StatefulSet
  jqPathExpressions:
    - '.spec.volumeClaimTemplates[]?'
EOT
}