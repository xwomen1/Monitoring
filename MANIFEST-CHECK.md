# Kiểm tra manifest – lỗi thường gặp khi deploy

Tài liệu này liệt kê **lỗi đã biết** trong manifest và **bước bắt buộc** khi deploy để người khác deploy lại không gặp lỗi.

---

## 1. Loki ↔ MinIO: mật khẩu phải khớp

**Lỗi:** Loki không kết nối được MinIO (403 / auth failed).

**Nguyên nhân:** `loki/configmap.yaml` trước đây hardcode `secret_access_key: minioadmin` trong khi `base/secret.yaml` có `MINIO_ROOT_PASSWORD: "minioadmin123"` (hoặc giá trị khác). MinIO chạy với password trong secret, Loki lại dùng password trong config → không khớp.

**Đã sửa trong manifest:**
- `loki/deployment.yaml`: thêm args `-config.expand-env=true` để Loki đọc biến môi trường trong config.
- `loki/configmap.yaml`: dùng `secret_access_key: ${MINIO_PASSWORD}`; deployment đã mount env `MINIO_PASSWORD` từ secret `logging-secrets` key `MINIO_ROOT_PASSWORD`.

**Khi deploy:** Đảm bảo `base/secret.yaml` có đủ key `MINIO_ROOT_PASSWORD` (và `GRAFANA_ADMIN_PASSWORD`). Apply `base/secret.yaml` trước khi deploy MinIO + Loki.

---

## 2. Loki → MinIO: hostname `loki.minio....` không resolve (no such host)

**Lỗi trong log Loki:**  
`lookup loki.minio.logging.svc.cluster.local on ...:53: no such host`

**Nguyên nhân:** Loki (ruler, compactor, …) gọi S3 theo kiểu virtual-hosted → hostname thành `loki.minio.logging.svc.cluster.local`. Trong cluster không có DNS cho hostname này.

**Cách xử lý (không nằm trong manifest):** Phải cấu hình CoreDNS rewrite một lần trên cluster:

- Trong Corefile (ConfigMap `coredns` namespace `kube-system`), thêm dòng:
  ```text
  rewrite name exact loki.minio.logging.svc.cluster.local minio.logging.svc.cluster.local
  ```
- Restart CoreDNS, sau đó restart Loki.

Chi tiết từng bước: xem **`loki/coredns-rewrite-minio.md`**.

**Lưu ý:** Loki 3.3 không hỗ trợ `s3ForcePathStyle` / `s3_force_path_style` trong config, nên không thể sửa hoàn toàn trong manifest; bắt buộc phải dùng CoreDNS rewrite (hoặc tương đương) nếu dùng MinIO trong cluster.

---

## 3. Loki: schema v13 / structured metadata

**Lỗi khi start Loki:**  
`CONFIG ERROR: schema v13 is required to store Structured Metadata... Set allow_structured_metadata: false...`

**Đã sửa trong manifest:**  
`loki/configmap.yaml` có `limits_config.allow_structured_metadata: false`. Nếu file bị revert hoặc chỉnh tay, cần giữ lại đoạn:

```yaml
limits_config:
  allow_structured_metadata: false
```

---

## 4. MinIO: bucket `loki` phải tồn tại

**Lỗi:** Loki ghi chunk/index lên S3 (MinIO) bị lỗi bucket không tồn tại.

**Khi deploy:** Sau khi MinIO chạy, tạo bucket `loki` một lần (bằng console MinIO hoặc `mc`):

```bash
kubectl exec -it deployment/minio -n logging -- sh -c 'mc alias set myminio http://localhost:9000 minioadmin "$MINIO_ROOT_PASSWORD" && mc mb myminio/loki --ignore-existing'
```

(Thay `minioadmin` nếu `MINIO_ROOT_USER` trong deployment khác; `$MINIO_ROOT_PASSWORD` lấy từ env trong pod.)

---

## 5. Thứ tự apply và dependency

**Đúng thứ tự:**
1. Namespace `logging` (nếu chưa có).
2. `base/` (secret + PVC).
3. MinIO (deployment + service) → đợi Running.
4. Tạo bucket `loki` trên MinIO (xem mục 4).
5. (Một lần) Cấu hình CoreDNS rewrite (xem mục 2).
6. Loki (configmap + deployment + service).
7. Promtail, Prometheus, Grafana, node-exporter, v.v. theo README.

Nếu apply sai thứ tự (vd: Loki trước MinIO, hoặc chưa có CoreDNS rewrite), sẽ gặp đúng các lỗi mô tả ở trên.

---

## 6. Tóm tắt file đã sửa liên quan lỗi

| File | Nội dung sửa / lưu ý |
|------|----------------------|
| `base/secret.yaml` | Có `MINIO_ROOT_PASSWORD`, `GRAFANA_ADMIN_PASSWORD`. Loki dùng cùng secret qua env `MINIO_PASSWORD`. |
| `loki/configmap.yaml` | `limits_config.allow_structured_metadata: false`; `secret_access_key: ${MINIO_PASSWORD}`; endpoint có `/loki` (path-style). |
| `loki/deployment.yaml` | Args có `-config.expand-env=true`. |
| CoreDNS (cluster) | Thêm rewrite `loki.minio....` → `minio....` (xem `loki/coredns-rewrite-minio.md`). |
| MinIO bucket | Tạo bucket `loki` sau khi MinIO chạy. |

Khi người khác deploy lại: apply đúng thứ tự, làm đủ bước CoreDNS + tạo bucket → không còn các lỗi trên do manifest hoặc thiếu bước.
