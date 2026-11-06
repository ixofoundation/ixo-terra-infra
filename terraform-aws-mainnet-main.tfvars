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
vault_core_mount           = "ixo_core"

# Apps that serve the real mainnet hostnames (no dns_segment).
dns_cutover_apps = ["prometheus_stack", "dex", "vault", "auto_approve_offset", "ixo_stake_reward_claimer", "ixo_did_resolver", "ixo_registry_server", "matrix_livekit", "ixo_minerva_livekit", "uptime_kuma", "ghost", "ixo_domain_indexer", "ixo_matrix_recording_bot", "ixo_diagnostic_oracle", "ixo_ecs_oracle", "ixo_minerva_oracle", "ixo_website_bot_oracle", "ixo_kyc_oracle", "ixo_memory_engine_graphiti", "ixo_domain_creator_oracle", "ixo_cellnode", "ixo_blocksync", "ixo_blocksync_api", "ixo_blocksync_core", "ixo_coin_server", "ixo_deeplink_server", "ixo_feegrant_nest", "ixo_firecrawl", "ixo_iot_data", "ixo_kyc_server", "ixo_message_relayer", "ixo_notification_server", "ixo_observable_framework_builder", "ixo_payments_nest", "ixo_trading_bot_server", "claims_credentials_ecs", "claims_credentials_carbon", "claims_credentials_claimformprotocol", "claims_credentials_did", "matrix", "matrix_admin", "ixo_matrix_appservice_rooms", "ixo_matrix_whatsapp", "ixo_sygnal", "digihub_matrix_state_bot", "digihub_matrix_appservice_rooms", "digihub_matrix_bids_bot", "digihub_ixo_matrix_claims_bot", "supamoto_matrix_appservice_rooms", "ixo_matrix_supamoto_bot", "ixo_matrix_supamoto_onboarding_server", "ixo_matrix_supamoto_claims_bot"]

# No in-place major upgrade pending. Set explicitly so the auto-loaded terraform.tfvars can never
# supply one.
pg_upgrade = {}

# AVP (<path:>) apps for vault-argocd-watcher; use_eso apps are not listed.
additional_manual_vault_watched_apps = {
  mainnet = ["matrix-livekit", "searxng", "ixo-firecrawl", "ixo-sygnal"]
}

# Standalone: nothing is inherited from other var-files. kubernetes_cluster is the EKS version.
versions = {
  kubernetes_cluster       = "1.36"
  argocd                   = "9.5.0"
  cert-manager             = "1.20.2"
  nginx-ingress-controller = "2.4.4"
  postgres-operator        = "6.0.1"
  prometheus-stack         = "83.4.3"
  external-dns             = "1.20.0"
  vault                    = "0.32.0"
  # vault image for the snapshot CronJob; match the running server version.
  vault_cli                    = "1.21.2"
  loki                         = "6.55.0"
  prometheus-blackbox-exporter = "11.9.1"
  dex                          = "0.24.0"
  tailscale                    = "1.96.5"
  matrix                       = "3.12.28"
  openebs                      = "4.4.0"
  metrics-server               = "3.13.0"
  descheduler                  = "0.35.1"
  vpa                          = "4.12.3" # https://artifacthub.io/packages/helm/fairwinds-stable/vpa (upstream VPA v1.6.0)
  hummingbot                   = "0.2.0"
  uptime-kuma                  = "4.1.0"
  chromadb                     = "0.2.2"
  ghost                        = "25.0.4"
  neo4j                        = "2026.3.1"
  falco_security               = "8.0.2"
  redis                        = "25.3.11"
  surrealdb                    = "0.4.0"
  searxng                      = "1.0.1"
  external-secrets             = "2.7.0"  # https://artifacthub.io/packages/helm/external-secrets-operator/external-secrets
  reloader                     = "2.2.14" # https://artifacthub.io/packages/helm/stakater/reloader
}

