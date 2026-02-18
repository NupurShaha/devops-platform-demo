# ADR-004: Single-Node Acceptable for Portfolio

**Status:** Accepted  
**Date:** February 2026  
**Author:** Nupur Shaha

## Context

Production Kubernetes clusters use 3+ nodes for HA. This portfolio project runs on a single Always-Free VM.

## Decision

Accept single-node K3s without HA. Implement comprehensive DR runbooks to compensate.

## Rationale

- Purpose is to demonstrate skills, not run a production SaaS
- 99%+ uptime achievable with K3s self-healing + UptimeRobot monitoring
- Full VM rebuild takes < 45 minutes (documented and tested)
- DR documentation demonstrates MORE operational maturity than many production setups

## Interview Talking Point

"For a portfolio project, single-node K3s demonstrates I can run Kubernetes without a managed control plane. In production, I'd use a 3-node K3s HA setup with embedded etcd or move to GKE/EKS. The DR runbook in my repo covers full VM rebuild in under 45 minutes, and I've tested it."
