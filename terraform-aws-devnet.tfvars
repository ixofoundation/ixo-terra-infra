domains = {
  ixoworld        = "ixo.world"
  ixoearth        = "ixo.earth"
  emerging        = "emerging.eco"
  impacts_network = "impacts.network"
}

org            = "ixofoundation"
cloud_provider = "aws"

storage_classes = {
  "standard" = "gp3"
  "fast"     = "gp3-fast"
  "bulk"     = "gp3"
  "shared"   = "efs"
}

ixo_helm_chart_repository  = "https://github.com/ixofoundation/ixo-helm-charts"
ixo_terra_infra_repository = "https://github.com/ixofoundation/ixo-terra-infra"
vault_core_mount            = "ixo_core"

versions = {
  kubernetes_cluster           = "1.36"
  argocd                       = "9.5.0"
  cert-manager                 = "1.20.2"
  nginx-ingress-controller     = "2.4.4"
  postgres-operator            = "6.0.1"
  prometheus-stack             = "83.4.3"
  external-dns                 = "1.20.0"
  vault                        = "0.32.0"
  loki                         = "6.55.0"
  prometheus-blackbox-exporter = "11.9.1"
  dex                          = "0.24.0"
  tailscale                    = "1.96.5"
  matrix                       = "3.12.28"
  openebs                      = "4.4.0"
  metrics-server               = "3.13.0"
  descheduler                  = "0.35.1"
  hummingbot                   = "0.2.0"
  uptime-kuma                  = "4.0.0"
  chromadb                     = "0.2.2"
  ghost                        = "25.0.4"
  neo4j                        = "2026.3.1"
  falco_security               = "8.0.2"
  redis                        = "25.3.11"
  surrealdb                    = "0.4.0"
  searxng                      = "1.0.1"
}

