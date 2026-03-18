# Monitoring Guide

Complete guide to Prometheus and Grafana monitoring with **automated dashboard deployment**.

## Table of Contents

- [Quick Start](#quick-start)
- [What Gets Deployed](#what-gets-deployed)
- [Grafana Dashboards](#grafana-dashboards)
- [Using the Dashboards](#using-the-dashboards)
- [Troubleshooting](#troubleshooting)
- [Configuration](#configuration)

---

## Quick Start

### Deploy Monitoring Stack

```bash
# One-command deployment (recommended)
make production

# Or step-by-step
make apply    # Terraform deploys monitoring stack
make config   # Ansible configures resources
```

### Access Services

| Service        | URL                     | Credentials   |
| -------------- | ----------------------- | ------------- |
| **Grafana**    | <http://localhost:3000> | admin / admin |
| **Prometheus** | <http://localhost:9090> | (none)        |

### View Dashboards

1. Open Grafana at <http://localhost:3000>
2. Login with username `admin`, password `admin`
3. Navigate: **Dashboards → Browse → API Demo** folder
4. Select any of the 4 pre-loaded dashboards

**No manual import needed!** Dashboards are automatically provisioned.

---

## What Gets Deployed

When `enable_monitoring=true` (default), Terraform automatically provisions:

### Components

| Component              | Purpose                     | Port         |
| ---------------------- | --------------------------- | ------------ |
| **Prometheus**         | Metrics collection          | 9090 → 30900 |
| **Grafana**            | Visualization & dashboards  | 3000 → 30300 |
| **Metrics Server**     | Kubernetes resource metrics | (internal)   |
| **Kube-State-Metrics** | Cluster state metrics       | (internal)   |

### ConfigMaps (6 total)

- `grafana-dashboards-provisioning` - Dashboard auto-discovery config
- `grafana-datasource-provisioning` - Prometheus data source
- `grafana-dashboard-api-performance` - API metrics dashboard
- `grafana-dashboard-infrastructure` - Kubernetes resources dashboard
- `grafana-dashboard-database` - PostgreSQL performance dashboard
- `grafana-dashboard-nginx-traffic` - Nginx/traffic dashboard

### How Auto-Provisioning Works

1. **ConfigMaps Created**: Dashboard JSON files loaded into ConfigMaps
2. **Volume Mounts**: ConfigMaps mounted into Grafana pod
3. **Auto-Discovery**: Grafana scans `/etc/grafana/provisioning/` every 10 seconds
4. **Data Source**: Prometheus pre-configured at `http://prometheus:9090`

---

## Grafana Dashboards

### 1. API Performance Dashboard

**Focus**: Application performance and health

**Key Metrics** (10 panels):

- Request rate (req/sec) by endpoint and method
- Response time percentiles (p50, p95)
- HTTP status code distribution (2xx/3xx/4xx/5xx)
- Error rate with alerting (threshold: 5%)
- Active requests counter
- Total requests (1h window)
- Average response time
- Health status indicator
- Traffic by endpoint (pie chart)
- Traffic by method (pie chart)

**Use Cases**:

- Monitor API health in real-time
- Identify performance bottlenecks
- Track endpoint usage patterns
- Detect error spikes

---

### 2. Infrastructure & Resource Usage

**Focus**: Kubernetes resources and container metrics

**Key Metrics** (9 panels):

- CPU usage by pod (%)
- Memory usage by pod (MB)
- Total pod count
- Running pods count
- Container restarts (24h) with thresholds
- Network I/O (transmit/receive bytes/sec)
- Disk usage by pod
- API deployment replica status (desired/available/ready)
- Node resource pressure (memory, disk, PID)

**Alerts**:

- Container restart monitoring (0=green, 1-4=yellow, 5+=red)

**Use Cases**:

- Capacity planning
- Identify resource-hungry pods
- Monitor autoscaling behavior
- Detect node issues

---

### 3. Database Performance

**Focus**: PostgreSQL health and optimization

**Key Metrics** (11 panels):

- Active connections vs max connections
- Query duration percentiles (p50, p95)
- Transactions per second (commits vs rollbacks)
- Cache hit ratio gauge (alerts: <80% red, 80-95% yellow, >95% green)
- Database size (MB)
- Table row counts
- Slow queries (>1 second)
- Lock counts by type
- Replication lag (if applicable)
- Deadlock detection (green: 0, red: >0)
- Temporary file usage

**Use Cases**:

- Optimize query performance
- Monitor connection pool health
- Identify locking issues
- Track cache efficiency

---

### 4. Nginx & Traffic Overview

**Focus**: Reverse proxy and traffic patterns

**Key Metrics** (11 panels):

- Nginx requests/sec by server and status
- Response time percentiles (p50, p95)
- Active connections and waiting connections
- Connection rate (accepted vs handled)
- HTTP status codes (color-coded: 2xx green, 3xx blue, 4xx yellow, 5xx red)
- Traffic volume (request/response bytes)
- SSL/TLS handshake success/failure rate
- Upstream (backend API) response time
- Cache hit rate gauge (alerts: <50% red, 50-80% yellow, >80% green)
- Request method distribution (pie chart)

**Use Cases**:

- Monitor reverse proxy performance
- Track SSL/TLS handshake issues
- Analyze traffic patterns
- Optimize caching strategy

---

## Using the Dashboards

### Dashboard Features

- **Auto-refresh**: 10-30 seconds (configurable per dashboard)
- **Time range**: Last 1-6 hours (adjustable via top-right selector)
- **Interactive**: Click and drag to zoom, hover for details
- **Alerts**: Visual warnings when thresholds breached

### Generating Traffic for Testing

Dashboards show data only when metrics exist. Generate traffic:

```bash
# Continuous traffic (runs in background)
./scripts/continuous-traffic.sh

# Or quick test
make test-traffic

# Load test (high volume)
make test-load
```

### Common PromQL Queries

**Request rate:**

```promql
rate(http_requests_total[1m])
```

**Error rate percentage:**

```promql
100 * (sum(rate(http_requests_total{status=~"5.."}[1m])) / sum(rate(http_requests_total[1m])))
```

**Response time 95th percentile:**

```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

**CPU usage by pod:**

```promql
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="api-deployment-demo"}[5m])) * 100
```

**Memory usage by pod (MB):**

```promql
sum by (pod) (container_memory_usage_bytes{namespace="api-deployment-demo"}) / 1024 / 1024
```

---

## Troubleshooting

### Dashboards Show No Data

**1. Verify Prometheus is scraping:**

```bash
# Check targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | "\(.labels.job) - \(.health)"'

# Should show:
# api - up
# prometheus - up
```

**2. Test a query:**

```bash
curl 'http://localhost:9090/api/v1/query?query=up'
```

**3. Check Grafana data source:**

- Settings → Data Sources → Prometheus
- Click **Test** button (should show "Data source is working")

**4. Generate traffic:**

```bash
./scripts/continuous-traffic.sh
```

### Dashboards Not Appearing

**Check Grafana pod:**

```bash
kubectl get pods -n monitoring
kubectl logs -n monitoring -l app=grafana
```

**Verify ConfigMaps:**

```bash
kubectl get configmaps -n monitoring | grep grafana
```

**Check mounted dashboard files:**

```bash
kubectl exec -n monitoring $(kubectl get pod -n monitoring -l app=grafana -o jsonpath='{.items[0].metadata.name}') -- \
  ls -la /var/lib/grafana/dashboards/
```

### Prometheus Not Scraping

**Access Prometheus UI:**

```bash
open http://localhost:9090/targets
```

**Common issues:**

- Application not exposing `/metrics` endpoint
- Network policy blocking scraping
- Incorrect service labels/selectors

---

## Configuration

### Updating Dashboards

After modifying dashboard JSON files in `monitoring/dashboards/`:

```bash
# Terraform detects changes and updates ConfigMaps
cd terraform
terraform apply -auto-approve

# Restart Grafana to reload
kubectl rollout restart deployment/grafana -n monitoring

# Wait for ready
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=60s
```

### Exporting Modified Dashboards

If you customize dashboards in the UI:

1. Open the dashboard
2. Click **Share** icon (top right)
3. Click **Export** tab
4. Click **Save to file**
5. Replace original JSON in `monitoring/dashboards/`
6. Re-apply Terraform to persist changes

### Changing Grafana Password

## Method 1: Environment variable (Terraform)

Edit `terraform/monitoring.tf`:

```hcl
env {
  name  = "GF_SECURITY_ADMIN_PASSWORD"
  value = "your-secure-password"
}
```

## Method 2: Kubernetes Secret (Recommended)

```bash
# Create secret
kubectl create secret generic grafana-admin-secret \
  -n monitoring \
  --from-literal=admin-password=your-secure-password

# Update deployment to use secret
# (See terraform/monitoring.tf for secret reference example)
```

### Required Metrics

For full dashboard functionality, applications should expose:

**API Metrics:**

- `http_requests_total` - Request counter
- `http_request_duration_seconds` - Duration histogram
- `http_requests_in_progress` - Active requests gauge
- `api_health_status` - Health status (1=healthy, 0=unhealthy)

**Database Metrics** (postgres_exporter):

- `pg_stat_database_*` - Database statistics
- `pg_stat_statements_*` - Query statistics
- `pg_locks_count` - Lock information
- `pg_database_size_bytes` - Database size

**Nginx Metrics** (nginx-exporter):

- `nginx_http_requests_total` - Request counter
- `nginx_connections_*` - Connection metrics
- `nginx_ssl_*` - SSL/TLS metrics
- `nginx_cache_status` - Cache statistics

---

## Best Practices

1. **Regular Backups**: Version control dashboard JSON files
2. **Alert Configuration**: Set up alerts for critical metrics
3. **Data Retention**: Configure Prometheus retention (default: 15 days)
4. **Resource Limits**: Monitor Prometheus/Grafana resource usage
5. **Dashboard Hygiene**: Keep focused, avoid clutter (10-15 panels max)
6. **Documentation**: Document custom metrics and thresholds

---

## Additional Resources

- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [PromQL Guide](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/best-practices-for-creating-dashboards/)
