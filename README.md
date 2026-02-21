# Cloud-Native DevOps Platform

**Production-grade platform running 24/7 on Oracle Cloud Free Tier — $0/month ($144/mo AWS equivalent)**

[![Live](https://img.shields.io/badge/Live-nupurshahalabs.work-brightgreen)](https://nupurshahalabs.work)
[![Uptime](https://img.shields.io/badge/Uptime-99%25%2B-brightgreen)](https://nupurshahalabs.work)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue)](LICENSE)
[![K3s](https://img.shields.io/badge/K3s-1.28-326CE5?logo=kubernetes)](https://k3s.io)
[![Terraform](https://img.shields.io/badge/Terraform-1.6-7B42BC?logo=terraform)](https://terraform.io)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-2.9-EF7B4D?logo=argo)](https://argoproj.github.io)

---

## What This Is

It's a fully operational, publicly accessible cloud-native platform that mirrors the tooling stack used at production SaaS companies — built entirely on free infrastructure.

Every design decision reflects real-world production thinking: immutable deployments, GitOps-driven delivery, default-deny network policies, encrypted secrets in Git, automated vulnerability scanning, tested disaster recovery, and live observability — all on a single ARM64 VM at zero cost.

**→ [View the live platform dashboard](https://nupurshahalabs.work)**

---

## Architecture

```
INTERNET
    │
    ▼
Cloudflare  (DDoS protection · WAF · CDN · TLS · Rate limiting)
    │  port 443 only — real Oracle IP is never exposed
    ▼
Oracle Cloud VM  (Ubuntu 22.04 ARM64 · 4 cores · 24 GB RAM)
    │
    ▼
UFW + iptables  (host firewall)
    │
    ▼
Traefik Ingress
    ├── /          → frontend   (React dashboard · 2 replicas)
    ├── /api       → backend    (FastAPI · 3 replicas)
    ├── /grafana   → Grafana    (monitoring namespace)
    └── /argocd    → ArgoCD     (auth-protected)

demo namespace:
  frontend → backend → PostgreSQL 15 (StatefulSet)
                     → Redis 7
                     → RabbitMQ 3.12 (AMQP)
  worker   → RabbitMQ + PostgreSQL

monitoring namespace:
  Prometheus ← scrapes all namespaces via ServiceMonitors
  Loki ← Promtail DaemonSet (structured log shipping)
  Grafana → queries Prometheus + Loki
  Alertmanager → email + Slack

GitOps flow:
  git push → GitHub Actions (lint · Trivy scan · build ARM64 · push GHCR)
           → manifest update committed
           → ArgoCD detects diff → applies to cluster
           → code to live in ~90 seconds, zero manual steps
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Orchestration | K3s 1.28 (Kubernetes, single-binary, ARM64) |
| Infrastructure as Code | Terraform 1.6 (OCI provider — VCN, compute, storage, security groups) |
| GitOps / CD | ArgoCD 2.9 |
| CI Pipeline | GitHub Actions (ARM64 image build, Trivy scan, GHCR push, manifest update) |
| Ingress | Traefik 2.10 + cert-manager 1.13 (Let's Encrypt TLS) |
| Secret Management | Sealed Secrets 0.24 (encrypted in Git — safe to commit) |
| Metrics | Prometheus 2.47 + Alertmanager |
| Dashboards | Grafana 10.2 |
| Logging | Loki 2.9 + Promtail |
| Vulnerability Scanning | Trivy 0.47 (runs in every CI pipeline) |
| Backend | FastAPI (Python 3.11) |
| Frontend | React 18 (nginx) — live deployment dashboard |
| Database | PostgreSQL 15 StatefulSet |
| Cache | Redis 7 |
| Message Queue | RabbitMQ 3.12 |
| Edge / CDN | Cloudflare (WAF · DDoS · rate limiting · CDN · proxy) |
| Registry | GHCR (GitHub Container Registry) |
| Uptime monitoring | UptimeRobot (external, independent) |

---

## Key Engineering Decisions

**Why Loki instead of ELK?**
Loki uses ~10× less memory than Elasticsearch for equivalent log volume, integrates natively with Grafana (already deployed), and fits the resource budget of a free-tier VM. At my day job I operate a full ELK stack in production — this was a deliberate cost-aware trade-off, documented in [ADR-003](docs/).

**Why Sealed Secrets instead of Vault?**
Vault requires dedicated infrastructure and a persistent unsealing process that's operationally expensive on a single-node cluster. Sealed Secrets gives GitOps-safe encrypted secrets with no runtime dependency beyond the controller.

**Single-node trade-off:**
No HA control plane. Acceptable for a portfolio project. The DR runbook (below) covers full VM rebuild under 45 minutes — tested. Documented in ADR-004.

---

## Security Posture

- **Edge:** Cloudflare WAF + DDoS + rate limiting (100 req/60s) + Bot Fight Mode. Real VM IP never exposed.
- **Host:** UFW + iptables. SSH restricted to known IPs via OCI Security List.
- **Cluster:** Default-deny NetworkPolicies on all namespaces. Explicit allow-rules only.
- **Workloads:** Non-root containers, read-only filesystems where applicable, Pod Security Standards enforced.
- **Secrets:** All secrets sealed with Bitnami Sealed Secrets — safe to commit to public Git.
- **Images:** Trivy CVE scan runs in every CI pipeline. Pipeline fails on HIGH/CRITICAL vulnerabilities.
- **Supply chain:** All image versions pinned. No `latest` tags anywhere.

---

## Disaster Recovery

Full cluster rebuild is documented, scripted, and tested:

| Step | Time |
|---|---|
| Terraform re-provision OCI compute | ~5 min |
| K3s install + bootstrap | ~10 min |
| Restore PVC data from OCI Object Storage | ~15 min |
| ArgoCD sync (re-deploys all workloads from Git) | ~10 min |
| Verify observability + connectivity | ~5 min |
| **Total** | **~45 min** |

Backup CronJob runs nightly to OCI Object Storage. Restore procedure documented in [`docs/dr-runbook.md`](docs/).

---

## Cost

| | AWS Equivalent | Our Cost |
|---|---|---|
| Compute (4 vCPU / 24 GB) | t4g.xlarge ~$117/mo | $0 |
| Block storage 100 GB | EBS gp3 ~$8/mo | $0 |
| Load Balancer | ALB ~$18/mo | $0 (NodePort + Cloudflare) |
| **Total** | **~$144/month** | **$0/month** |

---

## Repo Structure

```
devops-platform-demo/
├── terraform/          # OCI infrastructure — VCN, compute, storage, security groups
├── k8s/
│   ├── namespaces/     # Namespace definitions + RBAC + resource quotas
│   ├── network-policies/  # Default-deny + explicit allow rules per namespace
│   ├── demo/           # App workloads — backend, frontend, worker, PostgreSQL, Redis, RabbitMQ
│   ├── monitoring/     # Prometheus, Grafana, Loki, Alertmanager (via kube-prometheus-stack Helm)
│   └── argocd/         # ArgoCD Application CRDs
├── apps/
│   ├── backend/        # FastAPI service (Python 3.11) — ARM64 Dockerfile
│   ├── frontend/       # React dashboard — ARM64 Dockerfile
│   └── worker/         # Async worker — ARM64 Dockerfile
├── docs/
│   ├── architecture.md
│   ├── dr-runbook.md   # Tested disaster recovery procedure
│   └── adr/            # Architecture Decision Records
└── .github/workflows/  # CI (build + scan + push) + CD (manifest update)
```

---

## Live Links

| | |
|---|---|
| **Platform dashboard** | [nupurshahalabs.work](https://nupurshahalabs.work) |
| **Grafana** | [nupurshahalabs.work/grafana](https://nupurshahalabs.work/grafana) |
| **Author** | [linkedin.com/in/nupur-shaha](https://linkedin.com/in/nupur-shaha) |
| **Portfolio** | [nupurshaha.github.io](https://nupurshaha.github.io) |

---

*Built by [Nupur Shaha](https://linkedin.com/in/nupur-shaha) · GCP Certified Professional Cloud Architect · DevOps Engineer*
