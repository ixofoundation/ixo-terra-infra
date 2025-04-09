# Versioning for all services.
versions = {
  kubernetes_cluster           = "v1.32.2+1"
  argocd                       = "7.8.23"  # https://artifacthub.io/packages/helm/argo/argo-cd
  cert-manager                 = "1.17.1" # https://artifacthub.io/packages/helm/cert-manager/cert-manager
  nginx-ingress-controller     = "4.12.1" # https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx
  postgres-operator            = "5.6.1"  # https://access.crunchydata.com/documentation/postgres-operator/5.5/installation/helm
  prometheus-stack             = "70.4.2" # https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack
  external-dns                 = "1.14.5" # https://artifacthub.io/packages/helm/external-dns/external-dns
  vault                        = "0.30.0" # https://artifacthub.io/packages/helm/hashicorp/vault
  loki                         = "6.29.0" # https://artifacthub.io/packages/helm/grafana/loki
  prometheus-blackbox-exporter = "9.4.0"  # https://artifacthub.io/packages/helm/prometheus-community/prometheus-blackbox-exporter
  dex                          = "0.23.0" # https://artifacthub.io/packages/helm/dex/dex
  tailscale                    = "1.82.0" # https://pkgs.tailscale.com/helmcharts/index.yaml
  matrix                       = "3.11.7" # https://artifacthub.io/packages/helm/ananace-charts/matrix-synapse
  openebs                      = "4.2.0" # https://artifacthub.io/packages/helm/openebs/openebs
  metrics-server               = "3.12.2" # https://artifacthub.io/packages/helm/metrics-server/metrics-server
  nfs                          = "1.8.0"  # https://artifacthub.io/packages/helm/nfs-ganesha-server-and-external-provisioner/nfs-server-provisioner
  hummingbot                   = "0.2.0"
}

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
      databases = ["blocksync-core"]
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
      username = "message-relayer"
      databases = ["message-relayer"]
    }
  ]
  pg_version             = 15
  pgbackrest_image       = "registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest"
  pgbackrest_image_tag   = "ubi8-2.47-2"
  pgmonitoring_image     = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres-exporter"
  pgmonitoring_image_tag = "ubi8-5.5.0-0"
}

additional_prometheus_scrape_metrics = {
  devnet = <<EOT
- job_name: 'validator'
  metrics_path: '/metrics'
  scheme: 'http'
  static_configs:
    - targets:
      - '139.84.231.209:9100'
  relabel_configs:
    - source_labels: [ __address__ ]
      target_label: instance
EOT
  testnet = <<EOT
- job_name: 'validator'
  metrics_path: '/metrics'
  scheme: 'http'
  static_configs:
    - targets:
      - '45.76.34.6:9100'
      - '136.244.107.1:9100'
      - '95.179.129.70:9100'
  relabel_configs:
    - source_labels: [ __address__ ]
      target_label: instance
- job_name: 'validator_cosmos'
  metrics_path: '/metrics/validators'
  scheme: 'http'
  static_configs:
    - targets:
      - '95.179.129.70:9300'
- job_name: 'validator_tendermint'
  metrics_path: '/'
  scheme: 'http'
  static_configs:
    - targets:
      - '95.179.129.70:26660'
EOT
  mainnet = <<EOT
- job_name: 'validator'
  metrics_path: '/metrics'
  scheme: 'http'
  static_configs:
    - targets:
      - '136.244.109.82:9100'
      - '95.179.158.151:9100'
      - '45.32.233.84:9100'
  relabel_configs:
    - source_labels: [ __address__ ]
      target_label: instance
- job_name: 'validator_cosmos'
  metrics_path: '/metrics/validators'
  scheme: 'http'
  static_configs:
    - targets:
      - '136.244.109.82:9300'
      - '95.179.158.151:9300'
      - '45.32.233.84:9300'
  relabel_configs:
    - source_labels: [ __address__ ]
      target_label: instance
- job_name: 'validator_tendermint'
  metrics_path: '/'
  scheme: 'http'
  static_configs:
    - targets:
      - '136.244.109.82:26660'
      - '95.179.158.151:26660'
      - '45.32.233.84:26660'
  relabel_configs:
    - source_labels: [ __address__ ]
      target_label: instance
EOT
}