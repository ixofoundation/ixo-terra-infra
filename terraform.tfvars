# Domain mappings
# Define the actual domains for each domain identifier used in application configs.
# If you're customizing this for your own deployment, ensure all domain keys 
# referenced in the application_configs below are defined here.
domains = {
  ixoworld        = "ixo.world"       # Used for mainnet production services
  ixoearth        = "ixo.earth"       # Used for development and community services  
  emerging        = "emerging.eco"    # Used for emerging ecosystem services
  impacts_network = "impacts.network" # Used for impacts network services
}

# Organization name - used for resource naming and identification
org            = "ixofoundation"
cloud_provider = "aws"

# Storage classes
storage_classes = {
  "standard" = "vultr-block-storage"     # Standard storage (SSD)
  "fast"     = "vultr-block-storage"     # Fast storage (SSD)
  "bulk"     = "vultr-block-storage-hdd" # Slower, Cheaper, Bulk storage (HDD)
  "shared"   = "vultr-vfs-storage"       # NVME shared storage, slower than block storage, but faster than bulk storage.
}

# Repository configuration
ixo_helm_chart_repository  = "https://github.com/ixofoundation/ixo-helm-charts"
ixo_terra_infra_repository = "https://github.com/ixofoundation/ixo-terra-infra"
vault_core_mount           = "ixo_core"

# Versioning for all services.
versions = {
  kubernetes_cluster       = "v1.35.2+1"
  argocd                   = "9.5.0"  # https://artifacthub.io/packages/helm/argo/argo-cd
  cert-manager             = "1.20.2" # https://artifacthub.io/packages/helm/cert-manager/cert-manager
  nginx-ingress-controller = "2.4.4"  # https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx
  postgres-operator        = "6.0.1"  # https://access.crunchydata.com/documentation/postgres-operator/6.0/installation/helm
  prometheus-stack         = "83.4.3" # https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack
  external-dns             = "1.20.0" # https://artifacthub.io/packages/helm/external-dns/external-dns
  vault                    = "0.32.0" # https://artifacthub.io/packages/helm/hashicorp/vault
  # vault image for the snapshot CronJob; match the running server version.
  vault_cli                    = "1.21.2"
  loki                         = "6.55.0"  # https://github.com/grafana/loki/blob/main/production/helm/loki/Chart.yaml
  prometheus-blackbox-exporter = "11.9.1"  # https://artifacthub.io/packages/helm/prometheus-community/prometheus-blackbox-exporter
  dex                          = "0.24.0"  # https://artifacthub.io/packages/helm/dex/dex
  tailscale                    = "1.96.5"  # https://pkgs.tailscale.com/helmcharts/index.yaml
  matrix                       = "3.12.28" # https://artifacthub.io/packages/helm/ananace-charts/matrix-synapse
  openebs                      = "4.4.0"   # https://artifacthub.io/packages/helm/openebs/openebs
  metrics-server               = "3.13.0"  # https://artifacthub.io/packages/helm/metrics-server/metrics-server
  descheduler                  = "0.35.1"  # https://artifacthub.io/packages/helm/descheduler/descheduler
  vpa                          = "4.12.3"  # https://artifacthub.io/packages/helm/fairwinds-stable/vpa (upstream VPA v1.6.0)
  hummingbot                   = "0.2.0"
  uptime-kuma                  = "4.1.0"    # https://artifacthub.io/packages/helm/uptime-kuma/uptime-kuma
  chromadb                     = "0.2.2"    # https://github.com/amikos-tech/chromadb-chart
  ghost                        = "25.0.4"   # https://artifacthub.io/packages/helm/bitnami/ghost
  neo4j                        = "2026.3.1" # https://artifacthub.io/packages/helm/neo4j-helm-charts/neo4j
  falco_security               = "8.0.2"    # https://artifacthub.io/packages/helm/falcosecurity/falco
  redis                        = "25.3.11"  # https://artifacthub.io/packages/helm/bitnami/redis
  surrealdb                    = "0.4.0"    # https://artifacthub.io/packages/helm/surrealdb/surrealdb
  searxng                      = "1.0.1"    # https://github.com/searxng/searxng-helm-chart/tree/main/searxng
  external-secrets             = "2.7.0"    # https://artifacthub.io/packages/helm/external-secrets-operator/external-secrets
  reloader                     = "2.2.14"   # https://artifacthub.io/packages/helm/stakater/reloader
}

# Environment base configurations (static values only)
# Empty: every workspace sets its own environments in its var-file.
environments = {}

