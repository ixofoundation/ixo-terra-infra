#!/usr/bin/env bash
# Targeted plan/apply with your own identities (AWS SSO, Vault OIDC token, gcloud ADC). See docs/targeted-apply.md.
# Usage: scripts/tf-target.sh <devnet|testnet|mainnet> "<target> [target...]" [plan|apply]
set -euo pipefail
# Targets like module.x[0] must not glob-expand.
set -f

env_name="${1:-}"
targets="${2:-}"
action="${3:-plan}"

case "$env_name" in
  devnet)  var_file=terraform-aws-devnet-dev.tfvars;    profile=ixo-dev;  account=896358490078 ;;
  testnet) var_file=terraform-aws-testnet-test.tfvars;  profile=ixo-test; account=536202635008 ;;
  mainnet) var_file=terraform-aws-mainnet-main.tfvars;  profile=ixo-prod; account=361082683495 ;;
  *) echo "usage: $0 <devnet|testnet|mainnet> \"<target> [target...]\" [plan|apply]" >&2; exit 2 ;;
esac
case "$action" in plan|apply) ;; *) echo "[refused] action must be plan or apply" >&2; exit 2 ;; esac
[[ -n "${targets// /}" ]] || { echo "[refused] a target is required; untargeted runs are not allowed" >&2; exit 2; }

tf_targets=()
for t in $targets; do
  case "$t" in
    -*) echo "[refused] '$t': pass resource addresses only" >&2; exit 2 ;;
    *gcp_kms*) echo "[refused] '$t': destroying KMS key versions makes Vault unrecoverable" >&2; exit 2 ;;
    *matrix_init*) echo "[refused] '$t': replaces the Synapse macaroon key and logs everyone out" >&2; exit 2 ;;
    *cloudflare_workers_db_tunnel*) echo "[refused] '$t': cutover-only module" >&2; exit 2 ;;
  esac
  tf_targets+=("-target=$t")
done
for v in ${TF_CLI_ARGS:-} ${TF_CLI_ARGS_plan:-} ${TF_CLI_ARGS_apply:-}; do
  case "$v" in *gcp_kms*|*matrix_init*) echo "[refused] TF_CLI_ARGS names a forbidden target" >&2; exit 2 ;; esac
done

cd "$(dirname "$0")/.."
[[ -d .terraform ]] || { echo "[refused] run terraform init first (see docs/targeted-apply.md)" >&2; exit 1; }

want_tf=1.15.8
export TFENV_TERRAFORM_VERSION="${TFENV_TERRAFORM_VERSION:-$want_tf}"
have_tf=$(terraform version -json | sed -n 's/.*"terraform_version": *"\([^"]*\)".*/\1/p')
[[ "$have_tf" == "$want_tf" ]] || { echo "[refused] terraform $have_tf; state is written by $want_tf (tfenv use $want_tf)" >&2; exit 1; }

# Static keys in the environment would beat AWS_PROFILE.
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
export AWS_PROFILE="$profile"
got=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)
[[ "$got" == "$account" ]] || { echo "[refused] profile $profile is not account $account (try: aws sso login --profile $profile)" >&2; exit 1; }
aws sts get-caller-identity --profile ixo-devops --query Account --output text >/dev/null 2>&1 \
  || { echo "[refused] profile ixo-devops (Terraform state backend) is not logged in" >&2; exit 1; }

# Own Vault token only, never the shared userpass password.
unset TERRAFORM_VAULT_PASSWORD
export TF_VAR_vault_userpass_login=false
vault_addr="https://vault.${env_name}.ixo.earth"
if command -v vault >/dev/null; then
  VAULT_ADDR="$vault_addr" vault token lookup >/dev/null 2>&1 \
    || { echo "[refused] no valid Vault token for $vault_addr (VAULT_ADDR=$vault_addr vault login -method=oidc role=admin)" >&2; exit 1; }
fi
# OIDC client secrets may belong to another env; without them, argocd-dependent targets fail their precondition.
unset TF_VAR_oidc_argo TF_VAR_oidc_vault TF_VAR_oidc_tailscale

prev_ws=$(terraform workspace show)
trap 'terraform workspace select "$prev_ws" >/dev/null 2>&1 || true' EXIT
terraform workspace select "$env_name" >/dev/null
[[ "$(terraform workspace show)" == "$env_name" ]] || { echo "[abort] workspace is not $env_name" >&2; exit 1; }

echo "[ok] $env_name: account $account, workspace $env_name, var-file $var_file, targets: $targets"
# apply always shows the plan and asks for "yes"; never add -auto-approve here.
terraform "$action" -var-file="$var_file" "${tf_targets[@]}"
