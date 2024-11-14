# Quickstart
vultr_api_key = "" # Required, Vultr API Key
org = "" # Required, Organization name

additional_manual_synthetic_monitoring_endpoints = { # Optional for Blackbox Exporter Probes, See `variables.tf`
  quickstart = []
}
hostnames = {} # Optional if setting up DNS entries, See `variables.tf`

environments = {
  quickstart = {
    cluster_firewall     = false # Vultr cluster firewall
    rpc_url              = "https://devnet.ixo.earth/rpc/"
    ipfs_service_mapping = "https://devnet-blocksync-graphql.ixo.earth/api/ipfs/"
    domain               = "" # Required if external facing (nginx + external-dns)
    domain2              = "" # Optional, set to domain if no other.
    enabled_services = {
      # Core
      cert_manager                  = false # SSL management
      ingress_nginx                 = false # Nginx
      postgres_operator_crunchydata = false # Postgres Database, some IXO services will require this
      prometheus_stack              = false # Metrics & Grafana dashboard
      external_dns                  = false # Configured to use Vultr Load balancer + DNS
      dex                           = false # Dex disabled for quickstart
      vault                         = true  # Vault enabled for secret management
      loki                          = false # Logs -> Grafana
      prometheus_blackbox_exporter  = false # DNS probes
      tailscale                     = false # VPN for access to Databases externally
      matrix                        = false # Matrix server
      nfs_provisioner               = false # NFS storage class for shared block storage
      metrics_server                = false # K8 Metrics

      # IXO-specific services
      ixo_cellnode                         = false
      ixo_blocksync                        = false
      ixo_blocksync_core                   = false
      ixo_feegrant_nest                    = false
      ixo_did_resolver                     = false
      ixo_faucet                           = false
      ixo_matrix_state_bot                 = false
      ixo_matrix_appservice_rooms          = false
      claims_credentials_ecs               = false
      claims_credentials_prospect          = false
      claims_credentials_carbon            = false
      claims_credentials_umuzi             = false
      claims_credentials_claimformprotocol = false
      claims_credentials_did               = false
      ixo_deeplink_server                  = false
      ixo_kyc_server                       = false
      ixo_faq_assistant                    = false
      ixo_coin_server                      = false
      ixo_stake_reward_claimer             = false
      ixo_ussd                             = false
      ixo_whizz                            = false
      auto_approve_offset                  = false
      ixo_iot_data                         = false
      ixo_notification_server              = false
      ixo_guru                             = false
      ixo_trading_bot_server               = false
      ixo_ai_oracles_guru                  = false
    }
  }
}

# Postgres Image & User setup.
# Note, for existing databases, you may need to run SQL scripts in config/sql/ixo-init.sql if there are DB permission issues on startup for a IXO service.
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
    }
  ]
  pg_version             = 15
  pgbackrest_image       = "registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest"
  pgbackrest_image_tag   = "ubi8-2.47-2"
  pgmonitoring_image     = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres-exporter"
  pgmonitoring_image_tag = "ubi8-5.5.0-0"
}

# Versioning for all services.
versions = {
  kubernetes_cluster           = "v1.30.0+1"
  argocd                       = "7.5.0"  # https://artifacthub.io/packages/helm/argo/argo-cd
  cert-manager                 = "1.15.3" # https://artifacthub.io/packages/helm/cert-manager/cert-manager
  nginx-ingress-controller     = "4.11.2" # https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx
  postgres-operator            = "5.6.1"  # https://access.crunchydata.com/documentation/postgres-operator/5.5/installation/helm
  prometheus-stack             = "62.3.1" # https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack
  external-dns                 = "1.14.5" # https://artifacthub.io/packages/helm/external-dns/external-dns
  vault                        = "0.28.1" # https://artifacthub.io/packages/helm/hashicorp/vault
  loki                         = "6.10.2" # https://artifacthub.io/packages/helm/grafana/loki
  prometheus-blackbox-exporter = "9.0.0"  # https://artifacthub.io/packages/helm/prometheus-community/prometheus-blackbox-exporter
  dex                          = "0.19.1" # https://artifacthub.io/packages/helm/dex/dex
  tailscale                    = "1.72.1" # https://pkgs.tailscale.com/helmcharts/index.yaml
  matrix                       = "3.9.10" # https://artifacthub.io/packages/helm/ananace-charts/matrix-synapse
  openebs                      = "3.10.0" # https://artifacthub.io/packages/helm/openebs/openebs
  metrics-server               = "3.12.1" # https://artifacthub.io/packages/helm/metrics-server/metrics-server
  nfs                          = "1.8.0"  # https://artifacthub.io/packages/helm/nfs-ganesha-server-and-external-provisioner/nfs-server-provisioner
  hummingbot                   = "0.2.0"
}