# Cloud-Native DevOps Platform

[![CI](https://github.com/NupurShaha/devops-platform-demo/actions/workflows/ci.yml/badge.svg)](https://github.com/NupurShaha/devops-platform-demo/actions/workflows/ci.yml)
[![Platform Status](https://img.shields.io/badge/platform-building-yellow)](https://nupurshahalabs.work)

Production-grade cloud-native DevOps platform running 24/7 on Oracle Cloud Always-Free Tier.

## 🔗 Live Platform

**[https://nupurshahalabs.work](https://nupurshahalabs.work)** *(coming soon)*

## What This Is

A fully-functional, publicly accessible platform that demonstrates production-grade DevOps skills:

- **Infrastructure as Code** — All cloud resources provisioned via Terraform
- **Kubernetes** — K3s cluster with proper namespaces, RBAC, network policies, and resource quotas
- **GitOps** — ArgoCD automatically syncs cluster state from this repository
- **CI/CD** — GitHub Actions builds, tests, scans, and deploys on every push
- **Observability** — Prometheus metrics, Grafana dashboards, Loki logs, Alertmanager notifications
- **Security** — Cloudflare WAF, Trivy vulnerability scanning, Sealed Secrets, Pod Security Standards
- **Zero Cost** — Entire platform runs on Oracle Cloud Always-Free Tier ($0/month)

## Architecture

```
Internet → Cloudflare (WAF/CDN) → Oracle Cloud VM → K3s → Traefik Ingress
                                                        ├── Frontend (React Dashboard)
                                                        ├── Backend (FastAPI)
                                                        ├── Grafana (Public Dashboards)
                                                        └── ArgoCD (GitOps)
```

## Technology Stack (25+)

| Layer | Technologies |
|-------|-------------|
| Cloud | Oracle Cloud (Ampere A1), Cloudflare |
| Kubernetes | K3s, Helm, Traefik, Cert-Manager |
| GitOps & CI/CD | ArgoCD, GitHub Actions, GHCR |
| Application | FastAPI (Python), React, PostgreSQL, Redis, RabbitMQ |
| Observability | Prometheus, Grafana, Loki, Promtail, Alertmanager |
| Security | Trivy, Sealed Secrets, PSS, Network Policies, Fail2ban |
| IaC | Terraform (OCI provider) |

## Project Status

- [x] Phase 1: Foundation (OCI + K3s + Cloudflare + Traefik + TLS)
- [ ] Phase 2: Application + Data Layer
- [ ] Phase 3: Observability Stack
- [ ] Phase 4: CI/CD + GitOps
- [ ] Phase 5: Hardening + DR
- [ ] Phase 6: Frontend Dashboard + Polish

## Repository Structure

```
terraform/     — Oracle Cloud infrastructure (IaC)
k8s/           — Kubernetes manifests (GitOps source of truth)
apps/          — Application source code (frontend, backend, worker)
.github/       — CI/CD workflows
scripts/       — Operational scripts
docs/          — Architecture docs, runbooks, ADRs
```

## Documentation

- [Architecture & Design](docs/ARCHITECTURE.md)
- [Operations Runbook](docs/RUNBOOK.md)
- [Incident Response](docs/INCIDENT-RESPONSE.md)
- [Disaster Recovery](docs/DISASTER-RECOVERY.md)
- [ADR: K3s over Managed K8s](docs/ADR/001-k3s-over-managed.md)

## Author

**Nupur Shaha** — DevOps Engineer / GCP Cloud Architect

- 📧 shahns079@gmail.com
- 💼 [LinkedIn](https://www.linkedin.com/in/nupur-shaha/)
- 🌐 [Portfolio](https://nupurshaha.github.io)

## Equivalent Cost

This platform runs at **$0/month**. The equivalent cloud spend on AWS/GCP would be **~$120–145/month** ($1,440–1,730/year).
