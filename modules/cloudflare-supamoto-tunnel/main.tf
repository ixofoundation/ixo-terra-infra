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

# ── Supamoto-side tunnel ──────────────────────────────────────────────────────
# Supamoto's Windows server runs cloudflared with this tunnel's token.
# It connects outbound to Cloudflare and exposes their Postgres via TCP ingress.
# No changes are needed on their server — cloudflared polls for config updates.

resource "random_id" "supamoto_secret" {
  byte_length = 32
}

resource "cloudflare_tunnel" "supamoto" {
  account_id = var.cloudflare_account_id
  name       = "supamoto-postgres-${var.environment}"
  secret     = random_id.supamoto_secret.b64_std
}

# Exposes Supamoto's Postgres as a TCP service at supamoto-pg.ixo.earth.
# cloudflared on their server resolves matrix_postgres via Docker Swarm DNS
# (it runs inside the matrix_default overlay network).
resource "cloudflare_tunnel_config" "supamoto" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.supamoto.id

  config {
    ingress_rule {
      hostname = "supamoto-pg.${var.domain}"
      service  = "tcp://matrix_postgres:5432"
    }
    # Catch-all
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# CNAME pointing supamoto-pg.ixo.earth → <tunnel-id>.cfargotunnel.com
resource "cloudflare_record" "supamoto_pg" {
  provider = cloudflare.dns
  zone_id  = var.cloudflare_zone_id
  name     = "supamoto-pg"
  content  = cloudflare_tunnel.supamoto.cname
  type     = "CNAME"
  proxied  = true
}

# ── Cloudflare Access (machine-to-machine auth) ───────────────────────────────
# Restricts access to the TCP hostname to our K8s service token only.

resource "cloudflare_access_application" "supamoto_pg" {
  account_id       = var.cloudflare_account_id
  name             = "supamoto-postgres-${var.environment}"
  domain           = "supamoto-pg.${var.domain}"
  type             = "self_hosted"
  session_duration = "24h"
}

# Service token used by the ixo K8s cloudflared access proxy to authenticate.
resource "cloudflare_access_policy" "bypass" {
  application_id = cloudflare_access_application.supamoto_pg.id
  account_id     = var.cloudflare_account_id
  name           = "bypass-internal"
  precedence     = 1
  decision       = "bypass"

  include {
    everyone = true
  }
}

# ── Kubernetes resources ──────────────────────────────────────────────────────

resource "kubernetes_namespace_v1" "supamoto_tunnel" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# TCP access proxy — listens on 0.0.0.0:5432 inside the cluster and forwards
# connections through Cloudflare to Supamoto's Postgres via the tunnel.
resource "kubernetes_deployment_v1" "cloudflared" {
  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace_v1.supamoto_tunnel.metadata[0].name
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
        dns_policy = "None"
        dns_config {
          nameservers = ["1.1.1.1", "8.8.8.8"]
        }

        container {
          name  = "cloudflared"
          image = "cloudflare/cloudflared:latest"
          args  = ["access", "tcp", "--hostname", "supamoto-pg.${var.domain}", "--url", "0.0.0.0:5432"]

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
            tcp_socket {
              port = 5432
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

# ClusterIP service — bots connect to supamoto-postgres.supamoto-tunnel.svc.cluster.local:5432
resource "kubernetes_service_v1" "supamoto_postgres" {
  metadata {
    name      = "supamoto-postgres"
    namespace = kubernetes_namespace_v1.supamoto_tunnel.metadata[0].name
  }

  spec {
    selector = {
      app = "cloudflared"
    }

    port {
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Tailscale LoadBalancer — exposes Supamoto's Postgres on the Tailnet for direct developer access.
# Tailscale operator creates a proxy pod; connect from any Tailnet device as:
#   psql postgresql://user:pass@supamoto-postgres-<environment>/db
resource "kubernetes_service_v1" "supamoto_postgres_tailscale" {
  metadata {
    name      = "supamoto-postgres-ts"
    namespace = kubernetes_namespace_v1.supamoto_tunnel.metadata[0].name
    annotations = {
      "tailscale.com/hostname" = "supamoto-postgres-${terraform.workspace}"
      "tailscale.com/expose" = "true"
    }
  }

  spec {
    selector = {
      app = "cloudflared"
    }

    port {
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }

    type                = "LoadBalancer"
    load_balancer_class = "tailscale"
  }
}
