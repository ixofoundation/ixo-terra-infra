terraform {
  required_providers {
    vultr = {
      source = "vultr/vultr"
    }
  }
}

resource "vultr_kubernetes" "k8" {
  provider         = vultr
  region           = var.cluster_region
  label            = var.cluster_label
  version          = var.k8_version
  enable_firewall  = var.cluster_firewall
  ha_controlplanes = var.ha_controlplanes

  node_pools {
    node_quantity = var.initial_node_pool_quantity
    plan          = var.initial_node_pool_plan
    label         = var.initial_node_pool_label
    auto_scaler   = var.initial_node_pool_scaler
    min_nodes     = var.initial_node_pool_min_nodes
    max_nodes     = var.initial_node_pool_max_nodes
  }
}

resource "local_file" "kubeconfig" {
  content = base64decode(vultr_kubernetes.k8.kube_config)
  filename = local.kubeconfig_filename
}