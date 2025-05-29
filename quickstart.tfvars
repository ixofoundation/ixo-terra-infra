# Quickstart Configuration Template
# This file is designed for users who want to deploy their own IXO infrastructure
# Required fields are marked with "Required" in their comments

# ============== Required Configuration ==============
# Vultr API Key - Required for cluster creation and management
# Get this from your Vultr account dashboard
vultr_api_key = "" # Required: Your Vultr API Key

# Cloudflare Configuration - Required if using Cloudflare for DNS
# Get this from your Cloudflare account dashboard
cloudflare_api_token = "" # Optional: Your Cloudflare API Token

# ============== Domain Configuration ==============
# Domain mappings - Define the actual domains for each domain identifier
# If you're customizing this for your own deployment, ensure all domain keys 
# referenced in the application_configs below are defined here.
domains = {
  primary   = "my-ixo.com"      # Replace with your primary domain
  secondary = "my-ixo.org"      # Replace with your secondary domain (optional)
}

# Organization name - Required for resource naming and identification
# This will be used as a prefix for your resources
org = "" # Required: Your organization name (e.g., "my-org")

# Repository configuration - Update these if you have your own helm charts or infrastructure repo
ixo_helm_chart_repository = "https://github.com/ixofoundation/ixo-helm-charts"
ixo_terra_infra_repository = "https://github.com/ixofoundation/ixo-terra-infra"  
vault_core_mount = "ixo_core"

# ============== Monitoring Configuration ==============
# Add endpoints you want to monitor with Blackbox Exporter
additional_manual_synthetic_monitoring_endpoints = {
  quickstart = [
    # Add your endpoints to monitor (examples):
    # "https://my-service.com/health",
    # "https://my-api.com/status"
  ]
}

# ============== OIDC Configuration ==============
# OIDC Configuration - Required if you want to use OIDC authentication
# These values are typically provided by your OIDC provider (e.g., Google, GitHub, etc.)
oidc_argo = {
  clientId     = "" # Optional: OIDC client ID for ArgoCD
  clientSecret = "" # Optional: OIDC client secret for ArgoCD
}

oidc_vault = {
  clientId     = "" # Optional: OIDC client ID for Vault
  clientSecret = "" # Optional: OIDC client secret for Vault
}

oidc_tailscale = {
  clientId     = "" # Optional: OIDC client ID for Tailscale
  clientSecret = "" # Optional: OIDC client secret for Tailscale
}

