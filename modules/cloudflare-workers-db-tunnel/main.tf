terraform {
  required_providers {
    cloudflare = {
      source                = "cloudflare/cloudflare"
      version               = "~> 4.0"
      configuration_aliases = [cloudflare.dns]
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

# ── Cluster-side tunnel ───────────────────────────────────────────────────────
# The reverse of cloudflare-partner-tunnel: cloudflared runs *inside our* K8s
# cluster and exposes ixo-postgres (via pgbouncer) as a TCP service at
# <pg_cname>.<domain>, so Cloudflare Workers can reach it through Hyperdrive.

resource "random_id" "tunnel_secret" {
  byte_length = 32
}

resource "cloudflare_tunnel" "workers_db" {
  account_id = var.cloudflare_account_id
  name       = "${var.name}-postgres-${var.environment}"
  secret     = random_id.tunnel_secret.b64_std
}

resource "cloudflare_tunnel_config" "workers_db" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.workers_db.id

  config {
    ingress_rule {
      hostname = "${var.pg_cname}.${var.domain}"
      service  = "tcp://${var.postgres_service_host}:${var.postgres_port}"
    }
    # Catch-all
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# CNAME pointing <pg_cname>.<domain> → <tunnel-id>.cfargotunnel.com
resource "cloudflare_record" "workers_pg" {
  provider = cloudflare.dns
  zone_id  = var.cloudflare_zone_id
  name     = var.pg_cname
  content  = cloudflare_tunnel.workers_db.cname
  type     = "CNAME"
  proxied  = true
}

# ── Cloudflare Access (service-token auth for Hyperdrive) ─────────────────────
# Unlike the partner tunnels (bypass/everyone), our own DB endpoint is locked to
# a service token. Hyperdrive presents the client ID/secret on every connection;
# anything without the token is rejected at the Cloudflare edge.

resource "cloudflare_access_application" "workers_pg" {
  account_id       = var.cloudflare_account_id
  name             = "${var.name}-postgres-${var.environment}"
  domain           = "${var.pg_cname}.${var.domain}"
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_access_service_token" "hyperdrive" {
  account_id = var.cloudflare_account_id
  name       = "${var.name}-hyperdrive-${var.environment}"
}

resource "cloudflare_access_policy" "service_token_only" {
  application_id = cloudflare_access_application.workers_pg.id
  account_id     = var.cloudflare_account_id
  name           = "hyperdrive-service-token"
  precedence     = 1
  decision       = "non_identity"

  include {
    service_token = [cloudflare_access_service_token.hyperdrive.id]
  }
}

# ── Kubernetes resources ──────────────────────────────────────────────────────

resource "kubernetes_namespace_v1" "workers_db_tunnel" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "kubernetes_secret_v1" "tunnel_token" {
  metadata {
    name      = "cloudflared-tunnel-token"
    namespace = kubernetes_namespace_v1.workers_db_tunnel.metadata[0].name
  }

  data = {
    token = cloudflare_tunnel.workers_db.tunnel_token
  }
}

# Runs the tunnel itself (outbound-only) — needs cluster DNS to resolve the
# pgbouncer service, so no custom dns_policy here.
resource "kubernetes_deployment_v1" "cloudflared" {
  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace_v1.workers_db_tunnel.metadata[0].name
    labels = {
      app = "cloudflared"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "cloudflared"
      }
    }

    template {
      metadata {
        labels = {
          app = "cloudflared"
        }
      }

      spec {
        container {
          name  = "cloudflared"
          image = "cloudflare/cloudflared:latest"
          args  = ["tunnel", "--no-autoupdate", "--metrics", "0.0.0.0:2000", "run"]

          env {
            name = "TUNNEL_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.tunnel_token.metadata[0].name
                key  = "token"
              }
            }
          }

          resources {
            requests = {
              cpu    = "10m"
              memory = "64Mi"
            }
            limits = {
              memory = "128Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/ready"
              port = 2000
            }
            failure_threshold     = 3
            initial_delay_seconds = 10
            period_seconds        = 10
          }
        }
      }
    }
  }
}
