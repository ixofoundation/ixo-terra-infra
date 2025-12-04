# Domain mappings
# Define the actual domains for each domain identifier used in application configs.
# If you're customizing this for your own deployment, ensure all domain keys 
# referenced in the application_configs below are defined here.
domains = {
  ixoworld = "aws.ixo.world"     # Used for mainnet production services
  ixoearth = "aws.ixo.earth"     # Used for development and community services  
  emerging = "aws.emerging.eco"   # Used for emerging ecosystem services
}

# Organization name - used for resource naming and identification
org = "ixofoundationaws"
cloud_provider = "aws"

# Storage classes for AWS
# Keys must be "standard", "fast", "bulk", "shared"
storage_classes = {
  "standard" = "gp3"     # Standard storage (General Purpose SSD)
  "fast" = "gp3"         # Fast storage (General Purpose SSD)
  "bulk" = "st1"         # Throughput Optimized HDD (more compatible than sc1)
  "shared" = "efs"       # Shared storage (Elastic File System)
}

# Repository configuration
ixo_helm_chart_repository = "https://github.com/ixofoundation/ixo-helm-charts"
ixo_terra_infra_repository = "https://github.com/ixofoundation/ixo-terra-infra"
vault_core_mount = "ixo_core"

# Versioning for all services.
versions = {
  kubernetes_cluster           = "1.33"
  argocd                       = "7.8.23"  # https://artifacthub.io/packages/helm/argo/argo-cd
  cert-manager                 = "1.17.1" # https://artifacthub.io/packages/helm/cert-manager/cert-manager
  nginx-ingress-controller     = "4.12.1" # https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx
  postgres-operator            = "5.6.1"  # https://access.crunchydata.com/documentation/postgres-operator/5.5/installation/helm
  prometheus-stack             = "70.4.2" # https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack
  external-dns                 = "1.16.1" # https://artifacthub.io/packages/helm/external-dns/external-dns
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
  uptime-kuma                  = "2.21.2" # https://artifacthub.io/packages/helm/uptime-kuma/uptime-kuma
  chromadb                     = "0.1.23" # https://github.com/amikos-tech/chromadb-chart
  redis                        = "23.2.12" # https://artifacthub.io/packages/helm/bitnami/redis
}

