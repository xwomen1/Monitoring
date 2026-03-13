# Fix Loki → MinIO: DNS rewrite (loki.minio... → minio...)

Loki (ruler, compactor, …) gọi S3 dạng virtual-hosted nên hostname thành `loki.minio.logging.svc.cluster.local`, không tồn tại trong cluster. Cách xử lý: **rewrite DNS** trong CoreDNS để hostname đó trỏ về MinIO.

## Bước 1: Xem CoreDNS ConfigMap

```bash
kubectl get configmap coredns -n kube-system -o yaml
```

## Bước 2: Thêm rewrite trong Corefile

Trong phần **Corefile** (block `.:53` hoặc block xử lý `cluster.local`), thêm dòng **rewrite** (cùng cấp với `forward`, `cache`, …):

```text
rewrite name exact loki.minio.logging.svc.cluster.local minio.logging.svc.cluster.local
```

Ví dụ Corefile trước:

```text
.:53 {
    errors
    health {
        ...
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
        ...
    }
    forward . /etc/resolv.conf
    cache 30
    loop
    reload
    loadbalance
}
```

Sau khi thêm (đặt **trước** `forward`):

```text
.:53 {
    errors
    health {
        ...
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
        ...
    }
    rewrite name exact loki.minio.logging.svc.cluster.local minio.logging.svc.cluster.local
    forward . /etc/resolv.conf
    cache 30
    loop
    reload
    loadbalance
}
```

## Bước 3: Áp dụng và reload CoreDNS

```bash
# Sửa ConfigMap (edit hoặc apply file đã chỉnh)
kubectl edit configmap coredns -n kube-system

# Restart CoreDNS để load config mới
kubectl rollout restart deployment coredns -n kube-system
# Hoặc với DaemonSet:
# kubectl rollout restart daemonset coredns -n kube-system
```

## Bước 4: Restart Loki

```bash
kubectl rollout restart deployment loki -n logging
```

Sau đó kiểm tra log Loki (ruler, compactor) không còn lỗi `lookup loki.minio.logging.svc.cluster.local ... no such host`.

## Lưu ý

- Nếu cluster dùng CoreDNS addon khác (vd: K3s, RKE2), vị trí config có thể khác; vẫn cần thêm đúng dòng **rewrite** vào block xử lý DNS tương ứng.
- Plugin `rewrite` phải có trong image CoreDNS (thường có sẵn).
