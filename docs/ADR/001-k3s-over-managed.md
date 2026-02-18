# ADR-001: K3s Over Managed Kubernetes

**Status:** Accepted  
**Date:** February 2026  
**Author:** Nupur Shaha

## Context

Need Kubernetes for the portfolio project at zero cost. Oracle Kubernetes Engine (OKE) is not part of the Always-Free tier for worker nodes.

## Decision

Use K3s on a single Always-Free Ampere A1 Flex VM (4 cores, 24 GB RAM).

## Consequences

**Positive:**
- Zero cost — runs entirely on Always-Free resources
- Lightweight — K3s uses ~512 MB RAM vs ~2 GB for standard K8s
- Single binary — includes containerd, flannel, CoreDNS, local-path-provisioner
- Stronger portfolio signal — demonstrates ability to operate K8s without managed abstractions

**Negative:**
- Single node — no HA control plane (acceptable for portfolio; DR runbook compensates)
- Manual upgrades — no managed upgrade path
- Limited ecosystem — some K8s operators expect standard distributions

**For production:** Would use 3-node K3s HA with embedded etcd, or GKE/EKS depending on org needs.
