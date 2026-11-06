variable "cloudflare_api_token" {
  description = "CloudFlare Api Token" # TF_VAR_cloudflare_api_token
  default     = ""
}

variable "cloudlfare_supamoto_ecs_tunnel" {
  description = "Cloudflare API token with Account:Cloudflare Tunnel:Edit and Account:Zero Trust:Edit permissions (mainnet only)" # TF_VAR_cloudlfare_supamoto_ecs_tunnel
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID — found in the Cloudflare dashboard URL (dash.cloudflare.com/<account-id>/...)" # TF_VAR_cloudflare_account_id
  type        = string
  default     = ""
}

variable "cloudflare_ixo_earth_zone_id" {
  description = "Cloudflare Zone ID for ixo.earth — used to create the supamoto-pg CNAME record (mainnet only)" # TF_VAR_cloudflare_ixo_earth_zone_id
  type        = string
  default     = ""
}

variable "cloudflare_oracles_zone_id" {
  description = "CloudFlare Zone ID for oracles.work — required when oracles_cert_sync is enabled" # TF_VAR_cloudflare_oracles_zone_id
  default     = ""
}

variable "additional_manual_synthetic_monitoring_endpoints" {
  description = "Additional manual synthetic monitoring endpoints for each environment"
  type        = map(list(string))
}

variable "additional_manual_vault_watched_apps" {
  description = "Additional ArgoCD app names to watch per environment, for apps that use vault path syntax in their upstream helm chart but have create_kv = false"
  type        = map(list(string))
  default     = {}
}

# variables.tf
variable "storage_classes" {
  description = "Storage class mappings for different performance tiers"
  type        = map(string)

  validation {
    condition = alltrue([
      contains(keys(var.storage_classes), "standard"),
      contains(keys(var.storage_classes), "fast"),
      contains(keys(var.storage_classes), "bulk"),
      contains(keys(var.storage_classes), "shared")
    ])
    error_message = "storage_classes must contain all required keys: standard, fast, bulk, shared"
  }

  validation {
    condition     = length(setsubtract(keys(var.storage_classes), ["standard", "fast", "bulk", "shared"])) == 0
    error_message = "storage_classes can only contain these keys: standard, fast, bulk, shared"
  }
}

variable "dns_cutover_apps" {
  description = "Apps allowed to carry another environment's live hostname past the DNS guard in locals.tf. Set only in the var-file of a workspace taking that environment over."
  type        = list(string)
  default     = []
}

