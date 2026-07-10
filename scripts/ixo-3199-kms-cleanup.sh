#!/usr/bin/env bash
#
# IXO-3199 — Cloud KMS cost cleanup for devsecops-415617
#
# Background: keys were created with rotation_period=100000s (~28h, typo for 90d),
# minting ~1 version/day for 2 years => 7,862 billable versions x $0.06/mo = ~$472/mo.
# DISABLED versions bill the same as ENABLED — only DESTROYED versions stop billing.
#
# Usage evidence (ixo-terra-infra, verified 2026-07-09):
#   vault-{mainnet,testnet,devnet}  USED  - Vault gcpckms auto-unseal (modules.tf:325-327)
#   loki-*                          UNUSED - only the SA secret is consumed (modules.tf:376),
#                                            the crypto key is never referenced
#   matrix-*, core-*                UNUSED - module outputs consumed nowhere; all versions
#                                            already DISABLED for weeks with zero breakage
#   *-aws                           UNUSED - decommissioned AWS deployment
#   All 26,843 KMS API calls in the last 30d returned 200 (no consumer of disabled keys).
#
# Stages (run in order; each is dry-run by default, add --execute to act):
#   stage1     Destroy all versions of unused keys:
#                - every DISABLED version on matrix-*, core-*, vault-aws (Luke's set)
#                - every version on loki-* EXCEPT the primary (kept as insurance)
#   stage2     Vault keys: DISABLE all but the newest 10 versions per key (reversible).
#              >>> BEFORE running: restart each vault statefulset and confirm unseal:
#              >>>   kubectl -n vault rollout restart statefulset/vault && watch vault status
#              >>> The restart forces Vault to re-wrap its root key with the current
#              >>> primary version (autoseal UpgradeKeys, hashicorp/vault#7493).
#   rollback2  Re-enable everything stage2 disabled (instant, safe).
#   stage3     After a soak period (>=7 days of healthy vaults incl. one restart),
#              destroy the versions stage2 disabled.
#
# Destroyed versions enter a 30-day DESTROY_SCHEDULED window during which they can
# be restored (gcloud kms keys versions restore). After that they are gone forever.
#
# Requires: gcloud authed as an account with cloudkms.admin on devsecops-415617.

set -euo pipefail

PROJECT="devsecops-415617"
LOCATION="global"
KEEP_NEWEST_VAULT=10
PARALLELISM=8

UNUSED_RINGS=(
  matrix-aws matrix-devnet matrix-testnet matrix-mainnet
  core-aws core-devnet core-testnet core-mainnet
  vault-aws
)
LOKI_RINGS=(loki-aws loki-devnet loki-testnet loki-mainnet)
VAULT_RINGS=(vault-devnet vault-testnet vault-mainnet)

STAGE="${1:-}"
MODE="${2:-}"
if [[ -z "$STAGE" || ! "$STAGE" =~ ^(stage1|stage2|rollback2|stage3)$ ]]; then
  echo "Usage: $0 <stage1|stage2|rollback2|stage3> [--execute]" >&2
  exit 1
fi
EXECUTE=false
[[ "$MODE" == "--execute" ]] && EXECUTE=true

LOG="kms-cleanup-${STAGE}.log"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ring name -> key name follows the gcp_kms module convention:
# "<name>-key-ring" / "<name>-crypto-key"
key_of() { echo "${1}-crypto-key"; }
ring_of() { echo "${1}-key-ring"; }

# list_versions <ring-base> <state-filter>  -> lines: "<ring-base> <version-number>"
list_versions() {
  local base="$1" state="$2"
  gcloud kms keys versions list \
    --key "$(key_of "$base")" --keyring "$(ring_of "$base")" \
    --location "$LOCATION" --project "$PROJECT" \
    --filter "state=$state" --format "value(name.basename())" --limit 5000 \
    | while read -r v; do echo "$base $v"; done
}

primary_version() {
  gcloud kms keys describe "$(key_of "$1")" --keyring "$(ring_of "$1")" \
    --location "$LOCATION" --project "$PROJECT" \
    --format "value(primary.name.basename())"
}

