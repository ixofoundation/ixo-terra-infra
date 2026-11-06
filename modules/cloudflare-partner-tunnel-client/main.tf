terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

# In-cluster cloudflared access proxy and ClusterIP service for the partner tunnel.

resource "kubernetes_namespace_v1" "partner_tunnel" {
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
    namespace = kubernetes_namespace_v1.partner_tunnel.metadata[0].name
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
          image = "cloudflare/cloudflared:${var.cloudflared_version}"
          args  = ["access", "tcp", "--hostname", var.hostname, "--url", "0.0.0.0:5432"]

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
resource "kubernetes_service_v1" "partner_postgres" {
  metadata {
    name      = "${var.partner_name}-postgres"
    namespace = kubernetes_namespace_v1.partner_tunnel.metadata[0].name
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
resource "kubernetes_service_v1" "partner_postgres_tailscale" {
  count = var.tailscale_hostname != null ? 1 : 0

  metadata {
    name      = "${var.partner_name}-postgres-ts"
    namespace = kubernetes_namespace_v1.partner_tunnel.metadata[0].name
    annotations = {
      "tailscale.com/hostname" = var.tailscale_hostname
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
