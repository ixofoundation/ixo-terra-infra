#
# Manual Admin user command:
# register_new_matrix_user http://localhost:8008 -c synapse/secrets/config.yaml -u admin -p <admin_password>
#


resource "random_password" "matrix_admin" {
  length = 32
}

resource "random_password" "macaroon" {
  length = 32
}

resource "vault_kv_secret_v2" "matrix" {
  lifecycle {
    ignore_changes = [data_json]
  }
  mount               = var.vault_mount_path
  name                = "matrix"
  cas                 = 1
  delete_all_versions = true
  data_json = jsonencode(
    {
      MACAROON_SECRET_KEY    = random_password.macaroon.result
      ADMIN_PASSWORD         = random_password.matrix_admin.result
      MATRIX_STATE_BOT_TOKEN = ""
    }
  )
  custom_metadata {
    max_versions = 5
  }
}