# ============== Environment Configuration ==============
environments = {
  quickstart = {
    # Cluster Security
    cluster_firewall = false # Enable Vultr cluster firewall (recommended for production)
    aws_region      = "eu-north-1" # AWS region for any AWS resources
    aws_iam_users   = [] # List of AWS IAM users to create

    # Network Configuration
    rpc_url              = "https://devnet.ixo.earth/rpc/" # RPC endpoint for blockchain interaction
    ipfs_service_mapping = "https://ipfs.gateway.ixo.world" # IPFS gateway endpoint

    # Hyperlane Configuration (for cross-chain messaging)
    hyperlane = {
      chain_names     = [""]
      metadata_chains = [""]
    }

    # Application Configuration
    # Configure each service with enabled status, domain, and DNS settings
    # DNS Options:
    #   - dns_prefix: For standard pattern <prefix>.<environment>.<domain> (e.g., "api" -> "api.quickstart.my-ixo.com")
    #   - dns_endpoint: For custom DNS patterns (e.g., "custom.subdomain.my-ixo.com")
    application_configs = {
      # ============== Core Infrastructure Services ==============
      cert_manager = {
        enabled = false # SSL certificate management
        domain = "primary"
      }
      ingress_nginx = {
        enabled = false # External access and load balancing  
        domain = "primary"
      }
      postgres_operator_crunchydata = {
        enabled = false # PostgreSQL database management
        domain = "primary"
      }
      prometheus_stack = {
        enabled = false # Monitoring and alerting
        domain = "primary"
        dns_endpoint = "monitoring.my-ixo.com" # Custom monitoring URL
      }
      external_dns = {
        enabled = false # DNS management
        domain = "primary"
      }
      dex = {
        enabled = false # OIDC authentication
        domain = "primary"
        dns_prefix = "auth"
      }
      vault = {
        enabled = true # Secret management (recommended)
        domain = "primary"
        dns_prefix = "vault"
      }
      loki = {
        enabled = false # Log aggregation
        domain = "primary"
      }
      prometheus_blackbox_exporter = {
        enabled = false # Endpoint monitoring
        domain = "primary"
      }
      tailscale = {
        enabled = false # VPN access
        domain = "primary"
      }
      matrix = {
        enabled = false # Matrix server
        domain = "primary"
        dns_endpoint = "chat.my-ixo.com"
      }
      nfs_provisioner = {
        enabled = false # Shared storage
        domain = "primary"
      }
      metrics_server = {
        enabled = false # Kubernetes metrics
        domain = "primary"
      }
      hermes = {
        enabled = false # IBC relayer
        domain = "primary"
        dns_prefix = "relayer"
      }
      hyperlane_validator = {
        enabled = false # Hyperlane validator
        domain = "primary"
      }
      aws_vpc = {
        enabled = false # AWS VPC resources
        domain = "primary"
      }
      uptime_kuma = {
        enabled = false # Uptime monitoring
        domain = "primary"
        dns_prefix = "status"
      }
      chromadb = {
        enabled = false # Vector database
        domain = "primary"
      }

      # ============== IXO Core Services ==============
      ixo_cellnode = {
        enabled = false # Core cellnode service
        domain = "primary"
        dns_prefix = "cellnode"
      }
      ixo_blocksync = {
        enabled = false # Block synchronization
        domain = "primary"
        dns_endpoint = "blocksync-graphql.my-ixo.com"
      }
      ixo_blocksync_core = {
        enabled = false # Core block synchronization
        domain = "primary"
        dns_endpoint = "blocksync-core.my-ixo.com"
      }
      ixo_feegrant_nest = {
        enabled = false # Fee grant service
        domain = "primary"
        dns_prefix = "feegrant"
      }
      ixo_did_resolver = {
        enabled = false # DID resolution service
        domain = "primary"
        dns_prefix = "resolver"
      }
      ixo_faucet = {
        enabled = false # Token faucet
        domain = "primary"
        dns_prefix = "faucet"
      }

      # ============== IXO Extended Services ==============
      ixo_matrix_state_bot = {
        enabled = false # Matrix state bot
        domain = "primary"
        dns_endpoint = "state.bot.chat.my-ixo.com"
      }
      ixo_matrix_appservice_rooms = {
        enabled = false # Matrix room management
        domain = "primary"
        dns_endpoint = "rooms.bot.chat.my-ixo.com"
      }
      claims_credentials_ecs = {
        enabled = false # ECS credentials
        domain = "primary"
        dns_endpoint = "ecs.credentials.my-ixo.com"
      }
      claims_credentials_prospect = {
        enabled = false # Prospect credentials
        domain = "primary"
        dns_endpoint = "prospect.credentials.my-ixo.com"
      }
      claims_credentials_carbon = {
        enabled = false # Carbon credentials
        domain = "primary"
        dns_endpoint = "carbon.credentials.my-ixo.com"
      }
      claims_credentials_umuzi = {
        enabled = false # Umuzi credentials
        domain = "primary"
        dns_endpoint = "umuzi.credentials.my-ixo.com"
      }
      claims_credentials_claimformprotocol = {
        enabled = false # Claim form protocol
        domain = "primary"
        dns_endpoint = "claimform.credentials.my-ixo.com"
      }
      claims_credentials_did = {
        enabled = false # DID credentials
        domain = "primary"
        dns_endpoint = "did.credentials.my-ixo.com"
      }
      ixo_deeplink_server = {
        enabled = false # Deeplink service
        domain = "primary"
        dns_prefix = "deeplink"
      }
      ixo_kyc_server = {
        enabled = false # KYC service
        domain = "primary"
        dns_prefix = "kyc"
      }
      ixo_faq_assistant = {
        enabled = false # FAQ assistant
        domain = "primary"
        dns_endpoint = "faq.assistant.my-ixo.com"
      }
      ixo_coin_server = {
        enabled = false # Coin server
        domain = "primary"
        dns_endpoint = "coins.my-ixo.com"
      }
      ixo_stake_reward_claimer = {
        enabled = false # Stake reward service
        domain = "primary"
        dns_endpoint = "rewards.my-ixo.com"
      }
      ixo_ussd = {
        enabled = false # USSD service
        domain = "primary"
      }
      ixo_whizz = {
        enabled = false # Whizz service
        domain = "primary"
        dns_endpoint = "whizz.assistant.my-ixo.com"
      }
      auto_approve_offset = {
        enabled = false # Auto approve offset
        domain = "primary"
        dns_endpoint = "offset.auto-approve.my-ixo.com"
      }
      ixo_iot_data = {
        enabled = false # IoT data service
        domain = "primary"
        dns_prefix = "iot-data"
      }
      ixo_notification_server = {
        enabled = false # Notification server
        domain = "primary"
        dns_prefix = "notifications"
      }
      ixo_guru = {
        enabled = false # Guru service
        domain = "primary"
        dns_prefix = "guru"
      }
      ixo_trading_bot_server = {
        enabled = false # Trading bot
        domain = "primary"
        dns_endpoint = "trading.bot.my-ixo.com"
      }
      ixo_ai_oracles_guru = {
        enabled = false # AI oracles guru
        domain = "primary"
        dns_prefix = "guru2"
      }
      ixo_ai_oracles_giza = {
        enabled = false # AI oracles giza
        domain = "primary"
        dns_prefix = "giza"
      }
      ixo_payments_nest = {
        enabled = false # Payments service
        domain = "primary"
        dns_prefix = "payments"
      }
      ixo_message_relayer = {
        enabled = false # Message relayer
        domain = "primary"
        dns_prefix = "signx"
      }
      ixo_cvms_exporter = {
        enabled = false # CVMS exporter
        domain = "primary"
      }
      ixo_registry_server = {
        enabled = false # Registry server
        domain = "primary"
        dns_endpoint = "api.my-ixo.com"
      }
      ixo_agent_images_slack = {
        enabled = false # Agent images slack
        domain = "primary"
      }
      ixo_aws_iam = {
        enabled = false # AWS IAM management
        domain = "primary"
      }
      ixo_matrix_bids_bot = {
        enabled = false # Matrix bids bot
        domain = "primary"
        dns_endpoint = "bid.bot.chat.my-ixo.com"
      }
      ixo_matrix_claims_bot = {
        enabled = false # Matrix claims bot
        domain = "primary"
        dns_endpoint = "claim.bot.chat.my-ixo.com"
      }
      ixo_subscriptions_oracle = {
        enabled = false # Subscriptions oracle
        domain = "primary"
        dns_endpoint = "subscriptions.oracle.my-ixo.com"
      }
      ixo_subscriptions_oracle_bot = {
        enabled = false # Subscriptions oracle bot
        domain = "primary"
        dns_endpoint = "subscriptions.bot.my-ixo.com"
      }
      ixo_jokes_oracle = {
        enabled = false # Jokes oracle
        domain = "primary"
        dns_endpoint = "jokes.oracle.my-ixo.com"
      }
      ixo_observable_framework_builder = {
        enabled = false # Observable framework builder
        domain = "primary"
        dns_prefix = "builder.observable"
      }
    }
  }
}