environments = {
  # mainnet in the ixo-prod member account (361082683495). Run plans and applies
  # ONLY through ~/Documents/ixo-devops/scripts/mainnet.sh.
  mainnet = {
    # Old workspace name, kept where it renders: Application names, NETWORK, tailscale host.
    legacy_workspace_name = "mainnet_main"

    # Keeps the GCS bucket and KMS key ring names.
    global_resource_name = "mainnet_main"
    cluster_firewall     = true
    is_development       = false
    # Public until Tailscale reaches the VPC after migration, then set false.
    aws_eks_public_access = true
    aws_region            = "eu-west-1"
    aws_iam_users         = []
    aws_account_id        = "361082683495"
    aws_profile           = "ixo-prod"
    aws_cli_path          = "aws"
    vpc_cidr              = "10.66.0.0/16"
    aws_subnet_cidrs = {
      public  = ["10.66.0.0/24", "10.66.1.0/24"]
      private = ["10.66.32.0/19", "10.66.64.0/19"]
    }
    aws_service_ipv4_cidr = "172.20.0.0/16"
    cloud_resource_name   = "mainnet"
    kubeconfig_name       = "mainnet_main"
    loki_bucket_name      = "ixofoundation-mainnet-main-loki-chunks"
    # Own platform hostnames (*.mainnet-main.ixo.earth); also arms the DNS cross-env guard.
    dns_segment     = "mainnet-main"
    vault_oidc_team = "mainnet"
    chart_tree      = "mainnet"
    network_name    = "mainnet"
    # The key ring the snapshot source sealed with: a raft snapshot is barrier-encrypted under the SOURCE key,
    # so the restore must seal with it (any other key = silent success, undecryptable data).
    vault_seal = {
      key_ring   = "vault-mainnet-key-ring"
      crypto_key = "vault-mainnet-crypto-key"
    }
    vault_restored_from_snapshot = true
    vault_replicas               = 2
    grafana_max_open_conn        = 5
    grafana_admin_secret         = true
    aws_default_tags = {
      "aws-apn-id" = "pc:5bc946w6ri4iwivd8kdyyk1im"
    }
    aws_storage_class_parameters = {
      encrypted          = "true"
      tagSpecification_1 = "aws-apn-id=pc:5bc946w6ri4iwivd8kdyyk1im"
    }
    aws_node_launch_template = true
    aws_node_legacy_groups   = false
    # On-demand t3a.xlarge: firecrawl (6Gi), recording bot (3.5Gi) and graphiti (3Gi) don't fit t3.medium.
    aws_node_groups = {
      instance_types           = ["t3a.xlarge"]
      desired                  = 4
      min                      = 4
      max                      = 5
      on_demand_count          = 1
      on_demand_instance_types = ["t3a.xlarge"]
    }
    # 1 adds 2 db_lt node groups.
    aws_db_node_group = {
      per_az         = 1
      instance_types = ["t3a.large"]
    }
    aws_eks_authentication_mode = "API_AND_CONFIG_MAP"
    aws_eks_cluster_admin_arns  = []
    pg_standby = {
    }
    pg_backrest = {
      process_max   = 4
      compress_type = "zst"
    }
    rpc_url              = "https://impacthub.ixo.world/rpc/"
    ipfs_service_mapping = "https://ipfs.gateway.ixo.world"
    hyperlane = {
      chain_names     = ["ixo5", "base", "relayer"]
      metadata_chains = ["ixo5", "base", "relayer"]
    }
    aws_vpc_config = {
      nat_gateway_enabled = true # managed NAT, as testnet
      flow_logs_enabled   = false
      retention_days      = 7
      az_count            = 2
    }
    # dns_endpoint values are live hostnames (DNS guard); keep create_kv = false where the KV exists.
    application_configs = {
      # Core Infrastructure Services
      cert_manager = {
        enabled   = true
        create_kv = false
        domain    = "ixoworld"
      }
      ingress_nginx = {
        enabled   = true
        create_kv = false
        domain    = "ixoworld"
      }
      surrealdb = {
        enabled        = true
        memory_request = "756Mi"
        memory_limit   = "812Mi"
        create_kv      = false
        domain         = "ixoearth"
        storage_class  = "bulk"
        storage_size   = "40Gi"
      }
      postgres_operator_crunchydata = {
        enabled      = true
        create_kv    = false
        domain       = "ixoworld"
        storage_size = "150Gi"
        # Run the OpenTelemetry collector instead of the pgmonitor exporter.
        # Required before this environment can move to Postgres 18.
        use_otel = true
        # Patroni synchronous_mode on ixo-postgres (see variables.tf). Requires a healthy
        # streaming standby; check patronictl list before enabling in a new environment.
        enable_sync_replication = true
        # pgBackRest retention. See variables.tf.
        backup_retention_days        = 350
        matrix_backup_retention_full = 2
      }
      prometheus_stack = {
        enabled      = true
        create_kv    = false
        domain       = "ixoworld"
        dns_endpoint = "mainnetkb.ixo.earth" # listed in dns_cutover_apps
      }
      external_dns = {
        enabled   = true
        create_kv = false
        domain    = "ixoworld"
      }
      dex = {
        enabled      = true
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "dex.mainnet.ixo.earth" # listed in dns_cutover_apps
      }
      vault = {
        enabled                        = true
        create_kv                      = false
        domain                         = "ixoearth"
        dns_endpoint                   = "vault.mainnet.ixo.earth" # listed in dns_cutover_apps
        vault_snapshot_enabled         = true
        vault_snapshot_writer_sa_email = "devsecops@devsecops-415617.iam.gserviceaccount.com"
      }
      vault_argocd_watcher = {
        enabled    = true
        create_kv  = false
        domain     = "ixoearth"
        dns_prefix = "vault-watcher"
      }
      external_secrets = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
      }
      reloader = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
      }
      argocd_image_updater = {
        enabled   = false
        create_kv = false
      }
      loki = {
        enabled   = true
        create_kv = false
        domain    = "ixoworld"
      }
      prometheus_blackbox_exporter = {
        enabled   = true
        create_kv = false
        domain    = "ixoworld"
      }
      tailscale = {
        enabled   = true
        create_kv = false
        domain    = "ixoworld"
      }
      matrix = {
        enabled      = true
        create_kv    = false
        domain       = "ixoworld"
        dns_endpoint = "mx.ixo.earth"
        storage_size = "150Gi"
      }
      matrix_admin = {
        enabled      = true
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "admin.mx.ixo.earth"
      }
      matrix_livekit = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        domain       = "ixoearth"
        dns_endpoint = "livekit-jwt.mx.ixo.earth"
      }
      nfs_provisioner = {
        enabled   = false
        create_kv = false
      }
      metrics_server = {
        enabled   = true
        create_kv = false
        domain    = "ixoworld"
      }
      descheduler = {
        enabled   = true
        create_kv = false
        domain    = "ixoworld"
      }
      vpa = {
        enabled   = true
        create_kv = false
        domain    = "ixoworld"
      }
      hermes = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "hermes.ixo.earth"
      }
      hyperlane_validator = {
        enabled   = false # AWS account closed
        create_kv = false
        domain    = "ixoworld"
      }
      aws_vpc = {
        enabled   = false
        create_kv = false
        domain    = "ixoworld"
      }
      uptime_kuma = {
        enabled      = true
        create_kv    = false
        domain       = "ixoworld"
        dns_endpoint = "status.ixo.world"
      }
      chromadb = {
        enabled   = false
        create_kv = false
        domain    = "ixoworld"
      }
      ghost = {
        enabled      = true
        create_kv    = false
        domain       = "ixoworld"
        dns_endpoint = "impacts.ixo.world"
      }
      neo4j = {
        enabled    = false
        create_kv  = false
        domain     = "ixoearth"
        dns_prefix = "neo4j"
      }
      falco_security = {
        enabled    = false
        create_kv  = false
        domain     = "ixoearth"
        dns_prefix = "falco"
      }
      nomic_embedding = {
        enabled    = false
        create_kv  = false
        domain     = "ixoearth"
        dns_prefix = "nomic"
      }
      redis = {
        enabled       = true
        create_kv     = false
        domain        = "ixoearth"
        storage_class = "bulk"
        storage_size  = "40Gi"
      }
      # IXO Services
      ixo_cellnode = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoworld"
        dns_endpoint = "cellnode.ixo.world"
      }
      ixo_blocksync = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "index.blocksync.ixo.earth"
      }
      ixo_blocksync_api = {
        enabled      = true
        create_kv    = false
        use_eso      = true # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "blocksync-graphql.ixo.earth"
      }
      ixo_blocksync_core = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "ixo-blocksync-core.mainnetkb.ixo.earth"
      }
      ixo_domain_indexer = {
        enabled      = true
        create_kv    = false
        use_eso      = true # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "domain-indexer.ixo.earth"
      }
      ixo_qi_agents_builder = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "qi-agents-builder"
      }
      ixo_matrix_recording_bot = {
        enabled       = true
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "recording.bot.mx.ixo.earth"
        storage_class = "standard" # 0.7 G used; gp3 grows online
        storage_size  = "20Gi"
      }
      ixo_feegrant_nest = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoworld"
        dns_endpoint = "feegrant.ixo.world"
      }
      ixo_did_resolver = {
        enabled      = true
        create_kv    = false
        domain       = "ixoworld"
        dns_endpoint = "resolver.ixo.world"
      }
      ixo_faucet = {
        enabled      = false
        create_kv    = true
        domain       = "ixoworld"
        dns_endpoint = "faucet2.mainnetkb.ixo.earth"
      }
      ixo_matrix_state_bot = {
        enabled       = false # decommissioned
        create_kv     = false
        domain        = "ixoworld"
        dns_endpoint  = "state.bot.mx.ixo.earth"
        storage_class = "bulk"
        storage_size  = "40Gi"
      }
      ixo_matrix_appservice_rooms = {
        enabled        = true
        memory_request = "300Mi"
        memory_limit   = "450Mi"
        create_kv      = false
        domain         = "ixoworld"
        dns_endpoint   = "rooms.bot.mx.ixo.earth"
        storage_class  = "fast"
        storage_size   = "10Gi"
      }
      supamoto_matrix_state_bot = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "state.bot.matrix.supamoto.global"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      supamoto_ixo_matrix_claims_bot = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "claim.bot.matrix.supamoto.global"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      supamoto_matrix_appservice_rooms = {
        enabled       = true # crypto store on PVC: never run two instances
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "rooms.bot.matrix.supamoto.global"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      claims_credentials_ecs = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoworld"
        dns_endpoint = "ecs.credentials.ixo.world"
      }
      claims_credentials_prospect = {
        enabled      = false
        create_kv    = true
        domain       = "ixoworld"
        dns_endpoint = "prospect.credentials2.mainnet.ixo.world"
      }
      claims_credentials_carbon = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoworld"
        dns_endpoint = "carbon.credentials.ixo.world"
      }
      claims_credentials_umuzi = {
        enabled      = false
        create_kv    = true
        domain       = "ixoworld"
        dns_endpoint = "umuzi.credentials2.mainnet.ixo.world"
      }
      claims_credentials_claimformprotocol = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoworld"
        dns_endpoint = "claimformobjects.credentials.ixo.world"
      }
      claims_credentials_did = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "didoracle.credentials.ixo.earth"
      }
      ixo_deeplink_server = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "x.ixo.earth"
      }
      ixo_kyc_server = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "kyc.oracle.ixo.earth"
      }
      ixo_faq_assistant = {
        enabled      = false
        create_kv    = true
        use_eso      = true # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "faq.assistant.ixo.earth"
      }
      ixo_coin_server = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "coincache.ixo.earth"
      }
      ixo_stake_reward_claimer = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "reclaim.ixo.earth"
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
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "whizz.assistant.ixo.earth"
      }
      auto_approve_offset = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "offset.auto-approve.ixo.earth"
      }
      ixo_iot_data = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "iot-data.ixo.earth"
      }
      ixo_notification_server = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "notifications.ixo.earth"
      }
      ixo_guru = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "guru.ixo.earth"
      }
      ixo_trading_bot_server = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "trading.bot.ixo.earth"
      }
      ixo_ai_oracles_guru = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "guru2.ixo.earth"
      }
      ixo_ai_oracles_giza = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "giza.ixo.earth"
      }
      ixo_payments_nest = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "emerging"
        dns_endpoint = "payments.emerging.eco"
      }
      ixo_message_relayer = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "signx.ixo.earth"
      }
      ixo_cvms_exporter = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
      }
      ixo_registry_server = {
        enabled      = true
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "api.emerging.eco"
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
      ixo_matrix_bids_bot = {
        enabled       = false # decommissioned
        create_kv     = false
        domain        = "ixoworld"
        dns_endpoint  = "bid.bot.mx.ixo.earth"
        storage_class = "bulk"
        storage_size  = "40Gi"
      }
      supamoto_matrix_bids_bot = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "bid.bot.matrix.supamoto.global"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      digihub_matrix_state_bot = {
        enabled       = true # signing bot: never run two instances
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "state.bot.matrix.emediaworkspace.org"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      digihub_matrix_appservice_rooms = {
        enabled       = true # signing bot: never run two instances
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "rooms.bot.matrix.emediaworkspace.org"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      digihub_matrix_bids_bot = {
        enabled       = true # signing bot: never run two instances
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "bid.bot.matrix.emediaworkspace.org"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      digihub_ixo_matrix_claims_bot = {
        enabled       = true # signing bot: never run two instances
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "claim.bot.matrix.emediaworkspace.org"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      ixo_firecrawl = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        domain       = "ixoearth"
        dns_endpoint = "firecrawl.ixo.earth"
      }
      ixo_matrix_supamoto_bot = {
        enabled        = true # crypto store on PVC: never run two instances
        memory_request = "100Mi"
        memory_limit   = "650Mi"
        create_kv      = false
        domain         = "ixoearth"
        dns_endpoint   = "bot.matrix.supamoto.global"
        storage_class  = "fast"
        storage_size   = "10Gi"
      }
      ixo_matrix_supamoto_onboarding_server = {
        enabled       = true # crypto store on PVC: never run two instances
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "onboarding.matrix.supamoto.global"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      ixo_matrix_supamoto_claims_bot = {
        enabled        = true # crypto store on PVC: never run two instances
        memory_request = "600Mi"
        memory_limit   = "750Mi"
        create_kv      = false
        domain         = "ixoearth"
        dns_endpoint   = "submission.claim.bot.matrix.supamoto.global"
        storage_class  = "fast"
        storage_size   = "10Gi"
      }
      ixo_matrix_claims_bot = {
        enabled       = false # decommissioned
        create_kv     = false
        domain        = "ixoworld"
        dns_endpoint  = "claim.bot.mx.ixo.earth"
        storage_class = "bulk"
        storage_size  = "40Gi"
      }
      ixo_matrix_whatsapp = {
        enabled       = true
        create_kv     = false
        dns_endpoint  = "whatsapp.bridge.mx.ixo.world"
        domain        = "ixoworld"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      ixo_subscriptions_oracle = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "subscriptions.oracle.ixo.earth"
      }
      ixo_subscriptions_oracle_bot = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "subscriptions.bot.ixo.earth"
      }
      ixo_pathgen_oracle = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "pathgen.oracle"
      }
      ixo_minerva_oracle = {
        enabled       = true
        create_kv     = false
        use_eso       = true # env secrets via external-secrets-operator
        domain        = "ixoearth"
        dns_endpoint  = "minerva.ixo.earth"
        storage_class = "standard"
        storage_size  = "10Gi"
      }
      ixo_minerva_livekit = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "minerva-livekit.ixo.earth"
      }
      ixo_website_bot_oracle = {
        enabled       = true
        create_kv     = false
        use_eso       = true # env secrets via external-secrets-operator
        domain        = "ixoearth"
        dns_endpoint  = "website.bot.ixo.earth"
        storage_class = "standard"
        storage_size  = "10Gi"
      }
      ixo_jokes_oracle = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "jokes.oracle.ixo.earth"
      }
      ixo_domain_creator_oracle = {
        enabled       = true
        create_kv     = false
        use_eso       = true # env secrets via external-secrets-operator
        domain        = "ixoearth"
        dns_endpoint  = "domain-creator.ixo.earth"
        storage_class = "standard"
        storage_size  = "10Gi"
      }
      ixo_flow_manager_oracle = {
        enabled        = false
        memory_request = "1560Mi"
        memory_limit   = "2048Mi"
        create_kv      = true
        use_eso        = true # env secrets via external-secrets-operator
        domain         = "ixoearth"
        dns_prefix     = "flow-manager"
        storage_class  = "fast"
        storage_size   = "10Gi"
      }
      ixo_diagnostic_oracle = {
        enabled       = true
        create_kv     = false
        use_eso       = true
        domain        = "ixoearth"
        dns_endpoint  = "diagnostic.ixo.earth"
        storage_class = "standard"
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
      ixo_supamoto_3cx_server = {
        enabled       = false
        create_kv     = true
        use_eso       = true
        domain        = "ixoearth"
        dns_prefix    = "3cx"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      ixo_kyc_oracle = {
        enabled       = true
        create_kv     = false
        use_eso       = true # env secrets via external-secrets-operator
        domain        = "ixoworld"
        dns_endpoint  = "kyc.oracle.ixo.world"
        storage_class = "standard"
        storage_size  = "10Gi"
      }
      ixo_yellowcard_oracle = {
        enabled       = false
        create_kv     = true
        domain        = "ixoearth"
        dns_prefix    = "yellowcard"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      ixo_ecs_oracle = {
        enabled       = true
        create_kv     = false
        use_eso       = true # env secrets via external-secrets-operator
        domain        = "ixoearth"
        dns_endpoint  = "ecs-oracle.ixo.earth"
        storage_class = "standard"
        storage_size  = "10Gi"
      }
      ixo_yoma_agent_oracle = {
        enabled       = false
        create_kv     = true
        domain        = "ixoearth"
        dns_prefix    = "yoma-agent"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      ixo_observable_framework_builder = {
        enabled       = true
        create_kv     = false # KV came with the Vault restore
        use_eso       = true  # env secrets via external-secrets-operator
        domain        = "ixoearth"
        dns_endpoint  = "builder.observable.ixo.earth"
        storage_class = "fast"
        storage_size  = "40Gi"
      }
      ixo_memory_engine_graphiti = {
        enabled       = true
        create_kv     = false
        use_eso       = true # env secrets via external-secrets-operator
        domain        = "ixoearth"
        dns_endpoint  = "memory-engine.ixo.earth"
        storage_class = "standard" # ts PVC only, 0.4 G used
        storage_size  = "10Gi"
      }
      ixo_companion = {
        enabled    = false
        create_kv  = true
        use_eso    = true # env secrets via external-secrets-operator
        domain     = "ixoearth"
        dns_prefix = "companion"
      }
      ixo_sygnal = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        domain       = "ixoworld"
        dns_endpoint = "sygnal.ixo.world"
      }
      searxng = {
        enabled    = true
        create_kv  = false # KV came with the Vault restore
        domain     = "ixoearth"
        dns_prefix = "searxng"
      }
      oracles_cert_sync = {
        enabled   = false # oracles.work is on the CF Free plan, custom certs rejected (1011)
        create_kv = false
        domain    = "ixoearth"
      }
    }
  }
}

# Validator scrape jobs are not here: those hosts are unreachable from outside.
additional_manual_synthetic_monitoring_endpoints = {
  mainnet = [
    "https://coincache.ixo.earth",
    "https://trading.bot.ixo.earth/api/",
    "https://reclaim.ixo.earth",
    "https://signx.ixo.earth",
    "https://ixo.rpc.m.stavr.tech",
    "https://impacthub.ixo.world/rpc/",
    "https://api.emerging.eco/emerging-platform/v1/hello",
    "https://mx.ixo.earth/health",
    "https://ipfs.gateway.ixo.world/health",
    "https://archive.impacthub.ixo.earth/rpc/",
    "https://livekit-jwt.mx.ixo.earth/healthz",
    "https://sygnal.ixo.world/health"
  ]
}

pg_matrix = {
  pg_cluster_name = "synapse"
  pg_image        = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres"
  pg_image_tag    = "ubi9-18.3-2610"
  pg_users = [
    {
      username  = "synapse"
      options   = "SUPERUSER"
      databases = []
    }
  ]
  pg_version = 18
  namespace  = "matrix-synapse"
  # Steady state ~1.06 GiB; restore and WAL catch-up need headroom.
  memory_request         = "1.5Gi"
  memory_limit           = "2Gi"
  pgbackrest_image       = "registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest"
  pgbackrest_image_tag   = "ubi9-2.58.0-2610"
  pgmonitoring_image     = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres-exporter"
  pgmonitoring_image_tag = "ubi8-5.5.0-0"
}

pg_ixo = {
  pg_cluster_name = "ixo-postgres"
  pg_image        = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres"
  pg_image_tag    = "ubi9-18.3-2610"
  pg_users = [
    { username = "admin", databases = ["postgres"], options = "SUPERUSER" },
    { username = "cellnode", databases = ["cellnode"] },
    { username = "blocksync-core", databases = ["blocksync-core", "blocksync-core_alt"] },
    { username = "blocksync", databases = ["blocksync", "blocksync_alt"] },
    { username = "deeplink", databases = ["deeplink"] },
    { username = "kyc", databases = ["kyc"] },
    { username = "coin-server", databases = ["coin-server"] },
    { username = "faq-assistant", databases = ["faq-assistant"] },
    { username = "whizz", databases = ["whizz"] },
    { username = "iot-data", databases = ["iot-data"] },
    { username = "notification-server", databases = ["notification-server"] },
    { username = "trading-bot-server", databases = ["trading-bot-server"] },
    { username = "payments-nest", databases = ["payments-nest"] },
    { username = "message-relayer", databases = ["message-relayer"] },
    { username = "subscriptions-oracle-bot", databases = ["subscriptions-oracle-bot"] },
    { username = "observable-framework-builder", databases = ["observable-framework-builder"] },
    { username = "pathgen-oracle", databases = ["pathgen-oracle"] },
    { username = "jokes-oracle", databases = ["jokes-oracle"] },
    { username = "supamoto-bot", databases = ["supamoto-bot"] },
    { username = "supamoto-claims-bot", databases = ["supamoto-claims-bot"] },
    { username = "firecrawl", databases = ["firecrawl"] },
    { username = "ussd-supamoto", databases = ["ussd-supamoto"] },
    { username = "sygnal", databases = ["sygnal"] },
    { username = "feegrant-nest", databases = ["feegrant-nest"] },
    { username = "eval-engine", databases = ["eval-engine"] },
    { username = "3cx-server", databases = ["3cx-server"] },
  ]
  pg_version             = 18
  pgbackrest_image       = "registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest"
  pgbackrest_image_tag   = "ubi9-2.58.0-2610"
  pgmonitoring_image     = "registry.developers.crunchydata.com/crunchydata/crunchy-postgres-exporter"
  pgmonitoring_image_tag = "ubi8-5.5.0-0"
}

additional_prometheus_scrape_metrics = {
  mainnet = ""
}