# Additional manual synthetic monitoring endpoints
additional_manual_synthetic_monitoring_endpoints = {}

# Postgres Matrix Synapse
pg_matrix = {
  pg_cluster_name = "synapse"
  pg_image        = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres"
  pg_image_tag    = "ubi8-15.5-0"
  pg_users = [
    {
      username  = "synapse"
      options   = "SUPERUSER"
      databases = []
    }
  ]
  pg_version             = 15
  namespace              = "matrix-synapse"
  pgbackrest_image       = "registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest"
  pgbackrest_image_tag   = "ubi8-2.47-2"
  pgmonitoring_image     = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres-exporter"
  pgmonitoring_image_tag = "ubi8-5.5.0-0"
}

# Postgres IXO Core DB
# TODO improve pg_users to be a map instead of a list.
pg_ixo = {
  pg_cluster_name = "ixo-postgres"
  pg_image        = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres"
  pg_image_tag    = "ubi8-15.5-0"
  pg_users = [
    { // 0
      username  = "admin"
      databases = ["postgres"]
      options   = "SUPERUSER"
    },
    { // 1
      username  = "cellnode"
      databases = ["cellnode"]
    },
    { // 2
      username  = "blocksync-core"
      databases = ["blocksync-core", "blocksync-core_alt"]
    },
    { // 3
      username  = "blocksync"
      databases = ["blocksync", "blocksync_alt"]
    },
    { // 4
      username  = "deeplink"
      databases = ["deeplink"]
    },
    { // 5
      username  = "kyc"
      databases = ["kyc"]
    },
    { // 6
      username  = "coin-server"
      databases = ["coin-server"]
    },
    { // 7
      username  = "faq-assistant"
      databases = ["faq-assistant"]
    },
    { // 8
      username  = "whizz"
      databases = ["whizz"]
    },
    { // 9
      username  = "iot-data"
      databases = ["iot-data"]
    },
    { // 10
      username  = "notification-server"
      databases = ["notification-server"]
    }, // 11
    {
      username  = "trading-bot-server"
      databases = ["trading-bot-server"]
    }, // 12
    {
      username  = "payments-nest"
      databases = ["payments-nest"]
    },
    { // 13
      username  = "message-relayer"
      databases = ["message-relayer"]
    },
    { // 14
      username  = "subscriptions-oracle-bot"
      databases = ["subscriptions-oracle-bot"]
    },
    { // 15
      username  = "observable-framework-builder"
      databases = ["observable-framework-builder"]
    },
    { // 16
      username  = "pathgen-oracle"
      databases = ["pathgen-oracle"]
    },
    { // 17
      username  = "jokes-oracle"
      databases = ["jokes-oracle"]
    },
    { // 18
      username  = "supamoto-bot"
      databases = ["supamoto-bot"]
    },
    { // 19
      username  = "supamoto-claims-bot"
      databases = ["supamoto-claims-bot"]
    },
    { // 20
      username  = "firecrawl"
      databases = ["firecrawl"]
    },
    { // 21
      username  = "ussd-supamoto"
      databases = ["ussd-supamoto"]
    },
    { // 22
      username  = "sygnal"
      databases = ["sygnal"]
    },
    { // 23
      username  = "feegrant-nest"
      databases = ["feegrant-nest"]
    },
    { // 24
      username  = "eval-engine"
      databases = ["eval-engine"]
    },
    { // 25
      username  = "3cx-server"
      databases = ["3cx-server"]
    }
  ]
  pg_version             = 15
  pgbackrest_image       = "registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest"
  pgbackrest_image_tag   = "ubi8-2.47-2"
  pgmonitoring_image     = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres-exporter"
  pgmonitoring_image_tag = "ubi8-5.5.0-0"
}

# Postgres major version upgrades, per workspace. See variable "pg_upgrade" in variables.tf
# for the staged sequence. Omitting a workspace means no upgrade is configured there.
#
# Image tags must match those the running operator resolves; read them from the pgo
# Deployment's RELATED_IMAGE_POSTGRES_* and RELATED_IMAGE_PGBACKREST environment variables,
# and re-read them whenever the operator is upgraded.
pg_upgrade = {
  # Preconditions before setting shutdown = true:
  #   - use_otel applied, with ccp_* metrics served on 9187 and logs reaching Loki
  #   - a current full backup on both clusters
  #   - enough free space on each data volume for both major versions plus WAL growth,
  #     since transfer_method = "Copy" retains the old data directory. Remove it after
  #     cutover and confirm WAL archiving is succeeding, or the volume will fill.
}

additional_prometheus_scrape_metrics = {}