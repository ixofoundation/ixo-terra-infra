#!/usr/bin/env bash
set -euo pipefail

ALERT_THRESHOLD=90
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

declare -a ALERTS=()

ENVS=("devnet" "testnet" "mainnet")

echo "========================================"
echo "  PVC Storage Report - $(date +%Y-%m-%d)"
echo "========================================"
echo ""

for ENV in "${ENVS[@]}"; do
  ENV_UPPER=$(echo "$ENV" | tr '[:lower:]' '[:upper:]')
  KUBECONFIG_FILE="${SCRIPT_DIR}/kubeconfig_${ENV}.yaml"

  if [[ ! -f "$KUBECONFIG_FILE" ]]; then
    echo "--- ${ENV_UPPER} --- (kubeconfig not found, skipping)"
    echo ""
    continue
  fi

  export KUBECONFIG="$KUBECONFIG_FILE"

  echo "--- ${ENV_UPPER} ---"
  printf "%-22s %-50s %8s %8s %6s\n" "NAMESPACE" "PVC NAME" "TOTAL" "USED" "USE%"
  printf "%-22s %-50s %8s %8s %6s\n" "---------" "--------" "-----" "----" "----"

  # Get all PVCs as JSON
  PVC_JSON=$(kubectl get pvc --all-namespaces -o json 2>/dev/null)
  PVC_COUNT=$(echo "$PVC_JSON" | jq '.items | length')

  for i in $(seq 0 $((PVC_COUNT - 1))); do
    NS=$(echo "$PVC_JSON" | jq -r ".items[$i].metadata.namespace")
    PVC_NAME=$(echo "$PVC_JSON" | jq -r ".items[$i].metadata.name")
    PVC_STATUS=$(echo "$PVC_JSON" | jq -r ".items[$i].status.phase")

    if [[ "$PVC_STATUS" != "Bound" ]]; then
      printf "%-22s %-50s %8s %8s %6s\n" "$NS" "$PVC_NAME" "--" "--" "(${PVC_STATUS})"
      continue
    fi

    # Find a running pod that mounts this PVC
    PODS_JSON=$(kubectl get pods -n "$NS" -o json 2>/dev/null)

    # Find pod name, container name, and mount path for this PVC
    MATCH=$(echo "$PODS_JSON" | jq -r --arg pvc "$PVC_NAME" '
      [.items[] |
        select(.status.phase == "Running") |
        . as $pod |
        .spec.volumes[]? |
        select(.persistentVolumeClaim.claimName == $pvc) |
        .name as $volName |
        $pod.spec.containers[] |
        select(.volumeMounts[]? | .name == $volName) |
        {
          pod: $pod.metadata.name,
          container: .name,
          mountPath: (.volumeMounts[] | select(.name == $volName) | .mountPath)
        }
      ] | first // empty' 2>/dev/null)

    if [[ -z "$MATCH" ]]; then
      printf "%-22s %-50s %8s %8s %6s\n" "$NS" "$PVC_NAME" "--" "--" "(no pod)"
      continue
    fi

    POD=$(echo "$MATCH" | jq -r '.pod')
    CONTAINER=$(echo "$MATCH" | jq -r '.container')
    MOUNT_PATH=$(echo "$MATCH" | jq -r '.mountPath')

    # Run df -P inside the pod for POSIX single-line output
    DF_OUTPUT=$(kubectl exec -n "$NS" "$POD" -c "$CONTAINER" -- df -P "$MOUNT_PATH" 2>/dev/null | tail -1) || true

    if [[ -z "$DF_OUTPUT" ]]; then
      printf "%-22s %-50s %8s %8s %6s\n" "$NS" "$PVC_NAME" "--" "--" "(df err)"
      continue
    fi

    # Parse df -P output: Filesystem 1024-blocks Used Available Capacity Mounted
    TOTAL_KB=$(echo "$DF_OUTPUT" | awk '{print $2}')
    USED_KB=$(echo "$DF_OUTPUT" | awk '{print $3}')
    USE_PCT=$(echo "$DF_OUTPUT" | awk '{print $5}' | tr -d '%')

    # Validate parsed values are numeric
    if ! [[ "$TOTAL_KB" =~ ^[0-9]+$ ]] || ! [[ "$USE_PCT" =~ ^[0-9]+$ ]]; then
      printf "%-22s %-50s %8s %8s %6s\n" "$NS" "$PVC_NAME" "--" "--" "(parse err)"
      continue
    fi

    # Convert KB to human-readable
    if [[ "$TOTAL_KB" -ge 1048576 ]]; then
      TOTAL_HR="$(awk "BEGIN {printf \"%.1fG\", $TOTAL_KB/1048576}")"
    elif [[ "$TOTAL_KB" -ge 1024 ]]; then
      TOTAL_HR="$(awk "BEGIN {printf \"%.1fM\", $TOTAL_KB/1024}")"
    else
      TOTAL_HR="${TOTAL_KB}K"
    fi

    if [[ "$USED_KB" -ge 1048576 ]]; then
      USED_HR="$(awk "BEGIN {printf \"%.1fG\", $USED_KB/1048576}")"
    elif [[ "$USED_KB" -ge 1024 ]]; then
      USED_HR="$(awk "BEGIN {printf \"%.1fM\", $USED_KB/1024}")"
    else
      USED_HR="${USED_KB}K"
    fi

    if [[ "$USE_PCT" -ge "$ALERT_THRESHOLD" ]]; then
      printf "%-22s %-50s %8s %8s %5s%%  \u26a0\ufe0f  ALERT\n" "$NS" "$PVC_NAME" "$TOTAL_HR" "$USED_HR" "$USE_PCT"
      ALERTS+=("[${ENV_UPPER}]  ${NS} / ${PVC_NAME}  ${USED_HR} / ${TOTAL_HR} (${USE_PCT}%)")
    else
      printf "%-22s %-50s %8s %8s %5s%%\n" "$NS" "$PVC_NAME" "$TOTAL_HR" "$USED_HR" "$USE_PCT"
    fi
  done

  echo ""
done

echo "========================================"
if [[ ${#ALERTS[@]} -eq 0 ]]; then
  echo "  All PVCs are below ${ALERT_THRESHOLD}% usage."
else
  echo "  \u26a0\ufe0f  ALERTS (>${ALERT_THRESHOLD}% usage)"
  echo "========================================"
  for ALERT in "${ALERTS[@]}"; do
    echo "  $ALERT"
  done
fi
echo "========================================"
