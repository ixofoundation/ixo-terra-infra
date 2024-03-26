# Versioning for all services.
versions = {
  kubernetes_cluster           = "v1.29.2+1"
  cert-manager                 = "1.14.4" # https://artifacthub.io/packages/helm/cert-manager/cert-manager
  nginx-ingress-controller     = "4.10.0" # https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx
  postgres-operator            = "5.5.0"  # https://access.crunchydata.com/documentation/postgres-operator/5.5/installation/helm
  prometheus-stack             = "57.1.1" # https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack
  external-dns                 = "1.14.3" # https://artifacthub.io/packages/helm/external-dns/external-dns
  vault                        = "0.27.0" # https://artifacthub.io/packages/helm/hashicorp/vault
  loki                         = "5.47.1" # https://artifacthub.io/packages/helm/grafana/loki
  prometheus-blackbox-exporter = "8.12.0" # https://artifacthub.io/packages/helm/prometheus-community/prometheus-blackbox-exporter
  dex                          = "0.17.0" # https://artifacthub.io/packages/helm/dex/dex
  tailscale                    = "1.62.0" # https://pkgs.tailscale.com/helmcharts/index.yaml
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