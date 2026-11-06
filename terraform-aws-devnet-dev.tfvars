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

# Enabled apps with KV in ixo_core, for vault-argocd-watcher.
additional_manual_vault_watched_apps = {
  devnet = [
    "claims-credentials-carbon", "claims-credentials-ecs", "claims-credentials-prospect", "claims-credentials-umuzi",
    "ixo-blocksync", "ixo-blocksync-core", "ixo-cellnode", "ixo-domain-indexer", "ixo-feegrant-nest",
    "ixo-message-relayer", "ixo-pathgen-oracle", "ixo-ussd-supamoto", "matrix-livekit", "ixo-minerva-livekit",
  ]
}

# Apps that serve the real devnet hostnames.
dns_cutover_apps = ["ixo_did_resolver", "ixo_registry_server", "ixo_faucet", "ixo_yoma_agent_oracle", "ixo_domain_creator_oracle", "ixo_qi_agents_builder", "ixo_minerva_oracle", "ixo_minerva_livekit", "ixo_website_bot_oracle", "ixo_memory_engine_graphiti", "ixo_blocksync", "ixo_blocksync_api", "ixo_blocksync_core", "ixo_cellnode", "ixo_feegrant_nest", "ixo_message_relayer", "ixo_ussd_supamoto", "ixo_matrix_supamoto_bot", "ixo_matrix_supamoto_onboarding_server", "ixo_matrix_supamoto_claims_bot", "ixo_pathgen_oracle", "ixo_domain_indexer", "matrix", "matrix_admin", "matrix_livekit", "ixo_matrix_appservice_rooms", "claims_credentials_carbon", "claims_credentials_ecs", "claims_credentials_prospect", "claims_credentials_umuzi", "prometheus_stack"]

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
  uptime-kuma                  = "4.0.0"
  chromadb                     = "0.2.2"
  chromadb_image               = "0.6.3" # chromadb/chroma tag; data written by 0.6.x
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
  # devnet in the ixo-dev member account. Run plans and applies ONLY through
  # ~/Documents/ixo-devops/scripts/devnet.sh.
  devnet = {
    cluster_firewall = true
    is_development   = true
    aws_region       = "eu-west-1"
    aws_iam_users    = []
    # ixo-dev. allowed_account_ids refuses any other account, so the mgmt IAM keys that
    # ~/.zshrc exports fail the plan instead of building there.
    aws_account_id = "896358490078"
    aws_profile    = "ixo-dev"
    # Resolved on PATH.
    aws_cli_path = "aws"
    # 10.64.0.0/16: /24 public and /19 private per AZ, one entry per AZ.
    vpc_cidr = "10.64.0.0/16"
    aws_subnet_cidrs = {
      public  = ["10.64.0.0/24", "10.64.1.0/24"]
      private = ["10.64.32.0/19", "10.64.64.0/19"]
    }
    aws_service_ipv4_cidr = "172.20.0.0/16"
    # Per-account AWS names are "devnet". The two names that are NOT per-account are set
    # explicitly: the kubeconfig file and the loki S3 bucket (global namespace).
    cloud_resource_name = "devnet"
    # Keeps the GCS bucket, GCP KMS ring and agent-images Lambda names. A KMS ring can never be
    # replaced or destroyed.
    global_resource_name = "devnet_dev"
    # Old workspace name, kept where it renders: faucet PROJECT_NAME, claims-credentials NETWORK
    # (carbon, prospect, ecs, umuzi) and the tailscale operator hostname. Dropping it is a live change.
    legacy_workspace_name = "devnet_dev"
    kubeconfig_name       = "devnet_dev"
    loki_bucket_name      = "ixofoundation-devnet-dev-loki-chunks"
    # Platform hosts dex.devnet / vault.devnet. Also arms the DNS guard.
    dns_segment     = "devnet"
    vault_oidc_team = "devnet"
    chart_tree      = "devnet"
    network_name    = "devnet"
    # Vault was restored from a raft snapshot sealed with devnet's key, so it must seal with it.
    # Its own key = silent success + data that cannot be decrypted.
    vault_seal = {
      key_ring   = "vault-devnet-key-ring"
      crypto_key = "vault-devnet-crypto-key"
    }
    vault_restored_from_snapshot = true
    vault_replicas               = 2
    grafana_max_open_conn        = 5
    # Admin password must not change on re-render.
    grafana_admin_secret = true
    # Landing-zone tag policy ixo-aws-apn-id (root, reporting only). On this provider only. default_tags do not reach what Kubernetes
    # creates, hence the StorageClass tagSpecification as well.
    aws_default_tags = {
      "aws-apn-id" = "pc:5bc946w6ri4iwivd8kdyyk1im"
    }
    aws_storage_class_parameters = {
      encrypted          = "true"
      tagSpecification_1 = "aws-apn-id=pc:5bc946w6ri4iwivd8kdyyk1im"
    }
    # 1 ON_DEMAND + 2 Spot, on template-based node groups (-lt).
    aws_node_launch_template = true
    aws_node_legacy_groups   = false
    aws_node_groups = {
      desired                  = 3
      min                      = 3
      max                      = 4
      on_demand_count          = 1
      on_demand_instance_types = ["t3a.xlarge"]
    }
    # 2 x t3a.large ON_DEMAND, one per AZ, tainted ixo.world/pool=db.
    aws_db_node_group = {
      per_az         = 1
      instance_types = ["t3a.large"]
    }
    # Empty: EKS adds the creator SSO role itself. SSO role ARNs go in without the /aws-reserved/... path.
    aws_eks_authentication_mode = "API_AND_CONFIG_MAP"
    aws_eks_cluster_admin_arns  = []
    rpc_url                     = "https://devnet.ixo.earth/rpc/"
    ipfs_service_mapping        = "https://ipfs.gateway.ixo.world"
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
        storage_class = "standard"
        storage_size  = "5Gi"
      }
      postgres_operator_crunchydata = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
        # ~17 GiB of data, ~32 GiB with WAL.
        storage_size = "64Gi"
        # As devnet: PG18 needs the OTel collector; sync replication; 30-day repos.
        use_otel                     = true
        enable_sync_replication      = true
        backup_retention_days        = 30
        matrix_backup_retention_full = 2
        matrix_repo1_storage_size    = "50Gi"
      }
      prometheus_stack = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
        # Serves /argocd, /grafana and /. Also the nginx controller Service's external-dns hostname.
        dns_endpoint = "devnetkb.ixo.earth"
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
        dns_prefix = "dex"
      }
      vault = {
        enabled    = true
        create_kv  = false
        domain     = "ixoearth"
        dns_prefix = "vault"
        # Bucket: ixofoundation-devnet_dev-vault-snapshots.
        vault_snapshot_enabled         = true
        vault_snapshot_writer_sa_email = "devsecops@devsecops-415617.iam.gserviceaccount.com"
      }
      # Needs a non-empty watched list (the binary exits on an empty WATCHED_APPS).
      vault_argocd_watcher = {
        enabled    = true
        create_kv  = false
        domain     = "ixoearth"
        dns_prefix = "vault-watcher"
      }
      loki = {
        # Deployed through module.loki_s3, not module.loki: chunks in S3 over IRSA with a
        # 30Gi gp3 volume for WAL + index. See main_loki_s3.tf and config/yml/helm_values/loki-values-s3.yml.
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
      }
      prometheus_blackbox_exporter = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
      }
      # Some entries below exist only so application_configs[<key>] resolves (modules_core.tf and
      # modules.tf index these keys unconditionally for every workspace).
      argocd_image_updater = {
        enabled   = true # the only writer to charts/devnet
        create_kv = false
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
      vpa = {
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
      }
      ixo_blocksync_api = {
        enabled      = true
        create_kv    = false
        use_eso      = true
        domain       = "ixoearth"
        dns_endpoint = "devnet-blocksync-graphql.ixo.earth"
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
        enabled       = true
        create_kv     = false
        use_eso       = true
        domain        = "ixoearth"
        dns_endpoint  = "yoma-agent.devnet.ixo.earth"
        storage_class = "standard"
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
        enabled   = true
        create_kv = false
        domain    = "ixoearth"
      }
      matrix = {
        enabled      = true
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "devmx.ixo.earth"
      }
      matrix_admin = {
        enabled      = true
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "admin.devmx.ixo.earth"
      }
      matrix_livekit = {
        enabled      = true
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "livekit-jwt.devmx.ixo.earth"
      }
      # mainnet-only; the key must exist in every workspace.
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
        enabled    = false
        create_kv  = false
        domain     = "ixoearth"
        dns_prefix = "status"
      }
      chromadb = {
        # Pinned to 0.6.3 (versions.chromadb_image).
        enabled      = true
        create_kv    = false
        domain       = "ixoearth"
        storage_size = "5Gi"
      }
      ghost = {
        enabled = false
        domain  = "ixoearth"
      }
      neo4j = {
        # Not deployed on AWS yet; data stores come with their own stage.
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
        # `save ""` in redis-values.yml disables RDB outright, so this is a pure cache. gp3 grows online but never shrinks, so size small and let it fill.
        storage_size = "8Gi"
      }
      # IXO Services
      ixo_cellnode = {
        enabled      = true
        create_kv    = false
        use_eso      = true
        domain       = "ixoearth"
        dns_endpoint = "devnet-cellnode.ixo.earth"
      }
      ixo_blocksync = {
        enabled      = true
        create_kv    = false
        use_eso      = true
        domain       = "ixoearth"
        dns_endpoint = "index.blocksync.devnet.ixo.earth"
      }
      ixo_blocksync_core = {
        enabled      = true
        create_kv    = false
        use_eso      = true
        domain       = "ixoearth"
        dns_endpoint = "ixo-blocksync-core.devnetkb.ixo.earth"
      }
      ixo_domain_indexer = {
        # Never create_kv (it would wipe it and mint a new SURREAL_PASS).
        enabled      = true
        create_kv    = false
        use_eso      = true
        domain       = "ixoearth"
        dns_endpoint = "domain-indexer.devnet.ixo.earth"
      }
      ixo_qi_agents_builder = {
        enabled       = true
        create_kv     = false
        use_eso       = true
        domain        = "ixoearth"
        dns_endpoint  = "qi-agents-builder.devnet.ixo.earth"
        storage_class = "standard"
        storage_size  = "40Gi"
      }
      ixo_matrix_recording_bot = {
        enabled    = false
        create_kv  = false
        domain     = "ixoearth"
        dns_prefix = "matrix-recording-bot"
      }
      ixo_feegrant_nest = {
        enabled      = true
        create_kv    = false
        use_eso      = true
        domain       = "ixoearth"
        dns_endpoint = "feegrant.devnet.ixo.earth"
      }
      ixo_did_resolver = {
        enabled      = true
        create_kv    = false
        domain       = "ixoearth"
        dns_endpoint = "resolver.devnet.ixo.earth"
      }
      ixo_faucet = {
        enabled      = true
        create_kv    = false # KV ixo_core/ixo-faucet came with the Vault restore; not in state, ESO only reads it
        use_eso      = true
        domain       = "ixoearth"
        dns_endpoint = "faucet.devnet.ixo.earth"
      }
      ixo_matrix_state_bot = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        dns_prefix    = "state.bot.mx"
        storage_class = "fast"
        storage_size  = "20Gi"
      }
      supamoto_matrix_state_bot = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      ixo_matrix_appservice_rooms = {
        enabled       = true
        create_kv     = false
        domain        = "ixoearth"
        dns_endpoint  = "rooms.bot.devmx.ixo.earth"
        storage_class = "standard"
        storage_size  = "10Gi"
      }
      supamoto_matrix_appservice_rooms = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      claims_credentials_ecs = {
        enabled      = true
        create_kv    = false # KV ixo_core/claims-credentials-ecs came with the Vault restore; ESO only reads it
        use_eso      = true
        domain       = "ixoearth"
        dns_endpoint = "ecs.credentials.devnet.ixo.earth"
      }
      claims_credentials_prospect = {
        enabled      = true
        create_kv    = false # KV ixo_core/claims-credentials-prospect came with the Vault restore; ESO only reads it
        use_eso      = true
        domain       = "ixoearth"
        dns_endpoint = "prospect.credentials.devnet.ixo.earth"
      }
      claims_credentials_carbon = {
        enabled      = true
        create_kv    = false # KV ixo_core/claims-credentials-carbon came with the Vault restore; ESO only reads it
        use_eso      = true
        domain       = "ixoearth"
        dns_endpoint = "carbon.credentials.devnet.ixo.earth"
      }
      claims_credentials_umuzi = {
        enabled      = true
        create_kv    = false # KV ixo_core/claims-credentials-umuzi came with the Vault restore; ESO only reads it
        use_eso      = true
        domain       = "ixoearth"
        dns_endpoint = "umuzi.credentials.devnet.ixo.earth"
      }
      claims_credentials_claimformprotocol = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      claims_credentials_did = {
        # Disabled: ixo_core/claims-credentials-did has no secrets on this Vault.
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "didoracle.credentials"
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
        enabled      = true
        create_kv    = false
        use_eso      = true
        domain       = "ixoearth"
        dns_endpoint = "ussd-supamoto.devnet.ixo.earth"
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
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "giza"
      }
      ixo_payments_nest = {
        enabled   = false
        create_kv = true
        domain    = "ixoearth"
      }
      ixo_message_relayer = {
        enabled      = true
        create_kv    = false
        use_eso      = true
        domain       = "ixoearth"
        dns_endpoint = "signx.devnet.ixo.earth"
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
        dns_prefix    = "bid.bot.mx"
        storage_class = "fast"
        storage_size  = "10Gi"
      }
      supamoto_matrix_bids_bot = {
        enabled   = false
        create_kv = false
        domain    = "ixoearth"
      }
      ixo_matrix_supamoto_bot = {
        enabled       = true
        create_kv     = false
        domain        = "ixoearth"
        storage_class = "standard"
        storage_size  = "10Gi"
        dns_endpoint  = "supamoto.bot.devmx.ixo.earth"
      }
      ixo_matrix_supamoto_onboarding_server = {
        enabled       = true
        create_kv     = false
        domain        = "ixoearth"
        storage_class = "standard"
        storage_size  = "10Gi"
        dns_endpoint  = "supamoto-onboarding.devmx.ixo.earth"
      }
      ixo_matrix_supamoto_claims_bot = {
        enabled       = true
        create_kv     = false
        domain        = "ixoearth"
        storage_class = "standard"
        storage_size  = "10Gi"
        dns_endpoint  = "supamoto.claims.bot.devmx.ixo.earth"
      }
      ixo_matrix_claims_bot = {
        enabled       = false
        create_kv     = false
        domain        = "ixoearth"
        dns_prefix    = "claim.bot.mx"
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
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "subscriptions.oracle"
      }
      ixo_subscriptions_oracle_bot = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "subscriptions.bot"
      }
      ixo_pathgen_oracle = {
        # Own RWO volume.
        enabled       = true
        create_kv     = false
        use_eso       = true
        domain        = "ixoearth"
        dns_endpoint  = "pathgen.oracle.devnet.ixo.earth"
        storage_class = "standard"
        storage_size  = "5Gi"
      }
      ixo_minerva_oracle = {
        enabled       = true
        create_kv     = false
        use_eso       = true
        domain        = "ixoearth"
        dns_endpoint  = "minerva.devnet.ixo.earth"
        storage_class = "standard"
        storage_size  = "10Gi"
      }
      ixo_minerva_livekit = {
        # A LiveKit Cloud agent worker, not a hostname-routed service - a second worker with the
        # same credentials joins the devnet worker pool and takes live jobs. Never run two copies.
        enabled      = true
        create_kv    = false
        use_eso      = true
        domain       = "ixoearth"
        dns_endpoint = "minerva-livekit.devnet.ixo.earth"
      }
      ixo_website_bot_oracle = {
        enabled       = true
        create_kv     = false
        use_eso       = true
        domain        = "ixoearth"
        dns_endpoint  = "website.bot.devnet.ixo.earth"
        storage_class = "standard"
        storage_size  = "10Gi"
      }
      ixo_jokes_oracle = {
        enabled    = false
        create_kv  = true
        domain     = "ixoearth"
        dns_prefix = "jokes.oracle"
      }
      ixo_domain_creator_oracle = {
        enabled       = true
        create_kv     = false
        use_eso       = true
        domain        = "ixoearth"
        dns_endpoint  = "domain-creator.devnet.ixo.earth"
        storage_class = "standard"
        storage_size  = "10Gi"
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
        enabled       = true
        create_kv     = false
        use_eso       = true
        domain        = "ixoearth"
        dns_endpoint  = "memory-engine.devnet.ixo.earth"
        storage_class = "standard"
        storage_size  = "40Gi"
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
  devnet = []
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
  devnet = ""
}

# No in-place major upgrade pending. Set explicitly so the auto-loaded terraform.tfvars can never
# supply one.
pg_upgrade = {}