environments = {
  devnet_aws = {
    cluster_firewall     = true
    is_development       = true
    aws_region           = "eu-north-1"
    aws_iam_users        = []
    rpc_url              = "https://devnet.ixo.earth/rpc/"
    ipfs_service_mapping = "https://ipfs.gateway.ixo.world"
    hyperlane = {
      chain_names     = [""]
      metadata_chains = [""]
    }
    aws_vpc_config = {
      nat_gateway_enabled = false
      flow_logs_enabled   = false
      retention_days      = 7
      az_count            = 2
    }
    aws_eks_config = {
      node_instance_types = ["t3.medium"]
      desired_capacity    = 3
      min_capacity        = 1
      max_capacity        = 5
      disk_size           = 50
    }
    application_configs = {
      # Core Infrastructure
      cert_manager = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
      }
      ingress_nginx = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
      }
      surrealdb = {
        enabled       = true
        create_kv     = false
        domain        = "ixoearth"
        storage_class = "fast"
        storage_size  = "40Gi"
      }
      postgres_operator_crunchydata = {
        enabled      = true
        create_kv    = false
        domain       = "ixoearth"
        storage_size = "210Gi"
      }
      prometheus_stack = {
        enabled      = true
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "devnetaws.ixo.earth"
      }
      external_dns = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
      }
      dex = {
        enabled    = true
        create_kv  = false
        domain     = "ixoearth"
        dns_prefix = "dexaws"
      }
      vault = {
        enabled    = true
        create_kv  = false
        domain     = "ixoearth"
        dns_prefix = "vaultaws"
      }
      vault_argocd_watcher = {
        enabled    = false
        create_kv  = false
        domain     = "ixoearth"
        dns_prefix = "vaultaws-watcher"
      }
      loki = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      prometheus_blackbox_exporter = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
      }
      # The following stub entries exist only so var.environments["devnet_aws"].application_configs[<key>]
      # resolves (modules_core.tf/modules.tf index these keys unconditionally for every workspace).
      # All are disabled until deliberately migrated to AWS. When enabling one that has a dns_endpoint
      # in the main devnet block, rename it here first (e.g. add an "-aws" suffix) to avoid colliding
      # with the hostname devnet (Vultr) already serves — dns_prefix-based entries are safe as-is since
      # they auto-namespace by terraform.workspace.
      argocd_image_updater = {
        enabled   = false
        create_kv = false
      }
      external_secrets = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      reloader = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      vpa = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      ixo_blocksync_api = {
        enabled   = false
        create_kv = false
        use_eso   = true
        domain    = "ixoearth"
      }
      ixo_diagnostic_oracle = {
        enabled       = false
        create_kv     = true
        use_eso       = true
        domain        = "ixoearth"
        dns_prefix    = "diagnostic"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      ixo_supamoto_3cx_server = {
        enabled       = false
        create_kv     = true
        use_eso       = true
        domain        = "ixoearth"
        dns_prefix    = "3cx"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      ixo_xero_oracle = {
        enabled       = false
        create_kv     = true
        use_eso       = true
        domain        = "ixoearth"
        dns_prefix    = "xero"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      ixo_yoma_agent_oracle = {
        enabled       = false
        create_kv     = true
        use_eso       = true
        domain        = "ixoearth"
        dns_prefix    = "yoma-agent"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      digihub_matrix_state_bot = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      digihub_matrix_appservice_rooms = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      digihub_matrix_bids_bot = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      digihub_ixo_matrix_claims_bot = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      supamoto_ixo_matrix_claims_bot = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      tailscale = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      matrix = {
        enabled      = false
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "devmx.ixo.earth"
      }
      matrix_admin = {
        enabled      = false
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "admin.devmx.ixo.earth"
      }
      matrix_livekit = {
        enabled      = false
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "livekit-jwt.devmx.ixo.earth"
      }
      metrics_server = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      descheduler = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      hermes = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      hyperlane_validator = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      aws_vpc = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      uptime_kuma = {
        enabled      = false
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "status.devnet.ixo.earth"
      }
      chromadb = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
      }
      ghost = {
        enabled = false
        domain  = "ixoearth"
      }
      neo4j = {
        enabled    = true
        create_kv  = false
        domain     = "ixoearth"
        dns_prefix = "neo4j"
      }
      falco_security = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        dns_prefix    = "falco"
        storage_class = "bulk"
        storage_size  = "40Gi"
      }
      nomic_embedding = {
        enabled    = false
        create_kv  = false
        domain     = "ixoearth"
        dns_prefix = "nomic"
      }
      redis = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        storage_class = "bulk"
        storage_size  = "40Gi"
      }
      # IXO Services
      ixo_cellnode = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "devnet-cellnode.ixo.earth"
      }
      ixo_blocksync = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "devnet-blocksync-graphql.ixo.earth"
      }
      ixo_blocksync_core = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "ixo-blocksync-core.devnetkb.ixo.earth"
      }
      ixo_domain_indexer = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "domain-indexer"
      }
      ixo_qi_agents_builder = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "qi-agents-builder"
      }
      ixo_matrix_recording_bot = {
        enabled    = false
        create_kv  = false
        domain     = "ixoearth"
        dns_prefix = "matrix-recording-bot"
      }
      ixo_feegrant_nest = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "feegrant"
      }
      ixo_did_resolver = {
        enabled    = false
        create_kv  = false
        domain     = "ixoearth"
        dns_prefix = "resolver"
      }
      ixo_faucet = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "faucet"
      }
      ixo_matrix_state_bot = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "state.bot.devmx.ixo.earth"
        storage_class = "fast"
        storage_size  = "20Gi"
      }
      supamoto_matrix_state_bot = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      ixo_matrix_appservice_rooms = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "rooms.bot.devmx.ixo.earth"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      supamoto_matrix_appservice_rooms = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      claims_credentials_ecs = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "ecs.credentials.devnet.ixo.earth"
      }
      claims_credentials_prospect = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "prospect.credentials.devnet.ixo.earth"
      }
      claims_credentials_carbon = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "carbon.credentials.devnet.ixo.earth"
      }
      claims_credentials_umuzi = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "umuzi.credentials.devnet.ixo.earth"
      }
      claims_credentials_claimformprotocol = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      claims_credentials_did = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "didoracle.credentials.devnet.ixo.earth"
      }
      ixo_deeplink_server = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "deeplink"
      }
      ixo_kyc_server = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "kyc"
      }
      ixo_faq_assistant = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      ixo_coin_server = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      ixo_stake_reward_claimer = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      ixo_ussd = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      ixo_ussd_supamoto = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "ussd-supamoto"
      }
      ixo_whizz = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      auto_approve_offset = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      ixo_iot_data = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      ixo_notification_server = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      ixo_guru = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      ixo_trading_bot_server = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      ixo_ai_oracles_guru = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      ixo_ai_oracles_giza = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "giza.devnet.ixo.earth"
      }
      ixo_payments_nest = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      ixo_message_relayer = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "signx.devnet.ixo.earth"
      }
      ixo_cvms_exporter = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      ixo_registry_server = {
        enabled      = false
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "dev.api.emerging.eco"
      }
      ixo_agent_images_slack = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      ixo_aws_iam = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      ixo_firecrawl = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "firecrawl"
      }
      ixo_matrix_bids_bot = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "bid.bot.devmx.ixo.earth"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      supamoto_matrix_bids_bot = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      ixo_matrix_supamoto_bot = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "supamoto.bot.devmx.ixo.earth"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      ixo_matrix_supamoto_onboarding_server = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "supamoto-onboarding.devmx.ixo.earth"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      ixo_matrix_supamoto_claims_bot = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "supamoto.claims.bot.devmx.ixo.earth"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      ixo_matrix_claims_bot = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "claim.bot.devmx.ixo.earth"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      ixo_matrix_whatsapp = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        storage_class = "bulk"
        storage_size  = "40Gi"
      }
      ixo_subscriptions_oracle = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "subscriptions.oracle.devnet.ixo.earth"
      }
      ixo_subscriptions_oracle_bot = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "subscriptions.bot.devnet.ixo.earth"
      }
      ixo_pathgen_oracle = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "pathgen.oracle"
      }
      ixo_minerva_oracle = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "minerva"
      }
      ixo_minerva_livekit = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "minerva-livekit"
      }
      ixo_website_bot_oracle = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "website.bot"
      }
      ixo_jokes_oracle = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "jokes.oracle.devnet.ixo.earth"
      }
      ixo_domain_creator_oracle = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "domain-creator"
      }
      ixo_flow_manager_oracle = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "flow-manager"
      }
      ixo_kyc_oracle = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "kyc"
      }
      ixo_yellowcard_oracle = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "yellowcard"
      }
      ixo_ecs_oracle = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "ecs-oracle"
      }
      ixo_observable_framework_builder = {
        enabled       = false
        create_kv     = true
        domain        = "ixoearth"
        storage_class = "fast"
        storage_size  = "40Gi"
      }
      ixo_memory_engine_graphiti = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "memory-engine"
      }
      ixo_companion = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "companion"
      }
      ixo_sygnal = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      searxng = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "searxng"
      }
      oracles_cert_sync = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
    }
  }
}

