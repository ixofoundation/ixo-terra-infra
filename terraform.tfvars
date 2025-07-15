# Domain mappings
# Define the actual domains for each domain identifier used in application configs.
# If you're customizing this for your own deployment, ensure all domain keys 
# referenced in the application_configs below are defined here.
domains = {
  ixoworld = "ixo.world"     # Used for mainnet production services
  ixoearth = "ixo.earth"     # Used for development and community services  
  emerging = "emerging.eco"   # Used for emerging ecosystem services
}

# Organization name - used for resource naming and identification
org = "ixofoundation"
cloud_provider = "vultr"

# Storage classes
storage_classes = {
  "standard" = "vultr-block-storage" # Standard storage (SSD)
  "fast" = "vultr-block-storage" # Fast storage (SSD)
  "bulk" = "vultr-block-storage-hdd" # Slower, Cheaper, Bulk storage (HDD)
  "shared" = null # Currently not used
}

# Repository configuration
ixo_helm_chart_repository = "https://github.com/ixofoundation/ixo-helm-charts"
ixo_terra_infra_repository = "https://github.com/ixofoundation/ixo-terra-infra"
vault_core_mount = "ixo_core"

# Versioning for all services.
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
  ghost                        = "23.0.19" # https://artifacthub.io/packages/helm/bitnami/ghost
  neo4j                        = "2025.6.0" # https://artifacthub.io/packages/helm/neo4j-helm-charts/neo4j
}

