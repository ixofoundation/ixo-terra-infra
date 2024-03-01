output "key_ring_name" {
  value = google_kms_key_ring.this.name
}

output "crypto_key_name" {
  value = google_kms_crypto_key.this.name
}

output "gcp_key_secret_name" {
  value = kubernetes_secret_v1.gcp_secret.metadata[0].name
}