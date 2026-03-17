# 🚀 Kubernetes Observability Stack (K3s/K8s)

[![Kubernetes](https://img.shields.io/badge/kubernetes-compatible-blue?logo=kubernetes)](https://kubernetes.io)
[![Kustomize](https://img.shields.io/badge/kustomize-ready-blue?logo=kustomize)](https://kustomize.io)
[![Grafana](https://img.shields.io/badge/grafana-monitoring-orange?logo=grafana)](https://grafana.com)
[![Prometheus](https://img.shields.io/badge/prometheus-metrics-red?logo=prometheus)](https://prometheus.io)
[![Loki](https://img.shields.io/badge/loki-logging-purple)](https://grafana.com/oss/loki/)

A highly structured, **Kustomize**-ready observability stack for Kubernetes (K3s/K8s). It provides a complete monitoring and logging ecosystem tailored for production and home-lab deployments. This repository is sanitized and ready to act as a solid foundation for any Kubernetes log & monitoring stack.

<br>
<p align="center">
  <img src="assets/demo.png" alt="Grafana Dashboard Demo" width="100%">
</p>
<br>

## ✨ Features

- **Metrics Collection**: Prometheus, Node Exporter, Kube State Metrics.
- **Log Aggregation**: Grafana Loki & Promtail (backed by MinIO object storage for scalability).
- **Visualization**: Grafana with pre-configured dashboards and Prometheus/Loki datasources.
- **Database Exporters**: Built-in configs for MySQL, MSSQL, and Redis monitoring.
- **Infrastructure as Code**: Everything is structured using **Kustomize** for clean and modular deployments.

---

## 🏗 Architecture & Data Flow

1. **Grafana** (UI) acts as the single pane of glass, querying data from Prometheus & Loki.
2. **Prometheus** actively scrapes metrics from `node-exporter`, `kube-state-metrics`, and external database exporters.
3. **Promtail** runs as an agent (DaemonSet) on every node to collect pod logs and ship them to **Loki**.
4. **Loki** efficiently indexes logs and uses **MinIO** as an S3-compatible storage backend to securely store chunks out of the box.

---

## 🚀 Quick Start

### 1. Configure Secrets & Access Points

Before applying the manifests, you must configure your own secrets, passwords, and target IP addresses. 

Update the following files with your credentials (make sure to replace the `<PLACEHOLDER>` strings):

- `base/secret.yaml`: Set up your Grafana & MinIO admin passwords.
- `grafana/ingress.yaml`: Update the routing with your domain name (replace `log.example.com`).
- **DB Exporters** (`mysql-exporter`, `mssql-exporter`, `redis-exporter`): Update database target IP addresses and authentication passwords in their respective `secret.yaml` and `deployment.yaml` configurations.

### 2. Deployment

This repository natively supports **Kustomize**. You can deploy the entire stack with a single command from the root directory:

```bash
kubectl apply -k .
```

*Alternatively, use the provided helper script for a robust deployment process:*
```bash
chmod +x apply-all.sh
./apply-all.sh
```
*(Tip: Use `./apply-all.sh --recreate` to completely delete and securely recreate the `logging` namespace and all of its resources).*

### 3. Post-Deployment Steps

1. **Create S3 Bucket for Loki**: 
   Access your MinIO UI via port-forwarding or ingress, login, and manually create a bucket named `loki`.
2. **CoreDNS Rewrite mapping**: 
   Loki needs to reach MinIO over the internal DNS literal `loki.minio.logging.svc.cluster.local`. Ensure you configure your `CoreDNS` configmap if a rewrite rule is necessary (refer to `loki/coredns-rewrite-minio.md` if available).

---

## 📊 Access & Dashboards

- **Grafana UI**: Access your environment via your configured Ingress (e.g., `https://log.example.com`). 
  - Login with username `admin` and the custom password you defined in `base/secret.yaml`.
- Data Sources and Dashboards are automatically provisioned. Enjoy the defaults imported out-of-the-box (`grafana/dashboards-configmap.yaml`), or easily import popular ones from the [Grafana Dashboards](https://grafana.com/grafana/dashboards/) hub, such as:
  - **1860**: Node Exporter Full
  - **6417**: Kubernetes Compute Resources
  - **14056**: Persistent Volumes

---

## 🤝 Contributing

Contributions, issues and feature requests are welcome! Feel free to check [issues page](#). If you found this repository helpful, please consider giving it a ⭐️!