# Environment base configurations (static values only)
environments = {
  devnet = {
    cluster_firewall = true
    aws_region      = "eu-north-1"
    aws_iam_users   = []
    rpc_url         = "https://devnet.ixo.earth/rpc/"
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
        enabled = true # For initial setups, cert-manager must be disabled.
        domain = "ixoearth"
      }
      ingress_nginx = {
        enabled = true
        domain = "ixoearth"
      }
      postgres_operator_crunchydata = {
        enabled = true
        domain = "ixoearth"
      }
      prometheus_stack = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "devnetkb.ixo.earth"  # Main monitoring/grafana host
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
        enabled = true
        domain = "ixoearth"
      }
      prometheus_blackbox_exporter = {
        enabled = true
        domain = "ixoearth"
      }
      tailscale = {
        enabled = true
        domain = "ixoearth"
      }
      matrix = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "devmx.ixo.earth"
      }
      matrix_admin = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "admin.devmx.ixo.earth"
      }
      nfs_provisioner = {
        enabled = true
        domain = "ixoearth"
      }
      metrics_server = {
        enabled = true
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
        enabled = true
        domain = "ixoearth"
      }
      uptime_kuma = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "status.devnet.ixo.earth"
      }
      chromadb = {
        enabled = true
        domain = "ixoearth"
      }
      ghost = {
        enabled = false
        domain = "ixoearth"
      }
      neo4j = {
        enabled = true
        domain = "ixoearth"
      }
      # IXO Services
      ixo_cellnode = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "devnet-cellnode.ixo.earth"
      }
      ixo_blocksync = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "devnet-blocksync-graphql.ixo.earth"
      }
      ixo_blocksync_core = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "ixo-blocksync-core.devnetkb.ixo.earth"
      }
      ixo_feegrant_nest = {
        enabled = true
        domain = "ixoearth"
        dns_prefix = "feegrant"
      }
      ixo_did_resolver = {
        enabled = true
        domain = "ixoearth"
        dns_prefix = "resolver"
      }
      ixo_faucet = {
        enabled = true
        domain = "ixoearth"
        dns_prefix = "faucet"
      }
      ixo_matrix_state_bot = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "state.bot.devmx.ixo.earth"
        storage_class = "bulk"
        storage_size = "40Gi"
      }
      ixo_matrix_appservice_rooms = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "rooms.bot.devmx.ixo.earth"
        storage_class = "bulk"
        storage_size = "40Gi"
      }
      claims_credentials_ecs = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "ecs.credentials.devnet.ixo.earth"
      }
      claims_credentials_prospect = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "prospect.credentials.devnet.ixo.earth"
      }
      claims_credentials_carbon = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "carbon.credentials.devnet.ixo.earth"
      }
      claims_credentials_umuzi = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "umuzi.credentials.devnet.ixo.earth"
      }
      claims_credentials_claimformprotocol = {
        enabled = false
        domain = "ixoearth"
      }
      claims_credentials_did = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "didoracle.credentials.devnet.ixo.earth"
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
        dns_endpoint = "giza.devnet.ixo.earth"
      }
      ixo_payments_nest = {
        enabled = false
        domain = "ixoearth"
      }
      ixo_message_relayer = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "signx.devnet.ixo.earth"
      }
      ixo_cvms_exporter = {
        enabled = false
        domain = "ixoearth"
      }
      ixo_registry_server = {
        enabled = true
        domain = "ixoearth" # Domain 1 
        dns_endpoint = "dev.api.emerging.eco" # Domain 2
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
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "bid.bot.devmx.ixo.earth"
        storage_class = "bulk"
        storage_size = "40Gi"
      }
      ixo_matrix_claims_bot = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "claim.bot.devmx.ixo.earth"
        storage_class = "bulk"
        storage_size = "40Gi"
      }
      ixo_subscriptions_oracle = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "subscriptions.oracle.devnet.ixo.earth"
      }
      ixo_subscriptions_oracle_bot = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "subscriptions.bot.devnet.ixo.earth"
      }
      ixo_pathgen_oracle = {
        enabled = true
        domain = "ixoearth"
        dns_prefix = "pathgen.oracle"
      }
      ixo_jokes_oracle = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "jokes.oracle.devnet.ixo.earth"
      }
      ixo_observable_framework_builder = {
        enabled = false
        domain = "ixoearth"
        storage_class = "fast"
        storage_size = "40Gi"
      }
      ixo_memory_engine = {
        enabled = true
        domain = "ixoearth"
        dns_prefix = "memory-engine"
      }
      ixo_companion = {
        enabled = true
        domain = "ixoearth"
        dns_prefix = "companion"
      }
    }
  }
  testnet = {
    cluster_firewall = true
    aws_region      = "eu-north-1"
    aws_iam_users   = []
    rpc_url         = "https://testnet.ixo.earth/rpc/"
    ipfs_service_mapping = "https://ipfs.gateway.ixo.world"
    hyperlane = {
      chain_names     = ["relayer", "pandora8", "basesepolia"]
      metadata_chains = ["relayer", "pandora8", "basesepolia"]
    }
    aws_vpc_config = {
      nat_gateway_enabled = true
      flow_logs_enabled = true
      retention_days = 14
      az_count = 2
    }
    application_configs = {
      # Core Infrastructure Services
      cert_manager = {
        enabled = true
        domain = "ixoearth"
      }
      ingress_nginx = {
        enabled = true
        domain = "ixoearth"
      }
      postgres_operator_crunchydata = {
        enabled = true
        domain = "ixoearth"
      }
      prometheus_stack = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "testnetkb.ixo.earth"  # Main monitoring/grafana host
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
        enabled = true
        domain = "ixoearth"
      }
      prometheus_blackbox_exporter = {
        enabled = true
        domain = "ixoearth"
      }
      tailscale = {
        enabled = true
        domain = "ixoearth"
      }
      matrix = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "testmx.ixo.earth"
      }
      matrix_admin = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "admin.testmx.ixo.earth"
      }
      nfs_provisioner = {
        enabled = true
        domain = "ixoearth"
      }
      metrics_server = {
        enabled = true
        domain = "ixoearth"
      }
      hermes = {
        enabled = false
        domain = "ixoearth"
      }
      hyperlane_validator = {
        enabled = true
        domain = "ixoearth"
      }
      aws_vpc = {
        enabled = false
        domain = "ixoearth"
      }
      uptime_kuma = {
        enabled = false
        domain = "ixoearth"
      }
      chromadb = {
        enabled = false
        domain = "ixoearth"
      }
      ghost = {
        enabled = false
        domain = "ixoearth"
      }
      neo4j = {
        enabled = false
        domain = "ixoearth"
      }
      # IXO Services
      ixo_cellnode = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "testnet-cellnode.ixo.earth"
      }
      ixo_blocksync = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "testnet-blocksync-graphql.ixo.earth"
      }
      ixo_blocksync_core = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "ixo-blocksync-core.testnetkb.ixo.earth"
      }
      ixo_feegrant_nest = {
        enabled = true
        domain = "ixoearth"
        dns_prefix = "feegrant"
      }
      ixo_did_resolver = {
        enabled = true
        domain = "ixoearth"
        dns_prefix = "resolver"
      }
      ixo_faucet = {
        enabled = true
        domain = "ixoearth"
        dns_prefix = "faucet"
      }
      ixo_matrix_state_bot = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "state.bot.testmx.ixo.earth"
        storage_class = "bulk"
        storage_size = "40Gi"
      }
      ixo_matrix_appservice_rooms = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "rooms.bot.testmx.ixo.earth"
        storage_class = "bulk"
        storage_size = "40Gi"
      }
      claims_credentials_ecs = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "ecs.credentials.testnet.ixo.earth"
      }
      claims_credentials_prospect = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "prospect.credentials.testnet.ixo.earth"
      }
      claims_credentials_carbon = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "carbon.credentials.testnet.ixo.earth"
      }
      claims_credentials_umuzi = {
        enabled = false
        domain = "ixoearth"
      }
      claims_credentials_claimformprotocol = {
        enabled = false
        domain = "ixoearth"
      }
      claims_credentials_did = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "didoracle.credentials.testnet.ixo.earth"
      }
      ixo_deeplink_server = {
        enabled = false
        domain = "ixoearth"
        dns_prefix = "deeplink"
      }
      ixo_kyc_server = {
        enabled = true
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
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "offset.auto-approve.testnet.ixo.earth"
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
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "gizatest.ixo.earth"
      }
      ixo_payments_nest = {
        enabled = true
        domain = "emerging"
        dns_endpoint = "payments.testnet.emerging.eco"
      }
      ixo_message_relayer = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "signx.testnet.ixo.earth"
      }
      ixo_cvms_exporter = {
        enabled = false
        domain = "ixoearth"
      }
      ixo_registry_server = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "stage.api.emerging.eco"
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
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "bid.bot.testmx.ixo.earth"
        storage_class = "bulk"
        storage_size = "40Gi"
      }
      ixo_matrix_claims_bot = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "claim.bot.testmx.ixo.earth"
        storage_class = "bulk"
        storage_size = "40Gi"
      }
      ixo_subscriptions_oracle = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "subscriptions.oracle.testnet.ixo.earth"
      }
      ixo_subscriptions_oracle_bot = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "subscriptions.bot.testnet.ixo.earth"
      }
      ixo_pathgen_oracle = {
        enabled = false
        domain = "ixoearth"
        dns_prefix = "pathgen.oracle"
      }
      ixo_jokes_oracle = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "jokes.oracle.testnet.ixo.earth"
      }
      ixo_observable_framework_builder = {
        enabled = false
        domain = "ixoearth"
        storage_class = "fast"
        storage_size = "40Gi"
      }
      ixo_memory_engine = {
        enabled = false
        domain = "ixoearth"
        dns_prefix = "memory-engine"
      }
      ixo_companion = {
        enabled = false
        domain = "ixoearth"
        dns_prefix = "companion"
      }
    }
  }
  mainnet = {
    cluster_firewall = true
    aws_region      = "eu-north-1"
    aws_iam_users   = ["peterbulovec", "alwynvanwyk"]
    rpc_url         = "https://impacthub.ixo.world/rpc/"
    ipfs_service_mapping = "https://ipfs.gateway.ixo.world"
    hyperlane = {
      chain_names     = ["ixo5", "base", "relayer"]
      metadata_chains = ["ixo5", "base", "relayer"]
    }
    aws_vpc_config = {
      nat_gateway_enabled = true
      flow_logs_enabled = true
      retention_days = 30
      az_count = 3
    }
    aws_eks_config = {
      node_instance_types = ["t3.medium"]
      desired_capacity = 2
      min_capacity = 1
      max_capacity = 4
      disk_size = 50
    }
    application_configs = {
      # Core Infrastructure Services
      cert_manager = {
        enabled = true
        domain = "ixoworld"
      }
      ingress_nginx = {
        enabled = true
        domain = "ixoworld"
      }
      postgres_operator_crunchydata = {
        enabled = true
        domain = "ixoworld"
      }
      prometheus_stack = {
        enabled = true
        domain = "ixoworld"
        dns_endpoint = "mainnetkb.ixo.earth"  # Main monitoring/grafana host
      }
      external_dns = {
        enabled = true
        domain = "ixoworld"
      }
      dex = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "dex.mainnet.ixo.earth"
      }
      vault = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "vault.mainnet.ixo.earth"
      }
      loki = {
        enabled = true
        domain = "ixoworld"
      }
      prometheus_blackbox_exporter = {
        enabled = true
        domain = "ixoworld"
      }
      tailscale = {
        enabled = true
        domain = "ixoworld"
      }
      matrix = {
        enabled = true
        domain = "ixoworld"
        dns_endpoint = "mx.ixo.earth"
      }
      matrix_admin = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "admin.mx.ixo.earth"
      }
      nfs_provisioner = {
        enabled = true
        domain = "ixoworld"
      }
      metrics_server = {
        enabled = true
        domain = "ixoworld"
      }
      hermes = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "hermes.ixo.earth"
      }
      hyperlane_validator = {
        enabled = true
        domain = "ixoworld"
      }
      aws_vpc = {
        enabled = false
        domain = "ixoworld"
      }
      uptime_kuma = {
        enabled = true
        domain = "ixoworld"
        dns_endpoint = "status.mainnet.ixo.world"
      }
      chromadb = {
        enabled = false
        domain = "ixoworld"
      }
      ghost = {
        enabled = true
        domain = "ixoworld"
        dns_prefix = "ghost"
      }
      neo4j = {
        enabled = false
        domain = "ixoearth"
      }
      # IXO Services
      ixo_cellnode = {
        enabled = true
        domain = "ixoworld"
        dns_endpoint = "cellnode.ixo.world"
      }
      ixo_blocksync = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "blocksync-graphql.ixo.earth"
      }
      ixo_blocksync_core = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "ixo-blocksync-core.mainnetkb.ixo.earth"
      }
      ixo_feegrant_nest = {
        enabled = true
        domain = "ixoworld"
        dns_prefix = "feegrant"
      }
      ixo_did_resolver = {
        enabled = true
        domain = "ixoworld"
        dns_prefix = "resolver"
      }
      ixo_faucet = {
        enabled = false
        domain = "ixoworld"
        dns_endpoint = "faucet2.mainnetkb.ixo.earth"
      }
      ixo_matrix_state_bot = {
        enabled = true
        domain = "ixoworld"
        dns_endpoint = "state.bot.mx.ixo.earth"
        storage_class = "bulk"
        storage_size = "40Gi"
      }
      ixo_matrix_appservice_rooms = {
        enabled = true
        domain = "ixoworld"
        dns_endpoint = "rooms.bot.mx.ixo.earth"
        storage_class = "bulk"
        storage_size = "40Gi"
      }
      claims_credentials_ecs = {
        enabled = true
        domain = "ixoworld"
        dns_endpoint = "ecs.credentials.ixo.world"
      }
      claims_credentials_prospect = {
        enabled = false
        domain = "ixoworld"
        dns_endpoint = "prospect.credentials2.mainnet.ixo.world"
      }
      claims_credentials_carbon = {
        enabled = true
        domain = "ixoworld"
        dns_endpoint = "carbon.credentials.ixo.world"
      }
      claims_credentials_umuzi = {
        enabled = false
        domain = "ixoworld"
        dns_endpoint = "umuzi.credentials2.mainnet.ixo.world"
      }
      claims_credentials_claimformprotocol = {
        enabled = true
        domain = "ixoworld"
        dns_endpoint = "claimformobjects.credentials.ixo.world"
      }
      claims_credentials_did = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "didoracle.credentials.ixo.earth"
      }
      ixo_deeplink_server = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "x.ixo.earth"
      }
      ixo_kyc_server = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "kyc.oracle.ixo.earth"
      }
      ixo_faq_assistant = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "faq.assistant.ixo.earth"
      }
      ixo_coin_server = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "coincache.ixo.earth"
      }
      ixo_stake_reward_claimer = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "reclaim.ixo.earth"
      }
      ixo_ussd = {
        enabled = false
        domain = "ixoearth"
      }
      ixo_whizz = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "whizz.assistant.ixo.earth"
      }
      auto_approve_offset = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "offset.auto-approve.ixo.earth"
      }
      ixo_iot_data = {
        enabled = true
        domain = "ixoearth"
        dns_prefix = "iot-data"
      }
      ixo_notification_server = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "notifications.ixo.earth"
      }
      ixo_guru = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "guru.ixo.earth"
      }
      ixo_trading_bot_server = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "trading.bot.ixo.earth"
      }
      ixo_ai_oracles_guru = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "guru2.ixo.earth"
      }
      ixo_ai_oracles_giza = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "giza.ixo.earth"
      }
      ixo_payments_nest = {
        enabled = true
        domain = "emerging"
        dns_endpoint = "payments.emerging.eco"
      }
      ixo_message_relayer = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "signx.ixo.earth"
      }
      ixo_cvms_exporter = {
        enabled = true
        domain = "ixoearth"
      }
      ixo_registry_server = {
        enabled = true
        domain = "ixoearth"
        dns_endpoint = "api.emerging.eco"
      }
      ixo_agent_images_slack = {
        enabled = true
        domain = "ixoearth"
      }
      ixo_aws_iam = {
        enabled = true
        domain = "ixoearth"
      }
      ixo_matrix_bids_bot = {
        enabled = true
        domain = "ixoworld"
        dns_endpoint = "bid.bot.mx.ixo.earth"
        storage_class = "bulk"
        storage_size = "40Gi"
      }
      ixo_matrix_claims_bot = {
        enabled = true
        domain = "ixoworld"
        dns_endpoint = "claim.bot.mx.ixo.earth"
        storage_class = "bulk"
        storage_size = "40Gi"
      }
      ixo_subscriptions_oracle = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "subscriptions.oracle.ixo.earth"
      }
      ixo_subscriptions_oracle_bot = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "subscriptions.bot.ixo.earth"
      }
      ixo_pathgen_oracle = {
        enabled = false
        domain = "ixoearth"
        dns_prefix = "pathgen.oracle"
      }
      ixo_jokes_oracle = {
        enabled = false
        domain = "ixoearth"
        dns_endpoint = "jokes.oracle.ixo.earth"
      }
      ixo_observable_framework_builder = {
        enabled = true
        domain = "ixoearth"
        dns_prefix = "builder.observable"
        storage_class = "fast"
        storage_size = "40Gi"
      }
      ixo_memory_engine = {
        enabled = false
        domain = "ixoearth"
        dns_prefix = "memory-engine"
      }
      ixo_companion = {
        enabled = false
        domain = "ixoearth"
        dns_prefix = "companion"
      }
    }
  }
}

