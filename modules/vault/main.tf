resource "null_resource" "init" {
  provisioner "local-exec" {
    command = "KUBECONFIG=${var.kube_config_path} kubectl exec -n ${var.namespace} ${var.name}-0 -- vault operator init -format=json > cluster-keys-for-kms-vault.json || true"
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
#resource "null_resource" "vault_kubernetes_config" {
#  depends_on = [vault_auth_backend.kubernetes]
#  provisioner "local-exec" {
#    command = "KUBECONFIG=${var.kube_config_path} kubectl exec -n ${var.namespace} ${var.name}-0 -- vault login -method=userpass username=terraform password=$TERRAFORM_VAULT_PASSWORD && vault write auth/kubernetes/config token_reviewer_jwt=${kubernetes_secret_v1.repo_server.data.token} kubernetes_host=https://${var.kubernetes_host}:6443 kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
#  }
#}

resource "vault_kubernetes_auth_backend_config" "vault_kubernetes_config" {
  kubernetes_host    = "https://${var.kubernetes_host}:6443"
  backend            = vault_auth_backend.kubernetes.path
  kubernetes_ca_cert = kubernetes_secret_v1.repo_server.data["ca.crt"]
  token_reviewer_jwt = kubernetes_secret_v1.repo_server.data.token
}

# Create role for ArgoCD to read secrets on sync
resource "null_resource" "vault_argocd_role" {
  depends_on = [vault_auth_backend.kubernetes, vault_kubernetes_auth_backend_config.vault_kubernetes_config]
  provisioner "local-exec" {
    command = "KUBECONFIG=${var.kube_config_path} kubectl exec -n ${var.namespace} ${var.name}-0 -- vault write auth/kubernetes/role/argocd bound_service_account_names=argocd-repo-server bound_service_account_namespaces=${var.argo_namespace} policies=argocd ttl=1h"
  }
}

# Vault -> Dex OIDC
resource "vault_jwt_auth_backend" "oidc" {
  description        = "JWT Auth with Dex + GitHub"
  path               = "oidc"
  type               = "oidc"
  oidc_discovery_url = "https://${var.dex_host}"
  default_role       = "reader"
  oidc_client_id     = "vault-client"
  oidc_client_secret = var.oidc_client_secret
}

# Reader IXO_CORE Role (Default)
resource "vault_policy" "reader" {
  name   = "reader"
  policy = file("${path.root}/config/vault/reader.hcl")
}

resource "vault_jwt_auth_backend_role" "reader" {
  backend      = "oidc"
  role_name    = "reader"
  groups_claim = "groups"
  oidc_scopes  = ["groups"]
  bound_claims = {
    groups = "${var.org}:ixo_core"
  }
  token_policies        = [vault_policy.reader.name]
  user_claim            = "sub"
  role_type             = "oidc"
  allowed_redirect_uris = ["http://localhost:8200/ui/vault/auth/oidc/oidc/callback", "https://${var.vault_host}/ui/vault/auth/oidc/oidc/callback", "http://localhost:8250/oidc/callback"]
}

# Admin Role
resource "vault_policy" "oidc_admin" {
  name   = "admin"
  policy = file("${path.root}/config/vault/admin.hcl")
}

resource "vault_jwt_auth_backend_role" "admin" {
  backend        = "oidc"
  role_name      = "admin"
  token_policies = [vault_policy.oidc_admin.name]
  groups_claim   = "groups"
  oidc_scopes    = ["groups"]
  bound_claims = {
    groups = "${var.org}:${terraform.workspace}-devsecops"
  }
  user_claim            = "sub"
  role_type             = "oidc"
  allowed_redirect_uris = ["http://localhost:8200/ui/vault/auth/oidc/oidc/callback", "https://${var.vault_host}/ui/vault/auth/oidc/oidc/callback", "http://localhost:8250/oidc/callback"]
}

# Devsecops Admin Team
resource "vault_identity_group" "devops" {
  name     = "Devops"
  policies = [vault_policy.oidc_admin.name]
  type     = "external"
  metadata = {
    organization = "ixofoundation"
  }
}

resource "vault_identity_group_alias" "devops" {
  canonical_id   = vault_identity_group.devops.id
  mount_accessor = vault_jwt_auth_backend.oidc.accessor
  name           = "${var.org}:${terraform.workspace}-devsecops"
}