gcp_project_ids = {
  "aws" = "devsecops-415617"
}
# Environment base configurations (static values only)
environments = {
  aws = {
    is_development = true
    cluster_firewall = true
    aws_region      = "eu-north-1"
    aws_iam_users   = []
    rpc_url         = "https://aws.ixo.earth/rpc/"
    ipfs_service_mapping = "https://ipfs.gateway.ixo.world"
    hyperlane = {
      chain_names     = [""]
      metadata_chains = [""]
    }
    aws_vpc_config = {
      nat_gateway_enabled = false
      flow_logs_enabled = false
      retention_days = 7
      az_count = 2
    }
    application_configs = {
      # Core Infrastructure Services
      cert_manager = {
        enabled = false
        domain = "ixoearth"
      }
      ingress_nginx = {
        enabled = true
        domain = "ixoearth"
      }
      postgres_operator_crunchydata = {
        enabled = false
        domain = "ixoearth"
      }
      prometheus_stack = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "awskb.ixo.earth"
      }
      external_dns = {
        enabled = true
        domain = "ixoearth"
      }
      dex = {
        enabled = true
        domain = "ixoearth"
        dns_prefix = "dex"
      }
      vault = {
        enabled = true
        domain = "ixoearth"
        dns_prefix = "vault"
      }
      loki = {
        enabled = false
        domain = "ixoearth"
      }
      prometheus_blackbox_exporter = {
        enabled = false
        domain = "ixoearth"
      }
      tailscale = {
        enabled = false
        domain = "ixoearth"
      }
      matrix = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "awsmx.ixo.earth"
      }
      matrix_admin = {
        enabled = false
        domain = "ixoearth"
        dns_prefix= "matrix.admin"
      }
      nfs_provisioner = {
        enabled = true
        domain = "ixoearth"
      }
      metrics_server = {
        enabled = false
        domain = "ixoearth"
      }
      hermes = {
        enabled = false
        domain = "ixoearth"
      }
      hyperlane_validator = {
        enabled = false
        domain = "ixoearth"
      }
      aws_vpc = {
        enabled = false
        domain = "ixoearth"
      }
      uptime_kuma = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "status.aws.ixo.earth"
      }
      chromadb = {
        enabled = false
        domain = "ixoearth"
      }
      redis = {
        enabled = true
        domain = "ixoearth"
        storage_class = "bulk"
        storage_size = "40Gi"
      }
      # IXO Services
      ixo_cellnode = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "aws-cellnode.ixo.earth"
      }
      ixo_blocksync = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "aws-blocksync-graphql.ixo.earth"
      }
      ixo_blocksync_core = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "ixo-blocksync-core.awskb.ixo.earth"
      }
      ixo_feegrant_nest = {
        enabled = false
        domain = "ixoearth"
        dns_prefix = "feegrant"
      }
      ixo_did_resolver = {
        enabled = false
        domain = "ixoearth"
        dns_prefix = "resolver"
      }
      ixo_faucet = {
        enabled = false
        domain = "ixoearth"
        dns_prefix = "faucet"
      }
      ixo_matrix_state_bot = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "state.bot.awsmx.ixo.earth"
      }
      ixo_matrix_appservice_rooms = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "rooms.bot.awsmx.ixo.earth"
      }
      claims_credentials_ecs = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "ecs.credentials.aws.ixo.earth"
      }
      claims_credentials_prospect = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "prospect.credentials.aws.ixo.earth"
      }
      claims_credentials_carbon = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "carbon.credentials.aws.ixo.earth"
      }
      claims_credentials_umuzi = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "umuzi.credentials.aws.ixo.earth"
      }
      claims_credentials_claimformprotocol = {
        enabled = false
        domain = "ixoearth"
      }
      claims_credentials_did = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "didoracle.credentials.aws.ixo.earth"
      }
      ixo_deeplink_server = {
        enabled = false
        domain = "ixoearth"
        dns_prefix = "deeplink"
      }
      ixo_kyc_server = {
        enabled = false
        domain = "ixoearth"
        dns_prefix = "kyc"
      }
      ixo_faq_assistant = {
        enabled = false
        domain = "ixoearth"
      }
      ixo_coin_server = {
        enabled = false
        domain = "ixoearth"
      }
      ixo_stake_reward_claimer = {
        enabled = false
        domain = "ixoearth"
      }
      ixo_ussd = {
        enabled = false
        domain = "ixoearth"
      }
      ixo_whizz = {
        enabled = false
        domain = "ixoearth"
      }
      auto_approve_offset = {
        enabled = false
        domain = "ixoearth"
      }
      ixo_iot_data = {
        enabled = false
        domain = "ixoearth"
      }
      ixo_notification_server = {
        enabled = false
        domain = "ixoearth"
      }
      ixo_guru = {
        enabled = false
        domain = "ixoearth"
      }
      ixo_trading_bot_server = {
        enabled = false
        domain = "ixoearth"
      }
      ixo_ai_oracles_guru = {
        enabled = false
        domain = "ixoearth"
      }
      ixo_ai_oracles_giza = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "giza.aws.ixo.earth"
      }
      ixo_payments_nest = {
        enabled = false
        domain = "ixoearth"
      }
      ixo_message_relayer = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "signx.aws.ixo.earth"
      }
      ixo_cvms_exporter = {
        enabled = false
        domain = "ixoearth"
      }
      ixo_registry_server = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "aws.api.emerging.eco"
      }
      ixo_agent_images_slack = {
        enabled = false
        domain = "ixoearth"
      }
      ixo_aws_iam = {
        enabled = false
        domain = "ixoearth"
      }
      ixo_matrix_bids_bot = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "bid.bot.awsmx.ixo.earth"
      }
      ixo_matrix_claims_bot = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "claim.bot.awsmx.ixo.earth"
      }
      ixo_subscriptions_oracle = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "subscriptions.oracle.aws.ixo.earth"
      }
      ixo_subscriptions_oracle_bot = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "subscriptions.bot.aws.ixo.earth"
      }
      ixo_pathgen_oracle = {
        enabled = false
        domain = "ixoearth"
        dns_prefix = "pathgen.oracle"
      }
      ixo_jokes_oracle = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "jokes.oracle.aws.ixo.earth"
      }
      ixo_observable_framework_builder = {
        enabled = false
        domain = "ixoearth"
      }
    }
  }
}

# Additional manual synthetic monitoring endpoints
additional_manual_synthetic_monitoring_endpoints = {
  aws = [
    "https://signx.aws.ixo.earth",
    "https://aws.ixo.earth/rpc/",
    "https://aws.api.emerging.eco/emerging-platform/v1/hello",
    "https://awsmx.ixo.earth/health"
  ]
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
    },
    { // 14
      username = "subscriptions-oracle-bot"
      databases = ["subscriptions-oracle-bot"]
    },
    { // 15
      username = "observable-framework-builder"
      databases = ["observable-framework-builder"]
    },
    { // 16
      username = "pathgen-oracle"
      databases = ["pathgen-oracle"]
    }
  ]
  pg_version             = 15
  pgbackrest_image       = "registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest"
  pgbackrest_image_tag   = "ubi8-2.47-2"
  pgmonitoring_image     = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres-exporter"
  pgmonitoring_image_tag = "ubi8-5.5.0-0"
}

additional_prometheus_scrape_metrics = {
  aws = <<EOT
# Add AWS-specific monitoring targets here when needed
EOT
} 