# do_versions <verb> <targets-file>   verb: destroy|disable|enable
do_versions() {
  local verb="$1" file="$2"
  local count; count=$(wc -l < "$file" | tr -d ' ')
  if [[ "$count" -eq 0 ]]; then echo "  nothing to $verb"; return; fi
  if ! $EXECUTE; then
    echo "  DRY-RUN: would $verb $count versions (rerun with --execute)"
    sed 's/^/    /' "$file" | head -5; [[ "$count" -gt 5 ]] && echo "    ... ($count total)"
    return
  fi
  echo "  ${verb}: $count versions, parallelism $PARALLELISM -> $LOG"
  xargs -P "$PARALLELISM" -L 1 bash -c "
    base=\$0; v=\$1
    if gcloud kms keys versions $verb \"\$v\" \
         --key \"\${base}-crypto-key\" --keyring \"\${base}-key-ring\" \
         --location \"$LOCATION\" --project \"$PROJECT\" --quiet >/dev/null 2>>\"$LOG\"; then
      echo \"\$(date -u +%FT%TZ) $verb OK \$base/\$v\" >> \"$LOG\"
    else
      echo \"\$(date -u +%FT%TZ) $verb FAILED \$base/\$v\" >> \"$LOG\"
      echo \"FAILED: \$base/\$v\" >&2
    fi
  " < "$file"
  local failed
  failed=$(grep -c "$verb FAILED" "$LOG" 2>/dev/null || true)
  echo "  done. failures: ${failed:-0} (see $LOG)"
}

case "$STAGE" in

stage1)
  echo "== Stage 1: destroy versions of unused keys =="
  : > "$WORK/targets"

  for base in "${UNUSED_RINGS[@]}"; do
    # These keys are entirely unused; Luke already disabled every version.
    # Destroy DISABLED and (belt-and-braces) any ENABLED stragglers.
    list_versions "$base" ENABLED  >> "$WORK/targets" || true
    list_versions "$base" DISABLED >> "$WORK/targets" || true
  done

  for base in "${LOKI_RINGS[@]}"; do
    prim=$(primary_version "$base")
    if [[ -z "$prim" ]]; then
      echo "  !! could not determine primary for $base — skipping ring" >&2
      continue
    fi
    { list_versions "$base" ENABLED; list_versions "$base" DISABLED; } \
      | awk -v p="$prim" -v b="$base" '$1==b && $2!=p' >> "$WORK/targets" || true
    echo "  $base: keeping primary version $prim"
  done

  do_versions destroy "$WORK/targets"
  ;;

stage2)
  echo "== Stage 2: disable old versions on live vault keys (keep newest $KEEP_NEWEST_VAULT) =="
  echo "   PRE-REQ: you have restarted each vault statefulset since the last KMS rotation"
  echo "   and confirmed unseal (this re-wraps the root key with the current primary)."
  : > "$WORK/targets"
  for base in "${VAULT_RINGS[@]}"; do
    prim=$(primary_version "$base")
    list_versions "$base" ENABLED \
      | sort -k2,2 -n -r \
      | tail -n "+$((KEEP_NEWEST_VAULT + 1))" > "$WORK/ring"
    # never touch the primary, whatever its position
    awk -v p="$prim" '$2!=p' "$WORK/ring" >> "$WORK/targets"
    kept=$(( $(list_versions "$base" ENABLED | wc -l) - $(awk -v b="$base" '$1==b' "$WORK/targets" | wc -l) ))
    echo "  $base: primary=$prim, keeping $kept newest enabled versions"
  done
  do_versions disable "$WORK/targets"
  $EXECUTE && echo ">>> NOW restart each vault statefulset again and verify unseal. If anything fails: $0 rollback2 --execute"
  ;;

rollback2)
  echo "== Rollback stage 2: re-enable all disabled versions on vault keys =="
  : > "$WORK/targets"
  for base in "${VAULT_RINGS[@]}"; do
    list_versions "$base" DISABLED >> "$WORK/targets" || true
  done
  do_versions enable "$WORK/targets"
  ;;

stage3)
  echo "== Stage 3: destroy the vault versions disabled in stage 2 =="
  echo "   Run only after >=7 days of healthy vaults including at least one restart/unseal."
  : > "$WORK/targets"
  for base in "${VAULT_RINGS[@]}"; do
    list_versions "$base" DISABLED >> "$WORK/targets" || true
  done
  do_versions destroy "$WORK/targets"
  ;;
esac

echo
echo "== Billable version count after this run =="
total=0
for base in "${UNUSED_RINGS[@]}" "${LOKI_RINGS[@]}" "${VAULT_RINGS[@]}"; do
  n=$(( $(list_versions "$base" ENABLED | wc -l) + $(list_versions "$base" DISABLED | wc -l) ))
  total=$(( total + n ))
  printf "  %-16s %5d billable versions\n" "$base" "$n"
done
printf "  %-16s %5d  => \$%.2f/month\n" "TOTAL" "$total" "$(echo "$total * 0.06" | bc)"
