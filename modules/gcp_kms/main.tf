resource "google_kms_key_ring" "this" {
  location = "global"
  name     = "${var.name}-key-ring"
}

resource "google_kms_crypto_key" "this" {
  name            = "${var.name}-crypto-key"
  key_ring        = google_kms_key_ring.this.id
  rotation_period = "7776000s" # 90 days; was 100000s (~28h) which minted ~1 version/day — see IXO-3199
  purpose         = "ENCRYPT_DECRYPT"
}

resource "kubernetes_secret_v1" "gcp_secret" {
  lifecycle {
    ignore_changes = [data]
  }
  metadata {
    name      = "gcp-key-secret"
    namespace = var.namespace
  }
  data = {
    "key.json" = "" # To be added manually
  }
}

data "kubernetes_secret_v1" "current_gcp_secret_value" {
  depends_on = [kubernetes_secret_v1.gcp_secret]
  metadata {
    name = "gcp-key-secret"
    namespace = var.namespace
  }
}