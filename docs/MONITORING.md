# Monitoring Guide

Monitoring is deployed with the main stack using Kustomize + Ansible.

## Components

- Prometheus
- Grafana
- Metrics Server
- Kube State Metrics

## Access

- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090

Get Grafana credentials:

```bash
make get-secrets
```

## Verification

```bash
make status
make verify-metrics
kubectl get pods -n api-monitoring-ns -l app=prometheus
kubectl get pods -n api-monitoring-ns -l app=grafana
```

## Dashboards

Dashboard JSON lives under:

- `kustomize/monitoring/base/dashboards/`

Provisioning manifests live under:

- `kustomize/monitoring/base/grafana-config.yaml`
- `kustomize/monitoring/base/kustomization.yaml` (via `configMapGenerator`)

## Troubleshooting

Check Grafana logs:

```bash
make logs-grafana
```

Check Prometheus logs:

```bash
make logs-prometheus
```

Check service endpoints:

```bash
kubectl get svc -n api-monitoring-ns
```