# IXO Infra Defaults
variable "environments" {
  description = "Environment specific configurations"
  type = map(object({
    cluster_firewall      = bool
    is_development        = optional(bool) # If true, this environment is treated as a development environment.
    aws_eks_public_access = optional(bool) # Defaults to is_development.
    aws_region            = string
    aws_iam_users         = list(string)
    rpc_url               = optional(string)
    ipfs_service_mapping  = optional(string)
    aws_vpc_config = object({
      nat_gateway_enabled = bool
      flow_logs_enabled   = bool
      retention_days      = number
      az_count            = number
    })
    aws_eks_config = optional(object({
      node_instance_types = list(string)
      desired_capacity    = number
      min_capacity        = number
      max_capacity        = number
      disk_size           = number
    }))
    # EKS auth mode (CONFIG_MAP, API_AND_CONFIG_MAP or API); null = unmanaged. Leaving CONFIG_MAP is one-way.
    aws_eks_authentication_mode = optional(string)
    # Cluster-admin access entries. Do not list the cluster creator (EKS adds it).
    aws_eks_cluster_admin_arns = optional(list(string), [])
    # AWS account ID; sets allowed_account_ids.
    aws_account_id = optional(string)
    vpc_cidr       = optional(string, "10.0.0.0/16")
    # Environment identity; each defaults to the workspace name.
    #   cloud_resource_name   AWS names that cannot be renamed (EKS cluster, IAM roles, SGs, VPC tag)
    #   global_resource_name  names in namespaces shared with other environments: GCS buckets,
    #                         GCP KMS key rings (never deletable), Cloudflare and Lambda names
    #   kubeconfig_name       the generated kubeconfig file; must be unique per workspace
    #   dns_segment           hostname segment; setting it also arms the cross-environment DNS guard
    #   vault_oidc_team       GitHub team slug segment for Vault OIDC (ixofoundation:<x>-devsecops)
    #   chart_tree            charts/<tree>/ in ixo-helm-charts
    #   network_name          the chain environment a workspace serves: Tailscale tags and device
    #                         names, the Workers DB tunnel name and pg CNAME
    cloud_resource_name  = optional(string)
    global_resource_name = optional(string)
    # The old workspace name, kept where it leaked into live values (tailscale operator hostname, faucet
    # PROJECT_NAME, claims-credentials NETWORK) so a workspace rename plans 0 changes. Drop it per site on purpose.
    legacy_workspace_name = optional(string)
    kubeconfig_name       = optional(string)
    dns_segment           = optional(string)
    vault_oidc_team       = optional(string)
    chart_tree            = optional(string)
    network_name          = optional(string)
    # Seal key of the snapshot's source env, for a restored Vault. Null = own gcp_kms_vault key.
    vault_seal = optional(object({
      key_ring   = string
      crypto_key = string
    }))
    vault_restored_from_snapshot = optional(bool, false)
    # Vault replicas; 1 during a snapshot restore.
    vault_replicas        = optional(number, 2)
    grafana_max_open_conn = optional(number, 1)
    # Grafana admin credentials from a Terraform-managed Secret.
    grafana_admin_secret = optional(bool, false)
    # AWS-only settings.
    #   aws_profile        profile in the generated kubeconfig's exec env
    #   aws_cli_path       command the kubeconfig execs for a token
    #   aws_default_tags   provider default_tags; empty = none
    #   loki_bucket_name   S3 bucket name override (S3 names are global)
    #   aws_subnet_cidrs   per-AZ subnets; null = /24s from vpc_cidr
    #   aws_service_ipv4_cidr  EKS service CIDR; null = EKS default
    #   aws_storage_class_parameters  extra EBS StorageClass parameters (immutable)
    #   aws_node_groups    node group sizes; null = single default group
    aws_profile                  = optional(string)
    aws_cli_path                 = optional(string, "/usr/local/bin/aws")
    aws_default_tags             = optional(map(string), {})
    loki_bucket_name             = optional(string)
    aws_service_ipv4_cidr        = optional(string)
    aws_storage_class_parameters = optional(map(string), {})
    aws_subnet_cidrs = optional(object({
      public  = list(string)
      private = list(string)
    }))
    # Node launch template: tags instances, root volumes and ENIs, but attaching it REPLACES
    # both node groups. Off by default.
    aws_node_launch_template = optional(bool, false)
    # Keep the original node groups. false (after the -lt groups took over) destroys them.
    aws_node_legacy_groups = optional(bool, true)
    aws_node_groups = optional(object({
      desired                  = number
      min                      = number
      max                      = number
      instance_types           = optional(list(string)) # Main group; defaults by is_development.
      on_demand_count          = optional(number, 0)
      on_demand_instance_types = optional(list(string), ["t3a.xlarge"])
    }))
    # ON_DEMAND database nodes on the launch template, one group per AZ (EBS is AZ-bound),
    # labelled and tainted ixo.world/pool=db. Needs aws_node_launch_template.
    aws_db_node_group = optional(object({
      per_az         = number
      instance_types = list(string)
    }))
    # Build the Postgres clusters as standbys of another env's pgBackRest repos (no schedules).
    # A cluster is a standby only while its bucket is set.
    pg_standby = optional(object({
      ixo_bucket    = optional(string)
      matrix_bucket = optional(string)
      gcs_key_file  = optional(string)
    }))
    # pgBackRest tuning for both Postgres clusters; unset renders pgBackRest's defaults.
    pg_backrest = optional(object({
      process_max   = optional(number)
      compress_type = optional(string)
    }))
    hyperlane = object({
      chain_names     = list(string)
      metadata_chains = list(string)
    })
    application_configs = map(object({
      enabled       = bool
      create_kv     = optional(bool, false)
      use_eso       = optional(bool, false) # If true, env secrets sync from Vault via external-secrets-operator (envFrom) instead of AVP <path:> placeholders.
      domain        = optional(string)
      dns_endpoint  = optional(string)
      dns_prefix    = optional(string)
      storage_class = optional(string)
      storage_size  = optional(string)
      # Optional per-env memory request/limit (falls back to the module default).
      memory_request = optional(string)
      memory_limit   = optional(string)
      # postgres_operator_crunchydata only: run the OpenTelemetry collector instead of the
      # pgmonitor exporter. Required before upgrading that environment to Postgres 18.
      use_otel = optional(bool, false)
      # postgres_operator_crunchydata only: Patroni synchronous_mode on the core cluster.
      # A commit is acknowledged only once the standby has the WAL, so a failover cannot
      # lose an acknowledged write — the failure mode behind the Sep 20 and Sep 25 2026
      # mainnet split-brains, where the primary kept committing locally after replication
      # was severed. Non-strict, so a dead or absent standby degrades to asynchronous
      # rather than blocking writes.
      #
      # Costs one intra-cluster round trip per commit; blocksync-core catch-up (~10
      # blocks/s) is the workload that feels it. Requires a healthy streaming standby, so
      # enable it per environment only after `patronictl list` shows one.
      enable_sync_replication = optional(bool, false)
      # Days of pgBackRest retention for the object-storage repositories (the core
      # cluster's repo1 and the matrix cluster's repo2). Time-based, so the window does not
      # depend on how many scheduled backups succeeded.
      #
      # Keep this below the bucket's lifecycle Delete age. pgBackRest expires only at the
      # end of a backup run rather than on a timer, so an equal value can let lifecycle
      # remove an object before the next run expires the backup that references it,
      # leaving the repository listing backups whose data no longer exists.
      backup_retention_days = optional(number, 350)
      # The matrix cluster's repo1 is a fixed-size PersistentVolume, so it is bounded by a
      # count of full backups rather than by age.
      matrix_backup_retention_full = optional(number, 2)
      # Size of that repo1 volume. Fixed at creation in practice (gp3 grows, never shrinks).
      matrix_repo1_storage_size = optional(string, "200Gi")
      # vault only: daily raft snapshot to a per-env GCS bucket.
      vault_snapshot_enabled = optional(bool, false)
      # Daily, offset from the 02:30 matrix media backup and the pgBackRest window.
      vault_snapshot_schedule = optional(string, "15 1 * * *")
      # Snapshot retention, enforced by the bucket lifecycle rule.
      vault_snapshot_retention_days = optional(number, 30)
      # Bucket location. Immutable: changing it replaces the bucket.
      vault_snapshot_location = optional(string, "EU")
      # SA held in the vault namespace's gcp-key-secret; granted create + read on the snapshot bucket.
      vault_snapshot_writer_sa_email = optional(string)
    }))
  }))

  validation { # Validation should be updated when new services are added that require storage
    condition = alltrue([
      for env_name, env_config in var.environments : alltrue([
        for app_name, app_config in env_config.application_configs :
        contains([
          "ixo-matrix-appservice-rooms",
          "ixo-matrix-state-bot",
          "ixo-matrix-bids-bot",
          "ixo-matrix-claims-bot",
          "observable-framework-builder"
          ], app_name) && app_config.enabled ? (
          app_config.storage_class != null && app_config.storage_class != "" &&
          app_config.storage_size != null && app_config.storage_size != ""
        ) : true
      ])
    ])
    error_message = <<-EOF
  The following applications require both storage_class and storage_size when enabled:
  - ixo-matrix-appservice-rooms
  - ixo-matrix-state-bot
  - ixo-matrix-bids-bot
  - ixo-matrix-claims-bot
  - observable-framework-builder
  EOF
  }

  validation {
    condition = alltrue([
      for env_name, env_config in var.environments : alltrue([
        for app_name, app_config in env_config.application_configs :
        contains([
          "ixo-matrix-appservice-rooms",
          "ixo-matrix-state-bot",
          "ixo-matrix-bids-bot",
          "ixo-matrix-claims-bot",
          "observable-framework-builder"
        ], app_name) && app_config.enabled && app_config.storage_class != null && app_config.storage_class != "" ?
        contains(["standard", "fast", "bulk", "shared"], app_config.storage_class) : true
      ])
    ])
    error_message = "storage_class values for matrix and observable applications must be one of: standard, fast, bulk, shared"
  }
}

