pg_matrix = {
  pg_cluster_name      = "synapse"
  pg_image             = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres"
  pg_image_tag         = "ubi8-15.5-0"
  pg_version           = 15
  namespace            = "matrix-synapse"
  pgbackrest_image     = "registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest"
  pgbackrest_image_tag = "ubi8-2.47-2"
}

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
  pg_version           = 15
  pgbackrest_image     = "registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest"
  pgbackrest_image_tag = "ubi8-2.47-2"
}