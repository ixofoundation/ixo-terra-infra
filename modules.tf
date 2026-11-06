# Cloudflare private network tunnels — connect ixo's K8s cluster to partner
# Postgres DBs via Cloudflare Zero Trust, with no inbound ports or VPN required.
# Mainnet only.

# The Cloudflare half of the supamoto tunnel. environment stays "mainnet" because the
# tunnel and Access app names carry it, and renaming the tunnel is not safe (the partner's cloudflared holds its token).
module "cloudflare_supamoto_tunnel_cf" {
  count  = terraform.workspace == "mainnet" ? 1 : 0
  source = "./modules/cloudflare-partner-tunnel-cf"

  cloudflare_account_id   = var.cloudflare_account_id
  cloudflare_api_token    = var.cloudlfare_supamoto_ecs_tunnel
  cloudflare_zone_id      = var.cloudflare_ixo_earth_zone_id
  environment             = "mainnet"
  partner_name            = "supamoto"
  pg_cname                = "supamoto-pg"
  docker_postgres_service = "matrix_postgres"
  warp_routing_enabled    = true

  providers = {
    cloudflare     = cloudflare
    cloudflare.dns = cloudflare.dns
  }
}

# AWS mainnet: client half only.
module "cloudflare_supamoto_tunnel_client" {
  count  = terraform.workspace == "mainnet" ? 1 : 0
  source = "./modules/cloudflare-partner-tunnel-client"

  namespace    = "supamoto-tunnel"
  partner_name = "supamoto"
  hostname     = "supamoto-pg.ixo.earth"
  # Only with the operator, else the Service never gets an LB.
  tailscale_hostname = var.environments[terraform.workspace].application_configs["tailscale"].enabled ? "supamoto-postgres-mainnet" : null
}

# Reverse direction of the partner tunnels: cloudflared runs in our cluster and
# exposes ixo-postgres (via pgbouncer) at workers-pg.ixo.earth so Cloudflare
# Workers can connect through Hyperdrive, authenticated with an Access service
# token. Currently used by the supamoto-bot worker (supamoto-bot db/user).
# Deployed on all environments; hostname is workers-pg.ixo.earth on mainnet and
# workers-pg-<env>.ixo.earth elsewhere.
module "cloudflare_workers_db_tunnel" {
  source = "./modules/cloudflare-workers-db-tunnel"

  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_zone_id    = var.cloudflare_ixo_earth_zone_id
  # network_name keeps the chain names and hostname (workers-pg-<network>.ixo.earth).
  environment           = local.network_name
  name                  = "workers"
  pg_cname              = terraform.workspace == "mainnet" ? "workers-pg" : "workers-pg-${coalesce(local.env.network_name, local.global_resource_name)}"
  namespace             = "workers-db-tunnel"
  postgres_service_host = "${var.pg_ixo.pg_cluster_name}-pgbouncer.${kubernetes_namespace_v1.ixo-postgres.metadata[0].name}.svc.cluster.local"
  # testnet: extra token added outside Terraform.
  additional_service_token_ids = lookup({
    testnet = ["0c921883-c64c-43e3-8a3d-8d580c0627c5"]
  }, terraform.workspace, [])

  providers = {
    cloudflare     = cloudflare
    cloudflare.dns = cloudflare.dns
  }
}

# AWS VPC module (only created when using AWS)
module "aws_vpc" {
  count  = var.cloud_provider == "aws" ? 1 : 0
  source = "./modules/aws/vpc"

  env_config     = var.environments[terraform.workspace].aws_vpc_config
  project_name   = var.org
  environment    = local.cloud_resource_name
  is_development = coalesce(var.environments[terraform.workspace].is_development, false)
  vpc_cidr       = local.env.vpc_cidr
  subnet_cidrs   = local.env.aws_subnet_cidrs
  availability_zones = [
    "${var.environments[terraform.workspace].aws_region}a",
    "${var.environments[terraform.workspace].aws_region}b",
    "${var.environments[terraform.workspace].aws_region}c"
  ]
}

module "kubernetes_cluster" {
  source         = "./modules/kubernetes_cluster"
  cloud_provider = var.cloud_provider
  depends_on     = [module.aws_vpc]
  aws = {
    cluster_name           = "ixo-cluster-${local.cloud_resource_name}"
    kubeconfig_name        = local.kubeconfig_name
    cluster_version        = var.versions["kubernetes_cluster"]
    region                 = var.environments[terraform.workspace].aws_region
    environment            = local.cloud_resource_name
    project_name           = var.org
    endpoint_public_access = coalesce(local.env.aws_eks_public_access, local.env.is_development, false)
    public_access_cidrs    = coalesce(local.env.aws_eks_public_access, local.env.is_development, false) ? ["0.0.0.0/0"] : [local.env.vpc_cidr]
    cluster_log_types      = var.environments[terraform.workspace].is_development != true ? ["api", "audit"] : ["api", "audit", "authenticator", "controllerManager", "scheduler"]
    # Spot across two instance families on development; ON_DEMAND on production.
    node_instance_types = coalesce(local.env.aws_node_groups != null ? local.env.aws_node_groups.instance_types : null, coalesce(var.environments[terraform.workspace].is_development, false) ? ["t3a.xlarge", "t3.xlarge"] : ["t3.medium"])
    node_ami_type       = "AL2023_x86_64_STANDARD"
    node_capacity_type  = coalesce(var.environments[terraform.workspace].is_development, false) ? "SPOT" : "ON_DEMAND"
    node_disk_size      = 50
    # aws_node_groups, where set, sizes the main group and adds an ON_DEMAND one.
    node_desired_capacity   = local.env.aws_node_groups != null ? local.env.aws_node_groups.desired : 3
    node_max_capacity       = local.env.aws_node_groups != null ? local.env.aws_node_groups.max : (var.environments[terraform.workspace].is_development != true ? 10 : 5)
    node_min_capacity       = local.env.aws_node_groups != null ? local.env.aws_node_groups.min : (var.environments[terraform.workspace].is_development != true ? 3 : 1)
    node_key_name           = null
    node_security_group_ids = null
    authentication_mode     = var.environments[terraform.workspace].aws_eks_authentication_mode
    cluster_admin_arns      = var.environments[terraform.workspace].aws_eks_cluster_admin_arns

    aws_profile              = local.env.aws_profile
    aws_cli_path             = local.env.aws_cli_path
    service_ipv4_cidr        = local.env.aws_service_ipv4_cidr
    storage_class_parameters = local.env.aws_storage_class_parameters
    # Launch template only when explicitly switched on (replaces the node groups).
    node_launch_template_tags     = local.env.aws_node_launch_template ? local.env.aws_default_tags : {}
    node_legacy_groups            = local.env.aws_node_legacy_groups
    on_demand_node_count          = local.env.aws_node_groups != null ? local.env.aws_node_groups.on_demand_count : 0
    on_demand_node_instance_types = local.env.aws_node_groups != null ? local.env.aws_node_groups.on_demand_instance_types : ["t3a.xlarge"]
    db_nodes_per_az               = local.env.aws_db_node_group != null ? local.env.aws_db_node_group.per_az : 0
    db_node_instance_types        = local.env.aws_db_node_group != null ? local.env.aws_db_node_group.instance_types : ["t3a.large"]
  }
}