# Additional manual synthetic monitoring endpoints
additional_manual_synthetic_monitoring_endpoints = {
  devnet = [
    "https://signx.devnet.ixo.earth",
    "https://devnet.ixo.earth/rpc/",
    "https://dev.api.emerging.eco/emerging-platform/v1/hello",
    "https://devmx.ixo.earth/health",
    "https://archive.devnet.ixo.earth/rpc/"
  ]
  testnet = [
    "https://payments.testnet.emerging.eco",
    "https://blockscan-pandora.ixo.earth",
    "https://signx.testnet.ixo.earth",
    "https://testnet.ixo.earth/rpc/",
    "https://stage.api.emerging.eco/emerging-platform/v1/hello",
    "https://testmx.ixo.earth/health",
    "https://archive.testnet.ixo.earth/rpc/"
  ]
  mainnet = [
    "https://coincache.ixo.earth",
    "https://trading.bot.ixo.earth/api/",
    "https://hermes.ixo.earth/version",
    "https://reclaim.ixo.earth",
    "https://signx.ixo.earth",
    "https://ixo.rpc.m.stavr.tech",
    "https://impacthub.ixo.world/rpc/",
    "https://api.emerging.eco/emerging-platform/v1/hello",
    "https://mx.ixo.earth/health",
    "https://ipfs.gateway.ixo.world/health",
    "https://archive.impacthub.ixo.earth/rpc/"
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
    },
    { // 17
      username = "jokes-oracle"
      databases = ["jokes-oracle"]
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