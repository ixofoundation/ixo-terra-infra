path "ixo_core/data/*" {
  capabilities = ["read"]
}

path "ixo_core/metadata/*" {
  capabilities = ["read", "list"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
