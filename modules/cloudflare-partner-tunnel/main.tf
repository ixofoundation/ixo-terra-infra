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

# ── Partner-side tunnel ───────────────────────────────────────────────────────
# The partner's server runs cloudflared with this tunnel's token.
# It connects outbound to Cloudflare and exposes their Postgres via TCP ingress.

resource "random_id" "supamoto_secret" {
  byte_length = 32
}

resource "cloudflare_tunnel" "supamoto" {
  account_id = var.cloudflare_account_id
  name       = "${var.partner_name}-postgres-${var.environment}"
  secret     = random_id.supamoto_secret.b64_std
}

# Exposes the partner's Postgres as a TCP service at <pg_cname>.<domain>.
# cloudflared on their server resolves the Docker Swarm service via overlay network DNS.
resource "cloudflare_tunnel_config" "supamoto" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.supamoto.id

  config {
    ingress_rule {
      hostname = "${var.pg_cname}.${var.domain}"
      service  = "tcp://${var.docker_postgres_service}:5432"

      origin_request {
        tcp_keep_alive         = "60s"
        tls_timeout            = "30s"
        connect_timeout        = "60s"
        keep_alive_connections = "200"
      }
    }
    warp_routing {
      enabled = false
    }
    # Catch-all
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# CNAME pointing <pg_cname>.<domain> → <tunnel-id>.cfargotunnel.com
resource "cloudflare_record" "supamoto_pg" {
  provider = cloudflare.dns
  zone_id  = var.cloudflare_zone_id
  name     = var.pg_cname
  content  = cloudflare_tunnel.supamoto.cname
  type     = "CNAME"
  proxied  = true
}

# ── Cloudflare Access (machine-to-machine auth) ───────────────────────────────

resource "cloudflare_access_application" "supamoto_pg" {
  account_id       = var.cloudflare_account_id
  name             = "${var.partner_name}-postgres-${var.environment}"
  domain           = "${var.pg_cname}.${var.domain}"
  type             = "self_hosted"
  session_duration = "24h"
}

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
# connections through Cloudflare to the partner's Postgres via the tunnel.
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
          args  = ["access", "tcp", "--hostname", "${var.pg_cname}.${var.domain}", "--url", "0.0.0.0:5432"]

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

# ClusterIP service — bots connect to <partner_name>-postgres.<namespace>.svc.cluster.local:5432
resource "kubernetes_service_v1" "supamoto_postgres" {
  metadata {
    name      = "${var.partner_name}-postgres"
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

# Tailscale LoadBalancer — exposes the partner's Postgres on the Tailnet for direct developer access.
resource "kubernetes_service_v1" "supamoto_postgres_tailscale" {
  metadata {
    name      = "${var.partner_name}-postgres-ts"
    namespace = kubernetes_namespace_v1.supamoto_tunnel.metadata[0].name
    annotations = {
      "tailscale.com/hostname" = "${var.partner_name}-postgres-${terraform.workspace}"
      "tailscale.com/expose"   = "true"
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
