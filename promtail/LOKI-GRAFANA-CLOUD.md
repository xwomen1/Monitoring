# Gửi log lên Grafana Cloud (không chạy Loki trong cluster)

Khi cluster thiếu RAM, không chạy Loki trong cluster; dùng **Grafana Cloud Logs** (free tier) để nhận log từ Promtail.

**Giới hạn tài nguyên & retention:** Promtail được cấu hình **chỉ gửi log 2 giờ gần nhất** (stage `drop` với `older_than: 2h`) và **giới hạn CPU/RAM thấp** (limits: 100m CPU, 128Mi) để không ảnh hưởng workload khác trong cluster.

## Bước 1: Tạo Grafana Cloud stack

1. Vào https://grafana.com/products/cloud/
2. Đăng ký / đăng nhập → **Create free stack**
3. Trong stack: **Connections** → **Logs** → **Send logs** → chọn **Promtail**
4. Lấy:
   - **URL** (dạng `https://logs-prod-XXX.grafana.net`)
   - **User** (Instance ID, số)
   - **API Key** (token)

## Bước 2: Sửa URL trong ConfigMap

Mở `promtail/configmap-grafana-cloud.yaml`, tìm dòng:

```yaml
- url: https://logs-prod-XXX.grafana.net/loki/api/v1/push
```

Thay `logs-prod-XXX` bằng URL thật (vd. `logs-prod-006`).

## Bước 3: Tạo secret credentials

```bash
kubectl create secret generic promtail-grafana-cloud -n logging \
  --from-literal=username=123456 \
  --from-literal=password=glc_xxxxxxxxxxxx
```

- `username`: **Instance ID** (số) từ Grafana Cloud
- `password`: **API Key** (token) từ Grafana Cloud

Secret cần đúng 2 key: `username` và `password` (password được mount thành file, username dùng qua env).

## Bước 4: Tắt Loki, bật Promtail (Grafana Cloud)

```bash
# Scale Loki về 0
kubectl scale deployment loki -n logging --replicas=0

# Áp config Promtail Grafana Cloud (đã sửa URL ở bước 2)
kubectl apply -f promtail/configmap-grafana-cloud.yaml -n logging

# Áp DaemonSet có mount secret
kubectl apply -f promtail/daemon-grafana-cloud.yaml -n logging

# Restart Promtail
kubectl rollout restart daemonset/promtail -n logging
```

## Bước 5: Thêm datasource Loki trong Grafana

1. Grafana (UI) → **Connections** → **Data sources** → **Add data source**
2. Chọn **Loki**
3. URL: để trống (dùng Grafana Cloud)
4. Trong stack Grafana Cloud: **Details** → **Logs** → **Open Loki** (hoặc dùng URL họ cung cấp)
5. Nếu Grafana self-host: thêm data source Loki với URL của Cloud và cấu hình auth theo hướng dẫn Cloud.

Sau vài phút log sẽ xuất hiện trong Explore (Loki).

## Quay lại dùng Loki trong cluster

Khi đã có đủ RAM:

```bash
kubectl apply -f promtail/configmap.yaml -n logging
kubectl apply -f promtail/daemon.yaml -n logging
kubectl scale deployment loki -n logging --replicas=1
kubectl rollout restart daemonset/promtail -n logging
```
