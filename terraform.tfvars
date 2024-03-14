# Versioning for all services.
versions = {
  kubernetes_cluster           = "v1.29.2+1"
  cert-manager                 = "1.14.2"
  nginx-ingress-controller     = "4.9.1"
  postgres-operator            = "5.5.0"
  prometheus-stack             = "56.8.0"
  external-dns                 = "1.14.3"
  vault                        = "0.27.0"
  loki                         = "5.43.3"
  prometheus-blackbox-exporter = "8.12.0"
  dex                          = "0.16.0"
}

# Postgres Matrix Synapse
pg_matrix = {
  pg_cluster_name      = "synapse"
  pg_image             = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres"
  pg_image_tag         = "ubi8-15.5-0"
  pg_version           = 15
  namespace            = "matrix-synapse"
  pgbackrest_image     = "registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest"
  pgbackrest_image_tag = "ubi8-2.47-2"
}

# Postgres IXO Core DB
pg_ixo = {
  pg_cluster_name = "ixo-postgres"
  pg_image        = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres"
  pg_image_tag    = "ubi8-15.5-0"
  pg_users = [
    {
      username  = "cellnode"
      databases = ["cellnode"]
    }
  ]
  pg_version             = 15
  pgbackrest_image       = "registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest"
  pgbackrest_image_tag   = "ubi8-2.47-2"
  pgmonitoring_image     = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres-exporter"
  pgmonitoring_image_tag = "ubi8-5.5.0-0"
}