#!/usr/bin/env bash
# Apply all observability stack components 
# Run from repository root: ./apply-all.sh
# Option: ./apply-all.sh --recreate  (delete and redeploy namespace logging)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
NS=logging

if [ "${1:-}" = "--recreate" ] || [ "${1:-}" = "-r" ]; then
  echo "=== Deleting namespace $NS ==="
  kubectl delete namespace "$NS" --ignore-not-found --timeout=120s || true
  echo "Waiting for namespace to be fully deleted..."
  while kubectl get namespace "$NS" &>/dev/null; do sleep 2; done
fi

echo "=== Deploying Observability Stack using Kustomize ==="
kubectl apply -k .

echo "Waiting for MinIO to be Ready..."
kubectl rollout status deployment/minio -n "$NS" --timeout=120s || true

echo ""
echo "=== Deployment Completed! ==="
echo "Post-Installation Steps:"
echo "  1. Create the 'loki' bucket on minio."
echo "  2. Configure CoreDNS rewrite for Loki -> MinIO (see README.md)."
echo ""
echo "Check pods status: kubectl get pods -n $NS"
