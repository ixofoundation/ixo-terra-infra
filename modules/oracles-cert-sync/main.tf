terraform {
  required_providers {
    kubectl = {
      source = "alekc/kubectl"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

# CloudFlare API token secret in cert-manager namespace — used by both the
# ClusterIssuer (DNS-01 challenge) and the cert-sync CronJob (cert upload).
resource "kubernetes_secret_v1" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token-oracles"
    namespace = "cert-manager"
  }
  data = {
    api-token = var.cloudflare_api_token
  }
  type = "Opaque"
}

# ClusterIssuer using CloudFlare DNS-01.
# cert-manager will create/delete _acme-challenge TXT records automatically.
resource "kubectl_manifest" "letsencrypt_cloudflare_issuer" {
  depends_on = [kubernetes_secret_v1.cloudflare_api_token]
  yaml_body  = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-cloudflare
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${var.acme_email}
        privateKeySecretRef:
          name: letsencrypt-cloudflare-account-key
        solvers:
          - dns01:
              cloudflare:
                apiTokenSecretRef:
                  name: cloudflare-api-token-oracles
                  key: api-token
  YAML
}

# Wildcard certificate for *.devnet.oracles.work.
# cert-manager stores the issued cert in secret oracles-devnet-wildcard-tls
# and auto-renews it ~30 days before expiry.
resource "kubectl_manifest" "devnet_certificate" {
  depends_on = [kubectl_manifest.letsencrypt_cloudflare_issuer]
  yaml_body  = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: oracles-devnet-wildcard
      namespace: cert-manager
    spec:
      secretName: oracles-devnet-wildcard-tls
      issuerRef:
        name: letsencrypt-cloudflare
        kind: ClusterIssuer
      dnsNames:
        - "*.devnet.oracles.work"
  YAML
}

# Wildcard certificate for *.testnet.oracles.work.
resource "kubectl_manifest" "testnet_certificate" {
  depends_on = [kubectl_manifest.letsencrypt_cloudflare_issuer]
  yaml_body  = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: oracles-testnet-wildcard
      namespace: cert-manager
    spec:
      secretName: oracles-testnet-wildcard-tls
      issuerRef:
        name: letsencrypt-cloudflare
        kind: ClusterIssuer
      dnsNames:
        - "*.testnet.oracles.work"
  YAML
}

# Python sync script — uses only the standard library (urllib, json, ssl, hashlib)
# so no runtime package installation is needed regardless of filesystem restrictions.
resource "kubernetes_config_map_v1" "cert_sync_script" {
  metadata {
    name      = "oracles-cert-sync-script"
    namespace = "cert-manager"
  }
  data = {
    "sync.py" = <<-SCRIPT
      #!/usr/bin/env python3
      import hashlib
      import json
      import os
      import ssl
      import sys
      import urllib.error
      import urllib.request

      CF_API_TOKEN = os.environ["CF_API_TOKEN"]
      CF_ZONE_ID   = os.environ["CF_ZONE_ID"]

      if not CF_API_TOKEN or not CF_ZONE_ID:
          print("ERROR: CF_API_TOKEN and CF_ZONE_ID must be set.")
          sys.exit(1)

      BASE_URL = f"https://api.cloudflare.com/client/v4/zones/{CF_ZONE_ID}"

      def cf_request(method, path, data=None):
          url     = f"{BASE_URL}{path}"
          headers = {
              "Authorization": f"Bearer {CF_API_TOKEN}",
              "Content-Type":  "application/json",
          }
          body = json.dumps(data).encode() if data is not None else None
          req  = urllib.request.Request(url, data=body, headers=headers, method=method)
          try:
              with urllib.request.urlopen(req) as resp:
                  return json.loads(resp.read())
          except urllib.error.HTTPError as e:
              return json.loads(e.read())

      def get_fingerprint(cert_pem):
          der = ssl.PEM_cert_to_DER_cert(cert_pem)
          return hashlib.sha256(der).hexdigest()

      def sync_cert(env_name):
          secret_path = f"/certs/{env_name}"
          domain      = f"*.{env_name}.oracles.work"
          cert_file   = f"{secret_path}/tls.crt"
          key_file    = f"{secret_path}/tls.key"

          if not os.path.exists(cert_file) or not os.path.exists(key_file):
              print(f"[{env_name}] Certificate secret not yet available — skipping (cert-manager may still be issuing it)")
              return True

          cert_pem    = open(cert_file).read()
          key_pem     = open(key_file).read()
          fingerprint = get_fingerprint(cert_pem)

          print(f"[{env_name}] Checking CloudFlare for {domain} (fingerprint: {fingerprint})...")

          response = cf_request("GET", "/custom_certificates")
          if not response.get("success"):
              err = response.get("errors", [{}])[0]
              print(f"[{env_name}] CloudFlare error — code {err.get('code')}: {err.get('message')}")
              return False

          existing = next(
              (c for c in response.get("result", []) if domain in c.get("hosts", [])),
              None,
          )
          payload = {"certificate": cert_pem, "private_key": key_pem}

          if existing is None:
              print(f"[{env_name}] No existing certificate found — creating...")
              result = cf_request("POST", "/custom_certificates", {**payload, "bundle_method": "ubiquitous"})
          elif existing.get("fingerprint", "").replace(":", "").lower() != fingerprint:
              print(f"[{env_name}] Fingerprint changed — updating...")
              result = cf_request("PATCH", f"/custom_certificates/{existing['id']}", payload)
          else:
              print(f"[{env_name}] Certificate is up to date.")
              return True

          if not result.get("success"):
              err = result.get("errors", [{}])[0]
              print(f"[{env_name}] CloudFlare error — code {err.get('code')}: {err.get('message')}")
              return False

          print(f"[{env_name}] Done.")
          return True

      failed = False
      for env in ["devnet", "testnet"]:
          if not sync_cert(env):
              failed = True

      if failed:
          print("Sync completed with errors — check logs above.")
          sys.exit(1)

      print("Sync complete.")
    SCRIPT
  }
}

# ServiceAccount for the CronJob.
resource "kubernetes_service_account_v1" "cert_sync" {
  metadata {
    name      = "oracles-cert-sync"
    namespace = "cert-manager"
  }
}

# Role scoped to read only the two cert secrets in cert-manager namespace.
resource "kubernetes_role_v1" "cert_sync" {
  metadata {
    name      = "oracles-cert-sync"
    namespace = "cert-manager"
  }
  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = ["oracles-devnet-wildcard-tls", "oracles-testnet-wildcard-tls"]
    verbs          = ["get"]
  }
}