variable "versions" {
  description = "Versions for all services"
  type        = map(string)
}

# Postgres major version upgrades, per workspace. pg_ixo and pg_matrix are global, so this
# is what scopes an upgrade to a single environment.
#
# Applied in three stages, as pg_upgrade requires the cluster to be stopped:
#   1. enabled = true                    creates the PGUpgrade object and the annotation
#                                        consenting to it. The cluster stays available.
#   2. shutdown = true                   stops the cluster and runs pg_upgrade. The cluster
#                                        is unavailable until stage 3. Wait for the
#                                        PGUpgrade status to report PGUpgradeCompleted.
#   3. cutover = true, shutdown = false  restarts the cluster on the new major version.
#
# Reverting stages 1 and 2 restores the previous version, provided transfer_method is
# "Copy", which leaves the old data directory intact.
variable "pg_upgrade" {
  description = "Per-workspace Postgres major version upgrade control. Omit a workspace for no upgrade."
  type = map(object({
    enabled              = optional(bool, false)
    shutdown             = optional(bool, false)
    cutover              = optional(bool, false)
    from_version         = number
    to_version           = number
    postgres_image_tag   = string
    pgbackrest_image_tag = string
    transfer_method      = optional(string, "Copy")
    # pg_cluster_name values in scope. Trim this to stage clusters one at a time.
    clusters = list(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for ws, cfg in var.pg_upgrade :
      contains(["Clone", "Copy", "CopyFileRange", "Link"], cfg.transfer_method)
    ])
    error_message = "pg_upgrade.transfer_method must be one of: Clone, Copy, CopyFileRange, Link."
  }

  validation {
    condition = alltrue([
      for ws, cfg in var.pg_upgrade : cfg.to_version > cfg.from_version
    ])
    error_message = "pg_upgrade.to_version must be greater than from_version."
  }

  validation {
    condition = alltrue([
      for ws, cfg in var.pg_upgrade : cfg.enabled if cfg.shutdown || cfg.cutover
    ])
    error_message = "pg_upgrade.shutdown and cutover require enabled = true."
  }
}

variable "gcp_project_ids" {
  description = "Project IDs for GCP"
  type        = map(string)
  default = {
    devnet  = "devsecops-415617"
    testnet = "devsecops-415617"
    mainnet = "devsecops-415617"
  }
}

variable "org" {
  type    = string
  default = "ixofoundation"
  validation {
    condition     = length(var.org) > 0
    error_message = "Organization name must be provided."
  }
}

variable "cloud_provider" {
  type        = string
  description = "Cloud provider to use for the kubernetes cluster and configurations involved"
  default     = "aws"
  validation {
    condition     = contains(["aws"], var.cloud_provider)
    error_message = "Invalid cloud provider. Must be: aws (Vultr removed in mainnet-final-cleanup)"
  }
}

variable "oidc_argo" {
  type = map(string)
  default = {
    clientId     = ""
    clientSecret = ""
  }
}

variable "oidc_vault" {
  type = map(string)
  default = {
    clientId     = ""
    clientSecret = ""
  }
}

variable "oidc_tailscale" {
  type = map(string)
  default = {
    clientId     = ""
    clientSecret = ""
  }
  description = "OIDC configuration for Tailscale. Required when Tailscale is enabled in any environment."
}

variable "pg_matrix" {
  type = object(
    {
      pg_cluster_name = string
      pg_image        = string
      pg_image_tag    = string
      pg_users = list(
        object(
          {
            username  = string
            databases = list(string)
            options   = optional(string)
          }
        )
      )
      namespace              = string
      pg_version             = number
      pgbackrest_image       = string
      pgbackrest_image_tag   = string
      pgmonitoring_image     = optional(string)
      pgmonitoring_image_tag = optional(string)
      # Database container resources.
      memory_request = optional(string, "750Mi")
      memory_limit   = optional(string, "1Gi")
    }
  )
}

variable "pg_ixo" {
  type = object(
    {
      pg_cluster_name = string
      pg_image        = string
      pg_image_tag    = string
      pg_users = list(
        object(
          {
            username  = string
            databases = list(string)
            options   = optional(string)
          }
        )
      )
      pg_version             = number
      pgbackrest_image       = string
      pgbackrest_image_tag   = string
      pgmonitoring_image     = optional(string)
      pgmonitoring_image_tag = optional(string)
    }
  )
}

variable "additional_prometheus_scrape_metrics" {
  type        = map(string)
  description = "Additional prometheus scrape metrics config in yml."
  default = {
    devnet  = null
    testnet = null
    mainnet = null
  }
}

variable "domains" {
  description = "Map of domain identifiers to actual domain names"
  type        = map(string)

  validation {
    condition     = length(var.domains) > 0
    error_message = "At least one domain mapping must be provided."
  }
}

variable "ixo_helm_chart_repository" {
  description = "Git repository URL for IXO Helm charts"
  type        = string
  default     = "https://github.com/ixofoundation/ixo-helm-charts"
}


variable "ixo_terra_infra_repository" {
  description = "Git repository URL for IXO Terraform infrastructure"
  type        = string
  default     = "https://github.com/ixofoundation/ixo-terra-infra"
}

variable "vault_core_mount" {
  description = "Vault mount path for core IXO services"
  type        = string
  default     = "ixo_core"
}

variable "ixo_ghost_mailgun_user" {
  description = "Mailgun SMTP username for Ghost email configuration (e.g., ghost@impacts.ixo.world)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ixo_ghost_mailgun_password" {
  description = "Mailgun SMTP password for Ghost email configuration"
  type        = string
  default     = ""
  sensitive   = true
}

# True only for the first argocd apply on a new cluster (before cert-manager exists);
# it turns off the argocd-server Certificate.
variable "argocd_bootstrap" {
  type    = bool
  default = false
}
