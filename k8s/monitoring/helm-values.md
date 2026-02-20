# Monitoring Stack — Helm Installations

## Prometheus
helm install prometheus prometheus-community/prometheus --namespace monitoring

## Grafana
helm install grafana grafana/grafana --namespace monitoring

## Loki (SingleBinary mode)
helm install loki grafana/loki --namespace monitoring -f loki-values.yaml

## Promtail (kube-system for hostPath access)
helm install promtail grafana/promtail --namespace kube-system

## Imported Dashboards
- K8s Cluster Overview: Grafana ID 15520
- Node Exporter Full: Grafana ID 1860