# ============== Database Configuration ==============
# PostgreSQL configuration for Matrix services
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

# PostgreSQL configuration for IXO services
# Note: For existing databases, you may need to run SQL scripts in config/sql/ixo-init.sql
# if there are DB permission issues on startup for an IXO service.
pg_ixo = {
  pg_cluster_name = "ixo-postgres"
  pg_image        = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres"
  pg_image_tag    = "ubi8-15.5-0"
  pg_users = [
    { # Admin user - Required
      username  = "admin"
      databases = ["postgres"]
      options   = "SUPERUSER"
    },
    { # Cellnode user - Required if ixo_cellnode is enabled
      username  = "cellnode"
      databases = ["cellnode"]
    },
    { # Blocksync users - Required if ixo_blocksync or ixo_blocksync_core are enabled
      username  = "blocksync-core"
      databases = ["blocksync-core"]
    },
    {
      username  = "blocksync"
      databases = ["blocksync", "blocksync_alt"]
    },
    { # Additional users for other services - add as needed
      username  = "deeplink"
      databases = ["deeplink"]
    },
    {
      username  = "kyc"
      databases = ["kyc"]
    }
  ]
  pg_version             = 15
  pgbackrest_image       = "registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest"
  pgbackrest_image_tag   = "ubi8-2.47-2"
  pgmonitoring_image     = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres-exporter"
  pgmonitoring_image_tag = "ubi8-5.5.0-0"
}

# ============== Prometheus Scrape Configuration ==============
additional_prometheus_scrape_metrics = {
  quickstart = null # Add custom Prometheus scrape configs here if needed
}

# ============== Service Versions ==============
# Version numbers for all services
# These are stable, tested versions suitable for production use
versions = {
  kubernetes_cluster           = "v1.32.2+1"
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
}