resource "kubernetes_role_binding_v1" "cert_sync" {
  metadata {
    name      = "oracles-cert-sync"
    namespace = "cert-manager"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.cert_sync.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.cert_sync.metadata[0].name
    namespace = "cert-manager"
  }
}

# Daily CronJob — runs the Python sync script. python:3.12-alpine includes everything
# needed (urllib, json, ssl, hashlib) with no runtime package installation required.
resource "kubernetes_cron_job_v1" "cert_sync" {
  depends_on = [
    kubectl_manifest.devnet_certificate,
    kubectl_manifest.testnet_certificate,
    kubernetes_config_map_v1.cert_sync_script,
  ]
  metadata {
    name      = "oracles-cert-sync"
    namespace = "cert-manager"
  }
  spec {
    schedule                      = "0 3 * * *"
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 3
    job_template {
      metadata {}
      spec {
        template {
          metadata {}
          spec {
            service_account_name = kubernetes_service_account_v1.cert_sync.metadata[0].name
            restart_policy       = "OnFailure"
            container {
              name    = "cert-sync"
              image   = "python:3.12-alpine"
              command = ["python"]
              args    = ["/scripts/sync.py"]
              env {
                name = "CF_API_TOKEN"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.cloudflare_api_token.metadata[0].name
                    key  = "api-token"
                  }
                }
              }
              env {
                name  = "CF_ZONE_ID"
                value = var.cloudflare_zone_id
              }
              volume_mount {
                name       = "script"
                mount_path = "/scripts"
              }
              volume_mount {
                name       = "devnet-certs"
                mount_path = "/certs/devnet"
                read_only  = true
              }
              volume_mount {
                name       = "testnet-certs"
                mount_path = "/certs/testnet"
                read_only  = true
              }
              resources {
                requests = {
                  cpu    = "10m"
                  memory = "32Mi"
                }
                limits = {
                  memory = "64Mi"
                }
              }
            }
            volume {
              name = "script"
              config_map {
                name         = kubernetes_config_map_v1.cert_sync_script.metadata[0].name
                default_mode = "0755"
              }
            }
            volume {
              name = "devnet-certs"
              secret {
                secret_name = "oracles-devnet-wildcard-tls"
              }
            }
            volume {
              name = "testnet-certs"
              secret {
                secret_name = "oracles-testnet-wildcard-tls"
              }
            }
          }
        }
      }
    }
  }
}
