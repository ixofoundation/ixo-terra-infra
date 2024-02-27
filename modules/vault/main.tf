resource "null_resource" "init" {
  provisioner "local-exec" {
    command = "kubectl exec -n ${var.namespace} ${var.name}-0 -- vault operator init -key-shares=${var.init_params.key_shares} -key-threshold=${var.init_params.key_threshold} -format=json > cluster-keys.json"
  }
}