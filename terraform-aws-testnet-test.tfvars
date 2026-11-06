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

# Enabled apps with KV in ixo_core, for vault-argocd-watcher. matrix is excluded (no AVP plugin).
additional_manual_vault_watched_apps = {
  testnet = [
    "auto-approve-offset", "claims-credentials-carbon", "claims-credentials-did", "claims-credentials-ecs",
    "claims-credentials-prospect", "ixo-blocksync", "ixo-blocksync-core", "ixo-cellnode", "ixo-domain-creator-oracle",
    "ixo-domain-indexer", "ixo-ecs-oracle", "ixo-faucet", "ixo-feegrant-nest", "ixo-kyc-oracle", "ixo-kyc-server",
    "ixo-memory-engine-graphiti", "ixo-message-relayer", "ixo-payments-nest", "ixo-ussd-supamoto",
    "ixo-website-bot-oracle", "ixo-yellowcard-oracle", "ixo-yoma-agent-oracle", "matrix-livekit",
  ]
}

# Apps that serve the real testnet hostnames.
dns_cutover_apps = ["ixo_domain_indexer", "auto_approve_offset", "prometheus_stack", "ixo_did_resolver", "ixo_registry_server", "ixo_faucet", "matrix", "matrix_admin", "matrix_livekit", "ixo_matrix_appservice_rooms", "ixo_matrix_supamoto_bot", "ixo_matrix_supamoto_onboarding_server", "ixo_matrix_supamoto_claims_bot", "ixo_yoma_agent_oracle", "ixo_domain_creator_oracle", "ixo_kyc_oracle", "ixo_yellowcard_oracle", "ixo_memory_engine_graphiti", "ixo_ecs_oracle", "ixo_website_bot_oracle", "ixo_cellnode", "ixo_blocksync_api", "ixo_blocksync_core", "ixo_message_relayer", "ixo_payments_nest", "ixo_blocksync", "ixo_feegrant_nest", "ixo_ussd_supamoto", "ixo_kyc_server", "claims_credentials_ecs", "claims_credentials_prospect", "claims_credentials_carbon", "claims_credentials_did", "vault", "dex"]

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
  # testnet in the ixo-test member account (536202635008). Run plans and applies
  # ONLY through ~/Documents/ixo-devops/scripts/testnet.sh.
  testnet = {
    # Keeps the GCS bucket and KMS key ring names.
    global_resource_name = "testnet_test"
    # Old workspace name, kept where it renders: claims-credentials NETWORK, faucet PROJECT_NAME, kyc-server
    # IXO_NETWORK, auto-approve-offset NETWORK. Dropping it is a live change.
    legacy_workspace_name = "testnet_test"
    cluster_firewall      = true
    is_development        = true
    aws_region            = "eu-west-1"
    aws_iam_users         = []
    aws_account_id        = "536202635008"
    aws_profile           = "ixo-test"
    aws_cli_path          = "aws"
    vpc_cidr              = "10.65.0.0/16"
    aws_subnet_cidrs = {
      public  = ["10.65.0.0/24", "10.65.1.0/24"]
      private = ["10.65.32.0/19", "10.65.64.0/19"]
    }
    aws_service_ipv4_cidr = "172.20.0.0/16"
    cloud_resource_name   = "testnet"
    kubeconfig_name       = "testnet_test"
    loki_bucket_name      = "ixofoundation-testnet-test-loki-chunks"
    # Own platform hostnames (*.testnet-test.ixo.earth); also arms the DNS cross-env guard.
    dns_segment     = "testnet-test"
    vault_oidc_team = "testnet"
    chart_tree      = "testnet"
    network_name    = "testnet"
    # The key ring the snapshot source sealed with: a raft snapshot is barrier-encrypted under the SOURCE key,
    # so the restore must seal with it (any other key = silent success, undecryptable data).
    vault_seal = {
      key_ring   = "vault-testnet-key-ring"
      crypto_key = "vault-testnet-crypto-key"
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
    aws_node_groups = {
      desired                  = 3
      min                      = 3
      max                      = 4
      on_demand_count          = 1
      on_demand_instance_types = ["t3a.xlarge"]
    }
    aws_db_node_group = {
      per_az         = 1
      instance_types = ["t3a.large"]
    }
    aws_eks_authentication_mode = "API_AND_CONFIG_MAP"
    aws_eks_cluster_admin_arns  = []
    pg_backrest = {
      process_max   = 4
      compress_type = "zst"
    }
    rpc_url              = "https://testnet.ixo.earth/rpc/"
    ipfs_service_mapping = "https://ipfs.gateway.ixo.world"
    hyperlane = {
      chain_names     = ["relayer", "pandora8", "basesepolia"]
      metadata_chains = ["relayer", "pandora8", "basesepolia"]
    }
    aws_vpc_config = {
      nat_gateway_enabled = true # managed NAT
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
        storage_class = "standard"
        storage_size  = "5Gi"
      }
      postgres_operator_crunchydata = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
        # ~25 GiB of data.
        storage_size = "100Gi"
        # Run the OpenTelemetry collector instead of the pgmonitor exporter.
        # Required before this environment can move to Postgres 18.
        use_otel = true
        # Patroni synchronous_mode on ixo-postgres (see variables.tf). Requires a healthy
        # streaming standby; check patronictl list before enabling in a new environment.
        enable_sync_replication = true
        # pgBackRest full backups to retain (fulls are weekly => ~4 weeks of PITR).
        # Without this nothing ever expires and WAL is kept back to the oldest full.
        backup_retention_days        = 350
        matrix_backup_retention_full = 2
      }
      prometheus_stack = {
        enabled      = true
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "testnetkb.ixo.earth"
      }
      external_dns = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
      }
      dex = {
        enabled      = true
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "dex.testnet.ixo.earth" # listed in dns_cutover_apps
      }
      vault = {
        enabled                        = true
        create_kv                      = false
        domain                         = "ixoearth"
        dns_endpoint                   = "vault.testnet.ixo.earth" # listed in dns_cutover_apps
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
        enabled   = true # the only tag writer
        create_kv = false
      }
      loki = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
      }
      prometheus_blackbox_exporter = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
      }
      tailscale = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      matrix = {
        enabled      = true
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "testmx.ixo.earth"
        storage_size = "150Gi" # resized by hand from 100Gi; a PVC can only grow
      }
      matrix_admin = {
        enabled      = true
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "admin.testmx.ixo.earth" # listed in dns_cutover_apps
      }
      matrix_livekit = {
        enabled      = true  # outward-registering: never run two instances
        create_kv    = false # KV came with the Vault restore
        domain       = "ixoearth"
        dns_endpoint = "livekit-jwt.testmx.ixo.earth"
      }
      nfs_provisioner = {
        enabled   = false
        create_kv = false
      }
      metrics_server = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
      }
      descheduler = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
      }
      vpa = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
      }
      hermes = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      hyperlane_validator = {
        enabled   = false # AWS account closed
        create_kv = false
        domain    = "ixoearth"
      }
      aws_vpc = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      uptime_kuma = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      chromadb = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      ghost = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      neo4j = {
        enabled    = false
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
        enabled       = true
        create_kv     = false
        domain        = "ixoearth"
        storage_class = "bulk"
        storage_size  = "40Gi"
      }
      # IXO Services
      ixo_cellnode = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore (Z6 matched)
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "testnet-cellnode.ixo.earth"
      }
      ixo_blocksync = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore (Z6 matched)
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "index.blocksync.testnet.ixo.earth" # listed in dns_cutover_apps
      }
      ixo_blocksync_api = {
        enabled      = true
        create_kv    = false
        use_eso      = true # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "testnet-blocksync-graphql.ixo.earth"
      }
      ixo_blocksync_core = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore (Z6 matched)
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "ixo-blocksync-core.testnetkb.ixo.earth"
      }
      ixo_domain_indexer = {
        # Never create_kv (it would wipe it and mint a new SURREAL_PASS).
        enabled      = true
        create_kv    = false
        use_eso      = true # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "domain-indexer.testnet.ixo.earth"
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
        enabled      = true
        create_kv    = false # KV came with the Vault restore (Z6 matched)
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "feegrant.testnet.ixo.earth" # listed in dns_cutover_apps
      }
      ixo_did_resolver = {
        enabled      = true
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "resolver.testnet.ixo.earth"
      }
      ixo_faucet = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore; cas=1 would rewrite it (devnet 2a.4)
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "faucet.testnet.ixo.earth"
      }
      ixo_matrix_state_bot = {
        enabled       = false # decommissioned
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "state.bot.testmx.ixo.earth"
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
      ixo_matrix_appservice_rooms = {
        enabled        = true
        memory_request = "500Mi"
        memory_limit   = "650Mi"
        create_kv      = false
        domain         = "ixoearth"
        dns_endpoint   = "rooms.bot.testmx.ixo.earth"
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
      supamoto_matrix_appservice_rooms = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      digihub_matrix_state_bot = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "state.bot.matrix.emediaworkspace.org"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      digihub_matrix_appservice_rooms = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "rooms.bot.matrix.emediaworkspace.org"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      digihub_matrix_bids_bot = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "bid.bot.matrix.emediaworkspace.org"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      digihub_ixo_matrix_claims_bot = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "claim.bot.matrix.emediaworkspace.org"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      claims_credentials_ecs = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "ecs.credentials.testnet.ixo.earth" # listed in dns_cutover_apps
      }
      claims_credentials_prospect = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "prospect.credentials.testnet.ixo.earth" # listed in dns_cutover_apps
      }
      claims_credentials_carbon = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "carbon.credentials.testnet.ixo.earth" # listed in dns_cutover_apps
      }
      claims_credentials_umuzi = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      claims_credentials_claimformprotocol = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      claims_credentials_did = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "didoracle.credentials.testnet.ixo.earth" # listed in dns_cutover_apps
      }
      ixo_deeplink_server = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "deeplink"
      }
      ixo_kyc_server = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore (Z6 matched)
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "kyc.testnet.ixo.earth" # listed in dns_cutover_apps
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
        enabled      = true
        create_kv    = false # KV came with the Vault restore (Z6 matched)
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "ussd-supamoto.testnet.ixo.earth" # listed in dns_cutover_apps
      }
      ixo_whizz = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      auto_approve_offset = {
        enabled      = true  # signing agent: never run two instances
        create_kv    = false # KV came with the Vault restore
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "offset.auto-approve.testnet.ixo.earth"
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
        dns_endpoint = "gizatest.ixo.earth"
      }
      ixo_payments_nest = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore (Z6 matched)
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "emerging"
        dns_endpoint = "payments.testnet.emerging.eco"
      }
      ixo_message_relayer = {
        enabled      = true
        create_kv    = false # KV came with the Vault restore (Z6 matched)
        use_eso      = true  # env secrets via external-secrets-operator
        domain       = "ixoearth"
        dns_endpoint = "signx.testnet.ixo.earth"
      }
      ixo_cvms_exporter = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      ixo_registry_server = {
        enabled      = true
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "stage.api.emerging.eco"
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
        enabled       = false # decommissioned
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "bid.bot.testmx.ixo.earth"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      supamoto_matrix_bids_bot = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      ixo_matrix_supamoto_bot = {
        enabled        = true
        memory_request = "100Mi"
        memory_limit   = "650Mi"
        create_kv      = false
        domain         = "ixoearth"
        dns_endpoint   = "supamoto.bot.testmx.ixo.earth"
        storage_class  = "fast"
        storage_size   = "10Gi"
      }
      ixo_matrix_supamoto_onboarding_server = {
        enabled       = true
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "supamoto-onboarding.testmx.ixo.earth"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      ixo_matrix_supamoto_claims_bot = {
        enabled        = true
        memory_request = "100Mi"
        memory_limit   = "650Mi"
        create_kv      = false
        domain         = "ixoearth"
        dns_endpoint   = "supamoto.claims.bot.testmx.ixo.earth"
        storage_class  = "fast"
        storage_size   = "10Gi"
      }
      ixo_matrix_claims_bot = {
        enabled       = false # decommissioned
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "claim.bot.testmx.ixo.earth"
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
        dns_endpoint = "subscriptions.oracle.testnet.ixo.earth"
      }
      ixo_subscriptions_oracle_bot = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "subscriptions.bot.testnet.ixo.earth"
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
        enabled       = true
        create_kv     = false
        use_eso       = true # env secrets via external-secrets-operator
        domain        = "ixoearth"
        dns_endpoint  = "website.bot.testnet.ixo.earth" # listed in dns_cutover_apps
        storage_class = "standard"                      # gp3
        storage_size  = "10Gi"
      }
      ixo_jokes_oracle = {
        enabled      = false
        create_kv    = true
        domain       = "ixoearth"
        dns_endpoint = "jokes.oracle.testnet.ixo.earth"
      }
      ixo_domain_creator_oracle = {
        enabled       = true
        create_kv     = false
        use_eso       = true # env secrets via external-secrets-operator
        domain        = "ixoearth"
        dns_endpoint  = "domain-creator.testnet.ixo.earth" # listed in dns_cutover_apps
        storage_class = "standard"                         # gp3
        storage_size  = "10Gi"
      }
      ixo_flow_manager_oracle = {
        enabled        = false
        memory_request = "750Mi"
        memory_limit   = "850Mi"
        create_kv      = true
        use_eso        = true # env secrets via external-secrets-operator
        domain         = "ixoearth"
        dns_prefix     = "flow-manager"
        storage_class  = "fast"
        storage_size   = "10Gi"
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
        enabled       = false # unused (empty volume)
        create_kv     = false # KV came with the Vault restore (Z6 matched)
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
        dns_endpoint  = "kyc.testnet.ixo.world" # listed in dns_cutover_apps
        storage_class = "standard"              # gp3
        storage_size  = "10Gi"
      }
      ixo_yellowcard_oracle = {
        enabled       = true
        create_kv     = false
        use_eso       = true # env secrets via external-secrets-operator
        domain        = "ixoworld"
        dns_endpoint  = "yellowcard.testnet.ixo.world" # listed in dns_cutover_apps
        storage_class = "standard"                     # gp3
        storage_size  = "10Gi"
      }
      ixo_ecs_oracle = {
        enabled       = true
        create_kv     = false
        use_eso       = true # env secrets via external-secrets-operator
        domain        = "ixoearth"
        dns_endpoint  = "ecs-oracle.testnet.ixo.earth" # listed in dns_cutover_apps
        storage_class = "standard"                     # gp3
        storage_size  = "30Gi"
      }
      ixo_yoma_agent_oracle = {
        enabled       = true
        create_kv     = false
        use_eso       = true # env secrets via external-secrets-operator
        domain        = "ixoearth"
        dns_endpoint  = "yoma-agent.testnet.ixo.earth" # listed in dns_cutover_apps
        storage_class = "standard"                     # gp3
        storage_size  = "10Gi"
      }
      ixo_observable_framework_builder = {
        enabled       = false
        create_kv     = true
        domain        = "ixoearth"
        storage_class = "fast"
        storage_size  = "40Gi"
      }
      ixo_memory_engine_graphiti = {
        enabled       = true # legacy off via the values gate
        create_kv     = false
        use_eso       = true # env secrets via external-secrets-operator
        domain        = "ixoearth"
        dns_endpoint  = "memory-engine.testnet.ixo.earth" # listed in dns_cutover_apps
        storage_class = "standard"                        # gp3
        storage_size  = "40Gi"
      }
      ixo_companion = {
        enabled    = false
        create_kv  = true
        use_eso    = true # env secrets via external-secrets-operator
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
  testnet = []
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
  testnet = ""
}

# No in-place major upgrade pending. Set explicitly so the auto-loaded terraform.tfvars can never
# supply one.
pg_upgrade = {}
