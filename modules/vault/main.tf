resource "null_resource" "init" {
  provisioner "local-exec" {
    command = "KUBECONFIG=${var.kube_config_path} kubectl exec -n ${var.namespace} ${var.name}-0 -- vault operator init -format=json > cluster-keys-for-kms-vault.json"
  }
}

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "kubernetes_secret_v1" "repo_server" {
  metadata {
    annotations = {
      "kubernetes.io/service-account.name" = "vault"
    }
    namespace = var.namespace

    generate_name = "${var.name}-"
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

resource "vault_policy" "argocd" {
  name = "argocd"

  policy = var.argo_policy
}

# Create Vault -> Kubernetes Auth
resource "null_resource" "vault_kubernetes_config" {
  depends_on = [vault_auth_backend.kubernetes]
  provisioner "local-exec" {
    command = "KUBECONFIG=${var.kube_config_path} kubectl exec -n ${var.namespace} ${var.name}-0 -- vault write auth/kubernetes/config token_reviewer_jwt=${kubernetes_secret_v1.repo_server.data.token} kubernetes_host=https://${var.kubernetes_host}:6443 kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
  }
}

# Create role for ArgoCD to read secrets on sync
resource "null_resource" "vault_argocd_role" {
  depends_on = [vault_auth_backend.kubernetes, null_resource.vault_kubernetes_config]
  provisioner "local-exec" {
    command = "KUBECONFIG=${var.kube_config_path} kubectl exec -n ${var.namespace} ${var.name}-0 -- vault write auth/kubernetes/role/argocd bound_service_account_names=argocd-repo-server bound_service_account_namespaces=${var.argo_namespace} policies=argocd ttl=1h"
  }
}
