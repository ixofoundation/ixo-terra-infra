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
  }
}

# Cloudflare side of the partner tunnel; the in-cluster side is cloudflare-partner-tunnel-client.

# ── Partner-side tunnel ───────────────────────────────────────────────────────
# The partner runs cloudflared with this tunnel's token to expose their Postgres.

resource "random_id" "supamoto_secret" {
  byte_length = 32
}

resource "cloudflare_tunnel" "supamoto" {
  account_id = var.cloudflare_account_id
  name       = "${var.partner_name}-postgres-${var.environment}"
  secret     = random_id.supamoto_secret.b64_std

  # The API never returns the secret; ignored so an imported tunnel is not replaced.
  lifecycle {
    ignore_changes = [secret]
  }
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
        tcp_keep_alive         = "1m0s" # Cloudflare normalises 60s to 1m0s
        tls_timeout            = "30s"
        connect_timeout        = "1m0s"
        keep_alive_connections = "200"
      }
    }
    warp_routing {
      enabled = var.warp_routing_enabled
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
