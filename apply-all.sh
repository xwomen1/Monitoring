#!/usr/bin/env bash
# Apply toàn bộ stack logging — tạo lại namespace logging và deploy đủ thứ tự.
# Chạy từ thư mục log/ (repo root): ./apply-all.sh
# Tùy chọn: ./apply-all.sh --recreate  (xóa namespace logging rồi apply lại từ đầu)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
NS=logging

if [ "${1:-}" = "--recreate" ] || [ "${1:-}" = "-r" ]; then
  echo "=== Xóa namespace $NS (và mọi resource bên trong) ==="
  kubectl delete namespace "$NS" --ignore-not-found --timeout=120s || true
  echo "Đợi namespace xóa xong..."
  while kubectl get namespace "$NS" &>/dev/null; do sleep 2; done
fi

echo "=== 1. Namespace ==="
kubectl apply -f base/namespace.yaml

echo "=== 2. Base (secret + PVC) ==="
kubectl apply -f base/secret.yaml
kubectl apply -f base/pvc-logging-storage.yaml

echo "=== 3. MinIO ==="
kubectl apply -f minio/deployment.yaml
kubectl apply -f minio/service.yaml

echo "Đợi MinIO Running..."
kubectl rollout status deployment/minio -n "$NS" --timeout=120s || true

echo "=== 4. Loki ==="
kubectl apply -f loki/configmap.yaml
kubectl apply -f loki/deployment.yaml
kubectl apply -f loki/service.yaml

echo "=== 5. Promtail ==="
kubectl apply -f promtail/service-account.yaml
kubectl apply -f promtail/rbac.yaml
kubectl apply -f promtail/configmap.yaml
kubectl apply -f promtail/daemon.yaml

echo "=== 6. Prometheus ==="
kubectl apply -f prometheus/rbac.yaml
kubectl apply -f prometheus/configmap.yaml
kubectl apply -f prometheus/pvc.yaml
kubectl apply -f prometheus/deployment.yaml
kubectl apply -f prometheus/service.yaml

echo "=== 7. Node-exporter ==="
kubectl apply -f node-exporter/daemonset.yaml
kubectl apply -f node-exporter/service.yaml

echo "=== 8. Kube-state-metrics ==="
kubectl apply -f kube-state-metrics/rbac.yaml
kubectl apply -f kube-state-metrics/deployment.yaml
kubectl apply -f kube-state-metrics/service.yaml

echo "=== 9. Grafana ==="
kubectl apply -f grafana/pvc.yaml
kubectl apply -f grafana/datasource-prometheus.yaml
kubectl apply -f grafana/dashboards-provider.yaml
kubectl apply -f grafana/dashboards-configmap.yaml
kubectl apply -f grafana/deployment.yaml
kubectl apply -f grafana/service.yaml
kubectl apply -f grafana/ingress.yaml

echo "=== 10. DB exporters (mysql, mssql, redis) ==="
kubectl apply -f mysql-exporter/secret.yaml
kubectl apply -f mysql-exporter/deployment.yaml
kubectl apply -f mysql-exporter/service.yaml
kubectl apply -f mssql-exporter/secret.yaml
kubectl apply -f mssql-exporter/deployment.yaml
kubectl apply -f mssql-exporter/service.yaml
kubectl apply -f redis-exporter/deployment.yaml
kubectl apply -f redis-exporter/service.yaml

echo ""
echo "=== Xong ==="
echo "Nhớ làm thêm (nếu chưa):"
echo "  1. Tạo bucket loki trên MinIO (xem MANIFEST-CHECK.md)"
echo "  2. Cấu hình CoreDNS rewrite cho Loki→MinIO (xem loki/coredns-rewrite-minio.md)"
echo ""
echo "Kiểm tra: kubectl get pods -n $NS"
