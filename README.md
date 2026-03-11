# Log & Monitoring Stack (K3s)

Stack: Grafana, Loki, Promtail, MinIO, Prometheus, node-exporter, kube-state-metrics. Namespace: `logging`.

## Cấu trúc thư mục

```
log/
├── README.md
├── base/                    
│   ├── secret.yaml         # logging-secrets (Grafana, MinIO password)
│   └── pvc-logging-storage.yaml   # PVC 7Gi cho Loki + MinIO
├── minio/                   # Object storage (Loki backend)
│   ├── deployment.yaml
│   └── service.yaml
├── loki/                    # Log aggregation
│   ├── configmap.yaml
│   ├── deployment.yaml 
│   └── service.yaml
├── promtail/                # Log collector (DaemonSet)
│   ├── service-account.yaml
│   ├── rbac.yaml
│   ├── configmap.yaml
│   └── daemon.yaml
├── prometheus/              # Metrics
│   ├── rbac.yaml
│   ├── configmap.yaml
│   ├── pvc.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── node-exporter/          # Node metrics (DaemonSet)
│   ├── daemonset.yaml
│   └── service.yaml
├── kube-state-metrics/     # K8s object metrics
│   ├── rbac.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── grafana/                 # UI (log + metrics)
│   ├── pvc.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── datasource-prometheus.yaml
│   ├── dashboards-provider.yaml
│   ├── dashboards-configmap.yaml
│   └── ingress.yaml
├── mysql-exporter/          # MySQL server DB (192.168.5.40:3306)
│   ├── secret.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── mssql-exporter/          # SQL Server (192.168.5.40:1433)
│   ├── secret.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── redis-exporter/          # Redis (192.168.5.40:6379)
│   ├── deployment.yaml
│   └── service.yaml
└── _lite/                   # Manifest light (Pod + Service, test)
    ├── grafana-lite.yaml
    └── minio-lite.yaml
```

**Lưu ý:** Các thư mục `loki/`, `minio/` ở root chứa manifest lite/alternate; có thể giữ để tham khảo hoặc xóa nếu không dùng.

## Thứ tự apply (namespace `logging` đã có)

```bash
# 1. Base
kubectl apply -f base/

# 2. Storage & logging
kubectl apply -f minio/
kubectl apply -f loki/
kubectl apply -f promtail/

# 3. Monitoring
kubectl apply -f prometheus/
kubectl apply -f node-exporter/
kubectl apply -f kube-state-metrics/

# 4. Grafana + Ingress
kubectl apply -f grafana/

# 5. DB monitoring (server 192.168.5.40)
kubectl apply -f mysql-exporter/
kubectl apply -f mssql-exporter/
kubectl apply -f redis-exporter/
```

**Trước khi apply DB exporters:** sửa password trong `mysql-exporter/secret.yaml` và `mssql-exporter/secret.yaml`, đồng thời mở firewall trên 192.168.5.40 cho cluster truy cập port 3306, 1433, 6379.

Hoặc apply toàn bộ (nếu đã tạo namespace `logging`):

```bash
kubectl apply -f base/ -f minio/ -f loki/ -f promtail/ -f prometheus/ -f node-exporter/ -f kube-state-metrics/ -f grafana/
```

## Truy cập

- **Grafana:** https://log.pirago.work (cấu hình DNS/Cloudflare trỏ tới Ingress).
- Mật khẩu admin: lấy từ secret `logging-secrets`, key `GRAFANA_ADMIN_PASSWORD`.

## Giám sát server DB (192.168.5.40)

Exporters chạy trong cluster, kết nối ra MySQL (3306), SQL Server (1433), Redis (6379) trên server 192.168.5.40.

- **Yêu cầu:** Trên 192.168.5.40 mở firewall cho IP các node K3s (hoặc toàn mạng cluster) vào port 3306, 1433, 6379.
- **MySQL:** Sửa `mysql-exporter/secret.yaml` — thay `REPLACE_WITH_MYSQL_PASSWORD` bằng mật khẩu user `pirago`. Trên MySQL tạo user (nếu cần): `GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'pirago'@'%';`
- **SQL Server:** Sửa `mssql-exporter/secret.yaml` — đặt `USERNAME` (vd. `sa`) và `PASSWORD` đúng.
- **Redis:** Không auth mặc định; nếu có password thì thêm env `REDIS_PASSWORD` từ secret vào `redis-exporter/deployment.yaml`.
- **Prometheus:** Đã thêm job scrape `mysql-dbaas`, `mssql-dbaas`, `redis-dbaas`. Sau khi apply exporters, apply lại `prometheus/configmap.yaml` và reload Prometheus (hoặc restart pod).
- **Grafana:** Import dashboard MySQL (id 7362), SQL Server (tìm "SQL Server" trên Grafana.com), Redis (id 11835).

## Dashboard

Sau khi đăng nhập Grafana: màn hình mặc định là **Node Overview** (CPU, memory, disk theo node). Thêm dashboard từ Grafana.com: 1860 (Node Exporter Full), 6417 (Kubernetes Compute Resources), 14056 (Persistent Volumes).
