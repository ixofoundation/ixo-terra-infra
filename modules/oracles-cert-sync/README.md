# oracles-cert-sync

Automates Let's Encrypt wildcard TLS certificates for `*.devnet.oracles.work` and `*.testnet.oracles.work` and keeps them synced to CloudFlare as custom certificates.

## Why this exists

CloudFlare's free Universal SSL only covers first-level wildcards (`*.oracles.work`). The Sandbox SDK generates second-level preview URLs (e.g. `8080-abc123.devnet.oracles.work`), which require a deeper wildcard cert. CloudFlare's Advanced Certificate Manager covers this but costs $10/month. This module issues the certs for free via Let's Encrypt and automates renewal and upload.

## How it works

1. **ClusterIssuer** — a cert-manager `ClusterIssuer` (`letsencrypt-cloudflare`) uses the CloudFlare DNS-01 challenge to prove domain ownership without needing a running HTTP server. cert-manager creates a `_acme-challenge` TXT record in CloudFlare, Let's Encrypt verifies it, and the cert is issued.

2. **Certificate resources** — two cert-manager `Certificate` objects request wildcard certs for `*.devnet.oracles.work` and `*.testnet.oracles.work`. cert-manager stores the issued certs as Kubernetes Secrets in the `cert-manager` namespace and automatically renews them ~30 days before expiry.

3. **CronJob** — runs daily at 03:00 UTC. For each cert it reads the current certificate from the Kubernetes Secret, compares its fingerprint against what is currently uploaded to CloudFlare, and uploads/updates only if the cert has changed.

## CloudFlare API token permissions required

The token passed via `cloudflare_api_token` must have:

| Permission | Purpose |
|---|---|
| Zone → DNS → Edit | Create `_acme-challenge` TXT records for DNS-01 |
| Zone → Zone → Read | Look up the zone |
| Zone → SSL and Certificates → Edit | Upload/update custom certificates |

## Inputs

| Variable | Description |
|---|---|
| `cloudflare_api_token` | CloudFlare API token (see permissions above) |
| `cloudflare_zone_id` | Zone ID for `oracles.work` from the CloudFlare dashboard |
| `acme_email` | Email for Let's Encrypt registration (default: `admin@ixo.world`) |

## Enable/disable

Controlled by the `oracles_cert_sync` feature flag in `terraform.tfvars`. Only enabled in the `mainnet` workspace.
