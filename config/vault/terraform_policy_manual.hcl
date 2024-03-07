# Child token for authentication to access root API
path "auth/token/create" {
  capabilities = ["create", "update", "sudo"]
}

# List, create, update, and delete mounts
path "sys/mounts" {
  capabilities = ["create", "update", "read", "delete", "patch", "list"]
}

# List, create, update, and delete mounts.
path "sys/mounts/*" {
  capabilities = ["create", "update", "read", "delete", "patch", "list"]
}

path "sys/auth/*" {
  capabilities = ["create", "update", "read", "delete", "patch", "list", "sudo"]
}

# Allow access to login using the userpass method for Terraform
path "auth/userpass/login/terraform" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/kubernetes/role/argocd" {
  capabilities = ["create", "update", "delete", "read"]
}

# List, create, update, and delete key/value secrets
path "*" {
  capabilities = ["create", "update", "patch", "read", "delete"]
}