additional_manual_synthetic_monitoring_endpoints = {
  devnet_aws = []
}

pg_matrix = {
  pg_cluster_name        = "synapse"
  pg_image               = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres"
  pg_image_tag           = "ubi8-15.5-0"
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

pg_ixo = {
  pg_cluster_name = "ixo-postgres"
  pg_image        = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres"
  pg_image_tag    = "ubi8-15.5-0"
  pg_users = [
    { username = "admin",                       databases = ["postgres"],                           options = "SUPERUSER" },
    { username = "cellnode",                    databases = ["cellnode"] },
    { username = "blocksync-core",              databases = ["blocksync-core", "blocksync-core_alt"] },
    { username = "blocksync",                   databases = ["blocksync", "blocksync_alt"] },
    { username = "deeplink",                    databases = ["deeplink"] },
    { username = "kyc",                         databases = ["kyc"] },
    { username = "coin-server",                 databases = ["coin-server"] },
    { username = "faq-assistant",               databases = ["faq-assistant"] },
    { username = "whizz",                       databases = ["whizz"] },
    { username = "iot-data",                    databases = ["iot-data"] },
    { username = "notification-server",         databases = ["notification-server"] },
    { username = "trading-bot-server",          databases = ["trading-bot-server"] },
    { username = "payments-nest",               databases = ["payments-nest"] },
    { username = "message-relayer",             databases = ["message-relayer"] },
    { username = "subscriptions-oracle-bot",    databases = ["subscriptions-oracle-bot"] },
    { username = "observable-framework-builder", databases = ["observable-framework-builder"] },
    { username = "pathgen-oracle",              databases = ["pathgen-oracle"] },
    { username = "jokes-oracle",                databases = ["jokes-oracle"] },
    { username = "supamoto-bot",                databases = ["supamoto-bot"] },
    { username = "supamoto-claims-bot",         databases = ["supamoto-claims-bot"] },
    { username = "firecrawl",                   databases = ["firecrawl"] },
    { username = "ussd-supamoto",               databases = ["ussd-supamoto"] },
    { username = "sygnal",                      databases = ["sygnal"] },
    { username = "feegrant-nest",               databases = ["feegrant-nest"] },
  ]
  pg_version             = 15
  pgbackrest_image       = "registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest"
  pgbackrest_image_tag   = "ubi8-2.47-2"
  pgmonitoring_image     = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres-exporter"
  pgmonitoring_image_tag = "ubi8-5.5.0-0"
}

additional_prometheus_scrape_metrics = {
  devnet_aws = ""
}
