# List auth methods
path "sys/auth"
{
  capabilities = ["read"]
}

# List existing policies
path "sys/policies/acl"
{
  capabilities = ["read","list"]
}

# List, create, update, and delete key/value secrets
path "secret/*"
{
  capabilities = ["read"]
}

# Manage secret engines
path "sys/mounts/*"
{
  capabilities = ["read"]
}

# List existing secret engines.
path "sys/mounts"
{
  capabilities = ["read"]
}

# Read health checks
path "sys/health"
{
  capabilities = ["read"]
}