module "argocd" {
  depends_on = [module.kubernetes_cluster]
  source     = "./modules/argocd"
  hostnames = {
    (terraform.workspace) = local.dns_for_environment[terraform.workspace]["prometheus_stack"]
  }
  github_client_id     = var.oidc_argo.clientId
  github_client_secret = var.oidc_argo.clientSecret
  argo_version         = var.versions["argocd"]
  org                  = var.org
  oidc_team_segment    = local.vault_oidc_team_segment
  # var.argocd_bootstrap: fresh-cluster deadlock, see variables.tf.
  cert_manager_enabled  = var.argocd_bootstrap ? false : var.environments[terraform.workspace].application_configs["cert_manager"].enabled
  vault_mount_path      = local.vault_mount_path
  image_updater_enabled = var.environments[terraform.workspace].application_configs["argocd_image_updater"].enabled
  git_repositories = [
    {
      name       = "ixofoundation"
      repository = var.ixo_helm_chart_repository
    }
  ]
  applications_helm = [
  ]
}

module "argocd_image_updater" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["argocd_image_updater"].enabled && local.live_overrides.argocd_image_updater_app ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "argocd-image-updater"
    namespace = module.argocd.argo_namespace
    helm = {
      isOci    = false
      chart    = "argocd-image-updater"
      revision = "1.2.4"
    }
    repository      = "https://argoproj.github.io/argo-helm"
    values_override = file("${local.helm_values_config_path}/argocd-image-updater-values.yml")
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "chromadb" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["chromadb"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "chromadb"
    namespace = kubernetes_namespace_v1.chromadb.metadata[0].name
    helm = {
      isOci    = false
      chart    = "chromadb"
      revision = var.versions["chromadb"]
    }
    repository = "https://amikos-tech.github.io/chromadb-chart/"
    values_override = templatefile("${local.helm_values_config_path}/chromadb-values.yml", {
      storage_class = var.storage_classes["bulk"]
      # Optional per-env image tag (versions.chromadb_image); empty = chart appVersion.
      api_version = lookup(var.versions, "chromadb_image", "")
      volume_size = coalesce(local.storage_size_for_environment[terraform.workspace]["chromadb"], "40Gi")
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "cert_manager" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["cert_manager"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "cert-manager"
    namespace = kubernetes_namespace_v1.cert_manager.metadata[0].name
    helm = {
      isOci             = false
      chart             = "cert-manager"
      revision          = var.versions["cert-manager"]
      ignoreDifferences = local.cert_manager_ignore_differences
    }
    repository      = "https://charts.jetstack.io"
    values_override = templatefile("${local.helm_values_config_path}/cert-manager-values.yml", {})
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "ingress_nginx" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["ingress_nginx"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "nginx-ingress-controller"
    namespace = kubernetes_namespace_v1.ingress_nginx.metadata[0].name
    helm = {
      isOci             = true
      chart             = "nginx-ingress"
      revision          = var.versions["nginx-ingress-controller"]
      ignoreDifferences = local.nginx_ignore_differences
    }
    repository = "ghcr.io/nginx/charts"
    values_override = templatefile("${local.helm_values_config_path}/f5-nginx-ingress-controller-values.yml",
      {
        host                      = local.dns_for_environment[terraform.workspace]["prometheus_stack"]
        enable_proxy_protocol     = false # non-AWS PROXY path, unused
        enable_aws_proxy_protocol = local.enable_aws_proxy_protocol
        lb_hostname               = "" # read only when enable_proxy_protocol
        aws_lb_tags               = join(",", [for k, v in local.env.aws_default_tags : "${k}=${v}"])
        set_real_ip_from          = local.enable_aws_proxy_protocol ? local.env.vpc_cidr : "0.0.0.0/0"
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "postgres_operator_crunchydata" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["postgres_operator_crunchydata"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = { # We use a fork of the main Operator helm chart to enable feature gates.
    name       = "postgres-operator"
    namespace  = kubernetes_namespace_v1.postgres_operator.metadata[0].name
    repository = "registry.developers.crunchydata.com/crunchydata"
    helm = {
      isOci    = true
      chart    = "pgo"
      revision = var.versions["postgres-operator"]
    }
    values_override = templatefile("${local.helm_values_config_path}/postgres-operator-values.yml", {})
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "redis" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["redis"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "redis"
    namespace = kubernetes_namespace_v1.redis.metadata[0].name
    helm = {
      isOci    = true
      chart    = "redis"
      revision = var.versions["redis"]
    }
    repository = "registry-1.docker.io/bitnamicharts"
    values_override = templatefile("${local.helm_values_config_path}/redis-values.yml", {
      storage_class     = local.storage_class_for_environment[terraform.workspace]["redis"]
      storage_size      = local.storage_size_for_environment[terraform.workspace]["redis"]
      redis_secret_name = kubernetes_secret_v1.redis_secret[0].metadata[0].name
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "surrealdb" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["surrealdb"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "surrealdb"
    namespace = kubernetes_namespace_v1.surrealdb.metadata[0].name
    helm = {
      isOci    = false
      chart    = "surrealdb"
      revision = var.versions["surrealdb"]
    }
    repository = "https://helm.surrealdb.com"
    values_override = templatefile("${local.helm_values_config_path}/surrealdb-values.yml", {
      storage_class      = local.storage_class_for_environment[terraform.workspace]["surrealdb"]
      storage_size       = local.storage_size_for_environment[terraform.workspace]["surrealdb"]
      surrealdb_password = random_password.surrealdb_password.result
      memory_request     = coalesce(var.environments[terraform.workspace].application_configs["surrealdb"].memory_request, "256Mi")
      memory_limit       = coalesce(var.environments[terraform.workspace].application_configs["surrealdb"].memory_limit, "512Mi")
      # EBS nodes span AZs, so a rolling update can stall on multi-attach.
      recreate = var.cloud_provider == "aws"
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "prometheus_stack" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["prometheus_stack"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "prometheus-stack"
    namespace = kubernetes_namespace_v1.prometheus_stack.metadata[0].name
    helm = {
      isOci             = false
      chart             = "kube-prometheus-stack"
      revision          = var.versions["prometheus-stack"]
      ignoreDifferences = local.prometheus_stack_ignore_differences
    }
    repository = "https://prometheus-community.github.io/helm-charts"
    values_override = templatefile("${local.helm_values_config_path}/prometheus.yml", {
      host                      = local.dns_for_environment[terraform.workspace]["prometheus_stack"]
      blackbox_targets          = yamlencode(local.synthetic_monitoring_endpoints)
      grafana_oidc_secret       = random_password.grafana_dex_oidc_secret.result
      dex_host                  = local.dns_for_environment[terraform.workspace]["dex"]
      org                       = var.org
      environment               = terraform.workspace
      oidc_team                 = local.vault_oidc_team_segment # GitHub team slug, same as Vault
      additional_scrape_metrics = var.additional_prometheus_scrape_metrics[terraform.workspace]
      pg_enable_otel            = local.pg_enable_otel
      storage_class             = var.storage_classes["bulk"]
      # Grafana SQLite pool size; see the [database] block in prometheus.yml.
      grafana_max_open_conn = local.env.grafana_max_open_conn
      grafana_admin_secret  = local.env.grafana_admin_secret ? kubernetes_secret_v1.grafana_admin[0].metadata[0].name : ""
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "dex" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["dex"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "dex"
    namespace = kubernetes_namespace_v1.dex.metadata[0].name
    helm = {
      isOci                    = false
      chart                    = "dex"
      revision                 = var.versions["dex"]
      ignoreDifferences        = local.edit_in_place_ignore_differences
      respectIgnoreDifferences = true
    }
    repository = "https://charts.dexidp.io"
    values_override = templatefile("${local.helm_values_config_path}/dex-values.yml",
      {
        vault_host           = local.dns_for_environment[terraform.workspace]["vault"]
        host                 = local.dns_for_environment[terraform.workspace]["dex"]
        github_client_id     = var.oidc_vault.clientId
        github_client_secret = var.oidc_vault.clientSecret
        vault_oidc_secret    = random_password.vault_dex_oidc_secret.result
        grafana_oidc_secret  = random_password.grafana_dex_oidc_secret.result
        grafana_host         = "${local.dns_for_environment[terraform.workspace]["prometheus_stack"]}/grafana"
        org                  = var.org
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "vault" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["vault"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "vault"
    namespace = kubernetes_namespace_v1.vault.metadata[0].name
    helm = {
      isOci             = false
      chart             = "vault"
      revision          = var.versions["vault"]
      ignoreDifferences = local.vault_ignore_differences
    }
    repository = "https://helm.releases.hashicorp.com"
    values_override = templatefile("${local.helm_values_config_path}/vault-values.yml",
      {
        project         = var.gcp_project_ids[terraform.workspace]
        key_ring        = local.env.vault_seal != null ? local.env.vault_seal.key_ring : module.gcp_kms_vault.key_ring_name     # a raft snapshot is barrier-encrypted under the SOURCE cluster's KMS key
        crypto_key      = local.env.vault_seal != null ? local.env.vault_seal.crypto_key : module.gcp_kms_vault.crypto_key_name # restoring under any other key reports success and leaves undecryptable data
        gcp_secret_name = module.gcp_kms_vault.gcp_key_secret_name
        replicas        = local.env.vault_replicas
        host            = local.dns_for_environment[terraform.workspace]["vault"]
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

# ServiceAccount the snapshot CronJob uses for Vault Kubernetes auth.
resource "kubernetes_service_account_v1" "vault_raft_snapshot" {
  count = local.vault_snapshot_enabled ? 1 : 0
  metadata {
    name      = "vault-raft-snapshot"
    namespace = kubernetes_namespace_v1.vault.metadata[0].name
  }
}

# Daily Vault raft snapshot to GCS. The initContainer saves it from vault-active and fails on
# an empty file; the main container uploads it with rclone. Retention is the bucket lifecycle rule.
resource "kubectl_manifest" "vault_raft_snapshot" {
  count      = local.vault_snapshot_enabled ? 1 : 0
  depends_on = [module.vault, module.vault_init, kubernetes_service_account_v1.vault_raft_snapshot]

  yaml_body = <<-YAML
    apiVersion: batch/v1
    kind: CronJob
    metadata:
      name: vault-raft-snapshot
      namespace: ${kubernetes_namespace_v1.vault.metadata[0].name}
      labels:
        app.kubernetes.io/part-of: ixo
    spec:
      schedule: "${var.environments[terraform.workspace].application_configs["vault"].vault_snapshot_schedule}"
      concurrencyPolicy: Forbid
      startingDeadlineSeconds: 3600
      successfulJobsHistoryLimit: 3
      failedJobsHistoryLimit: 3
      jobTemplate:
        spec:
          backoffLimit: 2
          template:
            metadata:
              labels:
                app.kubernetes.io/name: vault-raft-snapshot
                app.kubernetes.io/part-of: ixo
            spec:
              restartPolicy: Never
              serviceAccountName: ${kubernetes_service_account_v1.vault_raft_snapshot[0].metadata[0].name}
              initContainers:
                - name: snapshot
                  image: hashicorp/vault:${var.versions["vault_cli"]}
                  command: ["/bin/sh", "-ec"]
                  args:
                    - |
                      export VAULT_ADDR=http://vault-active.${kubernetes_namespace_v1.vault.metadata[0].name}.svc.cluster.local:8200
                      VAULT_TOKEN="$(vault write -field=token auth/kubernetes/login \
                        role=raft-snapshot \
                        jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token)"
                      export VAULT_TOKEN
                      # The token outlives the pod otherwise: its TTL is 15m and a failed
                      # upload would leave a snapshot-capable token valid in Vault.
                      trap 'vault token revoke -self >/dev/null 2>&1 || true' EXIT
                      out="/snapshot/vault-$(date -u +%Y%m%dT%H%M%SZ).snap"
                      vault operator raft snapshot save "$out"
                      if [ ! -s "$out" ]; then
                        echo "snapshot $out is empty - refusing to upload" >&2
                        exit 1
                      fi
                      ls -l "$out"
                  resources:
                    requests:
                      cpu: 50m
                      memory: 128Mi
                    # Request == limit: never overcommit node memory. The CLI streams the
                    # snapshot to disk, so this is flat in snapshot size.
                    limits:
                      memory: 128Mi
                  volumeMounts:
                    - name: snapshot
                      mountPath: /snapshot
              containers:
                - name: upload
                  image: rclone/rclone:1.75.1
                  args:
                    - move
                    - /snapshot
                    - "gcs:${google_storage_bucket.vault_snapshots[0].name}/vault/raft/"
                    - --include
                    - "*.snap"
                    - --stats=1m
                    - --stats-one-line
                    # rclone emits stats at INFO but defaults to NOTICE, so without this
                    # the job logs a single line and you cannot tell what it uploaded.
                    - --stats-log-level=NOTICE
                  env:
                    - name: RCLONE_CONFIG_GCS_TYPE
                      value: "google cloud storage"
                    - name: RCLONE_CONFIG_GCS_SERVICE_ACCOUNT_FILE
                      value: /gcp/key.json
                    # Bucket has uniform access, so rclone must not send an ACL.
                    - name: RCLONE_CONFIG_GCS_BUCKET_POLICY_ONLY
                      value: "true"
                  resources:
                    requests:
                      cpu: 20m
                      memory: 128Mi
                    limits:
                      memory: 128Mi
                  volumeMounts:
                    - name: snapshot
                      mountPath: /snapshot
                    - name: gcp
                      mountPath: /gcp
                      readOnly: true
              volumes:
                # Disk-backed, not memory: a memory-medium emptyDir counts against the
                # pod's memory limit, and the snapshot is far larger than it.
                - name: snapshot
                  emptyDir:
                    sizeLimit: 2Gi
                - name: gcp
                  secret:
                    # Same hand-placed service-account key the Vault server uses for its
                    # gcpckms seal. It must also have object-write on the snapshot bucket.
                    secretName: ${module.gcp_kms_vault.gcp_key_secret_name}
  YAML
}

module "vault_argocd_watcher" {
  depends_on = [module.argocd, module.vault]
  count      = var.environments[terraform.workspace].application_configs["vault_argocd_watcher"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name       = "vault-argocd-watcher"
    namespace  = kubernetes_namespace_v1.vault_argocd_watcher.metadata[0].name
    repository = "https://github.com/ixoworld/vault-argocd-watcher"
    path       = "chart/vault-argocd-watcher"
    values_override = templatefile(
      "${local.helm_values_config_path}/vault-argocd-watcher.yml",
      {
        vault_mount    = local.vault_mount_path
        argo_namespace = module.argocd.argo_namespace
        watched_apps   = local.vault_watched_apps
      }
    )
  }
  create_kv        = var.environments[terraform.workspace].application_configs["vault_argocd_watcher"].create_kv
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

# Loki on non-AWS clusters (filesystem storage).
module "loki" {
  depends_on = [module.argocd, module.prometheus_stack]
  count      = var.environments[terraform.workspace].application_configs["loki"].enabled && var.cloud_provider != "aws" ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "loki"
    namespace = kubernetes_namespace_v1.loki.metadata[0].name
    helm = {
      isOci             = false
      chart             = "loki"
      revision          = var.versions["loki"]
      ignoreDifferences = local.loki_ignore_differences
    }
    repository = "https://grafana.github.io/helm-charts"
    values_override = templatefile("${local.helm_values_config_path}/loki-values.yml",
      {
        service_account = indent(8, module.gcp_kms_loki.gcp_key_secret_data["key.json"])
        gcs_bucket      = google_storage_bucket.loki_logs_backups[0].name
        storage_class   = var.storage_classes["bulk"]
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

# Loki on AWS: chunks in S3 (main_loki_s3.tf) via IRSA.
module "loki_s3" {
  depends_on = [module.argocd, module.prometheus_stack]
  count      = local.loki_s3_enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "loki"
    namespace = kubernetes_namespace_v1.loki.metadata[0].name
    helm = {
      isOci             = false
      chart             = "loki"
      revision          = var.versions["loki"]
      ignoreDifferences = local.loki_ignore_differences
    }
    repository = "https://grafana.github.io/helm-charts"
    values_override = templatefile("${local.helm_values_config_path}/loki-values-s3.yml",
      {
        s3_bucket     = aws_s3_bucket.loki_chunks[0].bucket
        s3_region     = var.environments[terraform.workspace].aws_region
        loki_role_arn = aws_iam_role.loki_s3[0].arn
        storage_class = var.storage_classes["bulk"]
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "prometheus_blackbox_exporter" {
  depends_on = [module.argocd, module.prometheus_stack]
  count      = var.environments[terraform.workspace].application_configs["prometheus_blackbox_exporter"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "prometheus-blackbox-exporter"
    namespace = kubernetes_namespace_v1.prometheus_blackbox_exporter.metadata[0].name
    helm = {
      isOci    = false
      chart    = "prometheus-blackbox-exporter"
      revision = var.versions["prometheus-blackbox-exporter"]
    }
    repository      = "https://prometheus-community.github.io/helm-charts"
    values_override = templatefile("${local.helm_values_config_path}/prometheus-blackbox.yml", {})
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "tailscale" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["tailscale"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "tailscale"
    namespace = kubernetes_namespace_v1.tailscale.metadata[0].name
    helm = {
      isOci    = false
      chart    = "tailscale-operator"
      revision = var.versions["tailscale"]
    }
    repository = "https://pkgs.tailscale.com/helmcharts"
    values_override = templatefile("${local.helm_values_config_path}/tailscale-values.yml",
      {
        clientId     = var.oidc_tailscale.clientId
        clientSecret = var.oidc_tailscale.clientSecret
        environment  = local.network_name
        hostname     = "k8cluster-${replace(local.legacy_workspace_name, "_", "-")}"
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "matrix" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["matrix"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "matrix"
    namespace = kubernetes_namespace_v1.matrix.metadata[0].name
    helm = {
      isOci             = false
      chart             = "matrix-synapse"
      revision          = var.versions["matrix"]
      ignoreDifferences = local.matrix_ignore_differences
    }
    repository = "https://ananace.gitlab.io/charts"
    values_override = templatefile("${local.helm_values_config_path}/matrix-values.yml",
      {
        pg_host                 = "${var.pg_matrix.pg_cluster_name}-primary.matrix-synapse.svc.cluster.local"
        pg_username             = "synapse"
        pg_cluster_name         = var.pg_matrix.pg_cluster_name
        host                    = local.dns_for_environment[terraform.workspace]["matrix"]
        kv_mount                = var.vault_core_mount
        app_name                = "matrix"
        gcs_bucket_url          = google_storage_bucket.matrix_backups[0].url
        storage_class           = var.storage_classes["bulk"]
        media_storage_size      = coalesce(local.storage_size_for_environment[terraform.workspace]["matrix"], "100Gi")
        livekit_host            = local.dns_for_environment[terraform.workspace]["matrix_livekit"]
        matrix_whatsapp_enabled = var.environments[terraform.workspace].application_configs["ixo_matrix_whatsapp"].enabled
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

# Synapse media-store backup.
#
# This cannot live in the Synapse container: the ananace chart exposes no sidecar hook,
# and anything that walks the media store from inside shares Synapse's 2536Mi cgroup and
# OOMKills it - both `zip -r` and `gsutil rsync` did exactly that on devnet. As its own
# pod it gets its own cgroup, so a runaway backup can no longer take Synapse down.
#
# rclone is what makes this fit: it lists directory-by-directory instead of building a
# whole-tree index, so walking all ~61k files costs ~20Mi of heap and uploading ~90Mi
# (measured on devnet), against gsutil's 1.1Gi+. The image is a static binary, which also
# removes the ~1.1Gi google-cloud-cli apt install the old in-container backup needed.
#
# The media PVC is ReadWriteOnce - that is per-NODE, not per-pod - so podAffinity
# co-schedules this with Synapse and it mounts the same volume read-only. Verified
# working while Synapse held it. If Synapse's node is full the job is skipped, which
# shows up in CronJob status rather than failing silently.
#
# `copy` not `sync`, deliberately: copy never deletes, so a failed or empty mount cannot
# clear the backup. Synapse media is content-addressed and immutable, so the destination
# is always a superset of every earlier state.
resource "kubectl_manifest" "matrix_media_backup" {
  count      = var.environments[terraform.workspace].application_configs["matrix"].enabled ? 1 : 0
  depends_on = [module.matrix]

  yaml_body = <<-YAML
    apiVersion: batch/v1
    kind: CronJob
    metadata:
      name: matrix-media-backup
      namespace: ${kubernetes_namespace_v1.matrix.metadata[0].name}
      labels:
        app.kubernetes.io/part-of: ixo
    spec:
      schedule: "30 2 * * *"
      concurrencyPolicy: Forbid
      startingDeadlineSeconds: 3600
      successfulJobsHistoryLimit: 3
      failedJobsHistoryLimit: 3
      jobTemplate:
        spec:
          backoffLimit: 2
          template:
            metadata:
              labels:
                app.kubernetes.io/name: matrix-media-backup
                app.kubernetes.io/part-of: ixo
            spec:
              restartPolicy: Never
              affinity:
                podAffinity:
                  requiredDuringSchedulingIgnoredDuringExecution:
                    - topologyKey: kubernetes.io/hostname
                      labelSelector:
                        matchLabels:
                          app.kubernetes.io/name: matrix-synapse
                          app.kubernetes.io/component: synapse
              containers:
                - name: rclone
                  image: rclone/rclone:1.75.1
                  args:
                    - copy
                    - /data
                    - "gcs:${google_storage_bucket.matrix_backups[0].name}/matrix/data/"
                    - --transfers=4
                    - --checkers=8
                    - --buffer-size=0
                    - --use-mmap
                    # --fast-list: one flat listing instead of one List call per directory.
                    - --fast-list
                    - --stats=5m
                    - --stats-one-line
                    # Without this the job logs literally one line and you cannot tell
                    # progress or read a summary: rclone emits stats at INFO, but its
                    # default log level is NOTICE, so they are silently dropped.
                    - --stats-log-level=NOTICE
                  env:
                    - name: RCLONE_CONFIG_GCS_TYPE
                      value: "google cloud storage"
                    - name: RCLONE_CONFIG_GCS_SERVICE_ACCOUNT_FILE
                      value: /gcp/key.json
                    - name: RCLONE_CONFIG_GCS_OBJECT_ACL
                      value: private
                    - name: RCLONE_CONFIG_GCS_BUCKET_ACL
                      value: private
                  resources:
                    requests:
                      cpu: 20m
                      memory: 64Mi
                    # A ~100G store OOMs at 512Mi with --fast-list; incremental runs sit far below this.
                    limits:
                      memory: 1Gi
                  volumeMounts:
                    - name: media
                      mountPath: /data
                      readOnly: true
                    - name: gcp
                      mountPath: /gcp
                      readOnly: true
              volumes:
                - name: media
                  persistentVolumeClaim:
                    claimName: matrix-synapse
                    readOnly: true
                - name: gcp
                  secret:
                    secretName: gcp-key-secret
  YAML
}

module "matrix_livekit" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["matrix_livekit"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name       = "matrix-livekit"
    namespace  = kubernetes_namespace_v1.matrix_livekit.metadata[0].name
    repository = var.ixo_terra_infra_repository
    path       = "charts/matrix_livekit"
    values_override = templatefile("${local.helm_values_config_path}/matrix-livekit-values.yml", {
      host        = local.dns_for_environment[terraform.workspace]["matrix_livekit"]
      vault_mount = local.vault_mount_path
    })
  }
  argo_namespace = module.argocd.argo_namespace
  create_kv      = var.environments[terraform.workspace].application_configs["matrix_livekit"].create_kv
  kv_defaults = {
    LIVEKIT_URL    = ""
    LIVEKIT_KEY    = ""
    LIVEKIT_SECRET = ""
  }
  vault_mount_path = local.vault_mount_path
}

# Backs mainnet's common PVC (nfs storage class).
module "nfs_provisioner" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["nfs_provisioner"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name      = "nfs-provisioner"
    namespace = kubernetes_namespace_v1.nfs_provisioner.metadata[0].name
    helm = {
      isOci             = false
      chart             = "nfs-server-provisioner"
      revision          = "1.8.0"
      ignoreDifferences = local.nfs_provisioner_ignore_differences
    }
    repository = "https://kubernetes-sigs.github.io/nfs-ganesha-server-and-external-provisioner"
    values_override = templatefile("${local.helm_values_config_path}/nfs-values.yml", {
      storage_class = var.storage_classes["bulk"]
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "metrics_server" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["metrics_server"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name       = "metrics-server"
    namespace  = kubernetes_namespace_v1.metrics_server.metadata[0].name
    repository = "https://kubernetes-sigs.github.io/metrics-server/"
    helm = {
      isOci    = false
      chart    = "metrics-server"
      revision = var.versions["metrics-server"]
    }
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "descheduler" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["descheduler"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name       = "descheduler"
    namespace  = kubernetes_namespace_v1.descheduler.metadata[0].name
    repository = "https://kubernetes-sigs.github.io/descheduler/"
    helm = {
      isOci    = false
      chart    = "descheduler"
      revision = var.versions["descheduler"]
    }
    values_override = templatefile("${local.helm_values_config_path}/descheduler-values.yml", {})
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "external_secrets" {
  depends_on = [module.argocd, module.vault_init]
  count      = var.environments[terraform.workspace].application_configs["external_secrets"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name       = "external-secrets"
    namespace  = kubernetes_namespace_v1.external_secrets.metadata[0].name
    repository = "https://charts.external-secrets.io"
    helm = {
      isOci    = false
      chart    = "external-secrets"
      revision = var.versions["external-secrets"]
    }
    values_override = templatefile("${local.helm_values_config_path}/external-secrets-values.yml",
      {
        vault_mount = local.vault_mount_path
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "reloader" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["reloader"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name       = "reloader"
    namespace  = kubernetes_namespace_v1.reloader.metadata[0].name
    repository = "https://stakater.github.io/stakater-charts"
    helm = {
      isOci    = false
      chart    = "reloader"
      revision = var.versions["reloader"]
    }
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "vpa_crds" {
  depends_on = [module.argocd]
  count      = var.environments[terraform.workspace].application_configs["vpa"].enabled ? 1 : 0
  source     = "./modules/vpa"
}

module "vpa" {
  depends_on = [module.argocd, module.vpa_crds]
  count      = var.environments[terraform.workspace].application_configs["vpa"].enabled ? 1 : 0
  source     = "./modules/argocd_application"
  application = {
    name       = "vpa"
    namespace  = kubernetes_namespace_v1.vpa.metadata[0].name
    repository = "https://charts.fairwinds.com/stable"
    helm = {
      isOci    = false
      chart    = "vpa"
      revision = var.versions["vpa"]
      skipCrds = true
    }
    values_override = templatefile("${local.helm_values_config_path}/vpa-values.yml", {})
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "uptime_kuma" {
  count      = var.environments[terraform.workspace].application_configs["uptime_kuma"].enabled ? 1 : 0
  depends_on = [module.argocd]
  source     = "./modules/argocd_application"
  application = {
    name       = "uptime-kuma"
    namespace  = kubernetes_namespace_v1.uptime_kuma.metadata[0].name
    repository = "https://dirsigler.github.io/uptime-kuma-helm"
    helm = {
      isOci    = false
      chart    = "uptime-kuma"
      revision = var.versions["uptime-kuma"]
    }
    values_override = templatefile("${local.helm_values_config_path}/uptime-kuma-values.yml", {
      host          = local.dns_for_environment[terraform.workspace]["uptime_kuma"]
      storage_class = var.storage_classes["bulk"]
    })
    argo_namespace   = module.argocd.argo_namespace
    vault_mount_path = local.vault_mount_path
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "matrix_admin" {
  count      = var.environments[terraform.workspace].application_configs["matrix_admin"].enabled ? 1 : 0
  depends_on = [module.argocd, module.matrix]
  source     = "./modules/argocd_application"
  application = {
    name       = "matrix-admin"
    namespace  = kubernetes_namespace_v1.matrix.metadata[0].name
    repository = var.ixo_terra_infra_repository
    path       = "charts/matrix-admin"
    values_override = templatefile("${local.helm_values_config_path}/matrix-admin.yml",
      {
        matrix_host = local.dns_for_environment[terraform.workspace]["matrix"]
        app_name    = "matrix-admin"
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

# Creates a cert-manager issuer for the cluster.
module "cert-issuer" {
  count      = var.environments[terraform.workspace].application_configs["cert_manager"].enabled ? 1 : 0
  depends_on = [module.argocd, module.cert_manager]
  source     = "./modules/cert-manager"
}

# Issues and auto-renews wildcard Let's Encrypt certs for *.devnet.oracles.work
# and *.testnet.oracles.work, then syncs them to CloudFlare custom certificates
# so external CloudFlare Workers can serve HTTPS on those subdomains.
module "oracles_cert_sync" {
  count      = var.environments[terraform.workspace].application_configs["oracles_cert_sync"].enabled ? 1 : 0
  depends_on = [module.cert-issuer]
  source     = "./modules/oracles-cert-sync"

  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id   = var.cloudflare_oracles_zone_id
}

module "postgres-operator" { # Sets up Cluster Instances
  count        = var.environments[terraform.workspace].application_configs["postgres_operator_crunchydata"].enabled ? 1 : 0
  depends_on   = [module.argocd, module.postgres_operator_crunchydata]
  source       = "./modules/postgres-operator"
  network_name = local.network_name
  # try(): the Matrix cluster is absent where Matrix is disabled.
  clusters = [
    for c in [
      {
        # Matrix Postgres Cluster
        pg_cluster_name      = var.pg_matrix.pg_cluster_name
        pg_cluster_namespace = kubernetes_namespace_v1.matrix.metadata[0].name
        pg_image             = var.pg_matrix.pg_image
        pg_image_tag         = local.pg_upgrade_for[var.pg_matrix.pg_cluster_name].pg_image_tag
        pg_version           = local.pg_upgrade_for[var.pg_matrix.pg_cluster_name].pg_version
        pg_instances = templatefile("${local.postgres_operator_config_path}/matrix-postgres-instances.yml", {
          db_pool        = local.env.aws_db_node_group != null
          memory_request = var.pg_matrix.memory_request
          memory_limit   = var.pg_matrix.memory_limit
        })
        pg_users             = local.matrix_pg_users_yaml
        pg_usernames         = local.matrix_pg_users_usernames
        pgbackrest_image     = var.pg_matrix.pgbackrest_image
        pgbackrest_image_tag = local.pg_upgrade_for[var.pg_matrix.pg_cluster_name].pgbackrest_image_tag
        pgbackrest_repos = try(local.env.pg_standby.matrix_bucket, null) != null ? templatefile("${local.postgres_operator_config_path}/postgres-standby-repos.yml", {
          repo_name  = "repo2"
          gcs_bucket = local.env.pg_standby.matrix_bucket
          }) : templatefile("${local.postgres_operator_config_path}/matrix-postgres-backups-repos.yml", {
          repo1_storage = var.environments[terraform.workspace].application_configs["postgres_operator_crunchydata"].matrix_repo1_storage_size
          gcs_bucket    = try(google_storage_bucket.matrix_backups[0].name, "")
        })
        pgmonitoring_image     = var.pg_matrix.pgmonitoring_image
        pgmonitoring_image_tag = var.pg_matrix.pgmonitoring_image_tag
        initSql                = file("${path.root}/config/sql/matrix-init.sql")
        enable_pgbouncer       = false # Synapse manages its own connection pooling
        enable_otel            = local.pg_enable_otel
        retention_full         = local.pg_retention_full_matrix
        retention_type         = "count"
        gcs_repo2_bucket       = try(google_storage_bucket.matrix_backups[0].name, "")
        repo2_retention_type   = "time"
        repo2_retention_full   = local.pg_retention_days
        shutdown               = local.pg_upgrade_for[var.pg_matrix.pg_cluster_name].shutdown
        upgrade                = local.pg_upgrade_for[var.pg_matrix.pg_cluster_name].upgrade
        standby_repo           = try(local.env.pg_standby.matrix_bucket, null) != null ? "repo2" : ""
        gcs_key                = try(local.env.pg_standby.matrix_bucket, null) != null && try(local.env.pg_standby.gcs_key_file, null) != null ? file(local.env.pg_standby.gcs_key_file) : null
        db_pool                = local.env.aws_db_node_group != null
        process_max            = try(local.env.pg_backrest.process_max, null)
        compress_type          = try(local.env.pg_backrest.compress_type, null)
      },
      {
        # IXO Cluster
        pg_cluster_name      = var.pg_ixo.pg_cluster_name
        pg_cluster_namespace = kubernetes_namespace_v1.ixo-postgres.metadata[0].name
        pg_image             = var.pg_ixo.pg_image
        pg_image_tag         = local.pg_upgrade_for[var.pg_ixo.pg_cluster_name].pg_image_tag
        pg_version           = local.pg_upgrade_for[var.pg_ixo.pg_cluster_name].pg_version
        pg_instances = templatefile("${local.postgres_operator_config_path}/ixo-postgres-instances.yml", {
          storage_size  = var.environments[terraform.workspace].application_configs["postgres_operator_crunchydata"].storage_size
          enable_otel   = local.pg_enable_otel
          storage_class = var.storage_classes["standard"]
          db_pool       = local.env.aws_db_node_group != null
        })
        pg_users             = local.pg_users_yaml
        pg_usernames         = local.pg_users_usernames
        pgbackrest_image     = var.pg_ixo.pgbackrest_image
        pgbackrest_image_tag = local.pg_upgrade_for[var.pg_ixo.pg_cluster_name].pgbackrest_image_tag
        pgbackrest_repos = try(local.env.pg_standby.ixo_bucket, null) != null ? templatefile("${local.postgres_operator_config_path}/postgres-standby-repos.yml", {
          repo_name  = "repo1"
          gcs_bucket = local.env.pg_standby.ixo_bucket
          }) : templatefile("${local.postgres_operator_config_path}/ixo-postgres-backups-repos.yml",
          {
            gcs_bucket = google_storage_bucket.postgres_backups[0].name
          }
        )
        pgmonitoring_image     = var.pg_ixo.pgmonitoring_image
        pgmonitoring_image_tag = var.pg_ixo.pgmonitoring_image_tag
        initSql                = file("${path.root}/config/sql/ixo-init.sql")
        enable_pg_cron         = true
        pg_cron_database       = "firecrawl"
        enable_pgbouncer       = true
        enable_otel            = local.pg_enable_otel
        # Only this cluster: the matrix cluster runs a single instance and has no standby.
        enable_sync_replication = local.pg_enable_sync_replication
        retention_full          = local.pg_retention_days
        retention_type          = "time"
        shutdown                = local.pg_upgrade_for[var.pg_ixo.pg_cluster_name].shutdown
        upgrade                 = local.pg_upgrade_for[var.pg_ixo.pg_cluster_name].upgrade
        standby_repo            = try(local.env.pg_standby.ixo_bucket, null) != null ? "repo1" : ""
        gcs_key                 = try(local.env.pg_standby.ixo_bucket, null) != null && try(local.env.pg_standby.gcs_key_file, null) != null ? file(local.env.pg_standby.gcs_key_file) : null
        db_pool                 = local.env.aws_db_node_group != null
        process_max             = try(local.env.pg_backrest.process_max, null)
        compress_type           = try(local.env.pg_backrest.compress_type, null)
      }
    ] : c
    if c.pg_cluster_name != var.pg_matrix.pg_cluster_name ||
    var.environments[terraform.workspace].application_configs["matrix"].enabled ||
    # A Synapse standby can exist while Matrix itself is off.
    try(local.env.pg_standby.matrix_bucket, null) != null
  ]
  gcs_key = file("${path.root}/credentials.json")
}

# module "hyperlane_validator" {
#   source = "./modules/hyperlane"
#   count      = var.environments[terraform.workspace].application_configs["hyperlane_validator"].enabled ? 1 : 0
#   providers = {
#     aws = aws
#   }
#   aws_region = var.environments[terraform.workspace].aws_region
#   environment = terraform.workspace
#   chain_names = var.environments[terraform.workspace].hyperlane.chain_names
#   metadata_chains = var.environments[terraform.workspace].hyperlane.metadata_chains
# }

module "ixo_loki_logs" {
  count      = var.environments[terraform.workspace].application_configs["loki"].enabled ? 1 : 0
  depends_on = [module.argocd]
  source     = "./modules/loki_logs"

  matchNamespaces = [
    kubernetes_namespace_v1.ixo_core.metadata[0].name,
    kubernetes_namespace_v1.ingress_nginx.metadata[0].name,
    kubernetes_namespace_v1.matrix.metadata[0].name,
    kubernetes_namespace_v1.ixo-postgres.metadata[0].name,
    kubernetes_namespace_v1.falco_security.metadata[0].name
  ]
  name      = "ixo"
  namespace = "ixo-loki"
}

module "gcp_kms_vault" {
  source          = "./modules/gcp_kms"
  name            = "vault-${local.global_resource_name}"
  namespace       = "vault"
  rotation_period = "15552000s" # 180d
}

module "gcp_kms_matrix" {
  depends_on      = [module.matrix]
  source          = "./modules/gcp_kms"
  name            = "matrix-${local.global_resource_name}"
  namespace       = kubernetes_namespace_v1.matrix.metadata[0].name
  rotation_period = "15552000s" # 180d
}

module "gcp_kms_loki" {
  source          = "./modules/gcp_kms"
  name            = "loki-${local.global_resource_name}"
  namespace       = kubernetes_namespace_v1.loki.metadata[0].name
  rotation_period = "15552000s" # 180d
}

module "gcp_kms_core" {
  depends_on      = [module.argocd]
  source          = "./modules/gcp_kms"
  name            = "core-${local.global_resource_name}"
  namespace       = kubernetes_namespace_v1.ixo_core.metadata[0].name
  rotation_period = "15552000s" # 180d
}

module "vault_init" {
  depends_on = [module.argocd, module.vault]
  source     = "./modules/vault"

  init_params = {
    key_shares    = 3
    key_threshold = 2
  }
  name                  = "vault"
  namespace             = "vault"
  kube_config_path      = module.kubernetes_cluster.kubeconfig_path
  kubernetes_host       = module.kubernetes_cluster.endpoint
  argo_namespace        = module.argocd.argo_namespace
  argo_policy           = file("${path.root}/config/vault/argocd_policy.hcl")
  dex_host              = local.dns_for_environment[terraform.workspace]["dex"]
  oidc_client_secret    = random_password.vault_dex_oidc_secret.result
  vault_host            = local.dns_for_environment[terraform.workspace]["vault"]
  org                   = var.org
  raft_snapshot_enabled = local.vault_snapshot_enabled
  # A Vault that came up as a raft snapshot restore is already
  # initialized and `vault operator init` would fail the apply.
  vault_already_initialized = local.env.vault_restored_from_snapshot
  oidc_team_segment         = local.vault_oidc_team_segment
}

module "matrix_init" {
  depends_on = [module.argocd, module.matrix]
  source     = "./modules/matrix"

  kube_config_path = module.kubernetes_cluster.kubeconfig_path
  namespace        = kubernetes_namespace_v1.matrix.metadata[0].name
  vault_mount_path = local.vault_mount_path
}

module "ghost" {
  source     = "./modules/argocd_application"
  count      = var.environments[terraform.workspace].application_configs["ghost"].enabled ? 1 : 0
  depends_on = [module.argocd, kubernetes_secret_v1.ghost_mysql_secret]
  application = {
    name       = "ghost"
    namespace  = kubernetes_namespace_v1.ghost.metadata[0].name
    repository = "registry-1.docker.io/bitnamicharts"
    helm = {
      isOci                    = true
      chart                    = "ghost"
      revision                 = var.versions["ghost"]
      ignoreDifferences        = local.edit_in_place_ignore_differences
      respectIgnoreDifferences = true
    }
    values_override = templatefile("${local.helm_values_config_path}/ghost-values.yml", {
      host                = local.dns_for_environment[terraform.workspace]["ghost"]
      ghost_password      = random_password.ghost_password.result
      ghost_smtp_user     = var.ixo_ghost_mailgun_user
      ghost_smtp_password = var.ixo_ghost_mailgun_password
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
  create_kv        = var.environments[terraform.workspace].application_configs["ghost"].create_kv
}

module "neo4j" { # TODO move to its own sub-module as it requires a Ingress resource.
  count  = var.environments[terraform.workspace].application_configs["neo4j"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "neo4j"
    namespace  = kubernetes_namespace_v1.neo4j.metadata[0].name
    repository = "https://neo4j.github.io/helm-charts"
    helm = {
      isOci    = false
      chart    = "neo4j"
      revision = var.versions["neo4j"]
    }
    values_override = templatefile("${local.helm_values_config_path}/neo4j.yml", {
      storage_class = var.storage_classes["fast"]
      storage_size  = "20Gi"
      org           = var.org
      password      = random_password.neo4j_password.result
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
}

module "external_dns_cloudflare" {
  source = "./modules/argocd_application"
  application = {
    name       = "external-dns-cloudflare"
    namespace  = kubernetes_namespace_v1.external_dns_cloudflare.metadata[0].name
    repository = "https://kubernetes-sigs.github.io/external-dns/"
    helm = {
      isOci    = false
      chart    = "external-dns"
      revision = var.versions["external-dns"]
    }
    values_override = templatefile("${local.helm_values_config_path}/external-dns-values-cloudflare.yml",
      {
        CF_API_TOKEN = var.cloudflare_api_token
      }
    )
  }
  argo_namespace   = module.argocd.argo_namespace
  create_kv        = var.environments[terraform.workspace].application_configs["external_dns"].create_kv
  vault_mount_path = null
}

module "falco_security" {
  count      = var.environments[terraform.workspace].application_configs["falco_security"].enabled ? 1 : 0
  depends_on = [module.argocd]
  source     = "./modules/argocd_application"
  application = {
    name       = "falco-security"
    namespace  = kubernetes_namespace_v1.falco_security.metadata[0].name
    repository = "https://falcosecurity.github.io/charts"
    helm = {
      isOci    = false
      chart    = "falco"
      revision = var.versions["falco_security"]
    }
    values_override = templatefile("${local.helm_values_config_path}/falco-values.yml", {
      storage_class = var.environments[terraform.workspace].application_configs["falco_security"].storage_class
      storage_size  = var.environments[terraform.workspace].application_configs["falco_security"].storage_size
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
  create_kv        = var.environments[terraform.workspace].application_configs["falco_security"].create_kv
}

resource "random_password" "mautrix_slack_as_token" {
  length  = 64
  special = false
  numeric = false
  lower   = true
  upper   = true
}

resource "random_password" "mautrix_slack_hs_token" {
  length  = 64
  special = false
  numeric = false
  lower   = true
  upper   = true
}

resource "random_password" "matrix_whatsapp_as_token" {
  count   = var.environments[terraform.workspace].application_configs["ixo_matrix_whatsapp"].enabled ? 1 : 0
  length  = 64
  special = false
  numeric = false
  lower   = true
  upper   = true
}

resource "random_password" "matrix_whatsapp_hs_token" {
  count   = var.environments[terraform.workspace].application_configs["ixo_matrix_whatsapp"].enabled ? 1 : 0
  length  = 64
  special = false
  numeric = false
  lower   = true
  upper   = true
}

module "searxng" {
  count  = var.environments[terraform.workspace].application_configs["searxng"].enabled ? 1 : 0
  source = "./modules/argocd_application"
  application = {
    name       = "searxng"
    namespace  = kubernetes_namespace_v1.searxng[0].metadata[0].name
    repository = var.ixo_helm_chart_repository # TODO fork and update to our own repository as it is not maintainted.
    path       = "charts/${local.chart_tree}/ixoworld/searxng"
    isHelm     = false
    values_override = templatefile("${local.helm_values_config_path}/searxng-values.yml", {
      vault_mount = local.vault_mount_path
    })
  }
  argo_namespace   = module.argocd.argo_namespace
  vault_mount_path = local.vault_mount_path
  create_kv        = var.environments[terraform.workspace].application_configs["searxng"].create_kv
  kv_defaults = {
    SECRET_KEY = ""
  }
}

module "nomic_embedding" {
  count  = var.environments[terraform.workspace].application_configs["nomic_embedding"].enabled ? 1 : 0
  source = "./modules/nomic_embedding"

  enable_deployment = local.live_overrides.nomic_deployment

  application_name = "nomic-embedding"
  namespace        = "nomic-embedding"
  create_namespace = true
  llama_batch_size = 2048
  # Backend selection (corrected for actual model availability):
  # - "llama_cpp": Exact model nomic-embed-text-v2-moe, 800MB-1.2GB memory (RECOMMENDED)
  # - "vllm": vLLM V1 with native embedding support, 2-3GB memory  
  # Note: Ollama does NOT have the V2 MoE model, only the older V1.5
  backend = "llama_cpp"

  # Resource configuration optimized for your 1-2GB constraint
  # llama.cpp backend will use these values automatically

  # Storage configuration (for model caching)
  storage_class = var.storage_classes["bulk"]

  # External access configuration
  enable_ingress = local.live_overrides.nomic_ingress
  host           = local.dns_for_environment[terraform.workspace]["nomic_embedding"]
  enable_tls     = true

  ingress_annotations = {
    "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
    "nginx.org/proxy-read-timeout"              = "300"
    "nginx.org/proxy-send-timeout"              = "300"
    "acme.cert-manager.io/http01-edit-in-place" = "true"
  }
}