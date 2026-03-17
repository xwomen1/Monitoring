"set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <namespace> <selector> [grep-pattern]"
  echo "  selector: label (vd. app=bi-blazor) hoặc deployment/xyz hoặc tên pod"
  echo "  grep-pattern: optional, vd. TotalServerResponseMs hoặc info"
  echo ""
  echo "Example:"
  echo "  $0 tis-bi app=bi-blazor TotalServerResponseMs"
  echo "  $0 tis-bi app=bi-blazor"
  exit 1
fi
NS="$1"
SEL="$2"
GREP="${3:-}"
TAIL="${TAIL:-500}"

if [[ "$SEL" == *"="* ]]; then
  LOGS_CMD=(kubectl logs -n "$NS" -l "$SEL" --tail="$TAIL" --all-containers=true)
else
  LOGS_CMD=(kubectl logs -n "$NS" "$SEL" --tail="$TAIL" --all-containers=true)
fi

if [ -n "$GREP" ]; then
  echo "=== Logs (namespace=$NS, selector=$SEL, grep=$GREP, tail=$TAIL) ==="
  "${LOGS_CMD[@]}" 2>/dev/null | grep -i -- "$GREP" || true
else
  echo "=== Logs (namespace=$NS, selector=$SEL, tail=$TAIL) ==="
  "${LOGS_CMD[@]}" 2>/dev/null || true
fi
