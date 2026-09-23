# Non-sensitive application config, stored under ixo_core/config/<app>.
# Bound to the ConfigEditors external identity group (GitHub team
# "<workspace>-config"). Deliberately excludes ixo_core/data/<app>, so config
# editors never gain read on the sibling secret paths.

# Browse the whole mount. KV v2 keeps values under data/ and only key names and
# version info under metadata/, so this reveals which apps exist, never a value.
path "ixo_core/metadata/*" {
  capabilities = ["list"]
}

# Full read/write on config paths only. The trailing slash before the glob is
# load-bearing: "ixo_core/data/config*" would also match a path such as
# "ixo_core/data/configuration-secrets".
path "ixo_core/data/config/*" {
  capabilities = ["create", "read", "update", "patch", "delete", "list"]
}

# read+list only. "delete" on a metadata path destroys every version irrecoverably.
path "ixo_core/metadata/config/*" {
  capabilities = ["read", "list"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
