# Monitoring Setup Guide

## Overview

The API Deployment Demo includes a comprehensive monitoring stack with **automated dashboard deployment**. When monitoring is enabled, Grafana is automatically configured with 4 pre-built dashboards and a Prometheus data source.

## Quick Start

### Enable Monitoring

```bash
# Using make (recommended)
make deploy

# Or using Terraform directly
cd terraform
terraform apply -auto-approve
```

### Access Monitoring

- **Grafana**: <http://localhost:3000> (admin/admin)
- **Prometheus**: <http://localhost:9090>

### View Dashboards

1. Open Grafana: <http://localhost:3000>
2. Login with username `admin`, password `admin`
3. Click **Dashboards** → **Browse** → **API Demo** folder
4. Select any of the 4 pre-loaded dashboards

## Automated Components

### What Gets Deployed Automatically

When `enable_monitoring=true`:

1. **Monitoring Namespace**: `monitoring`
2. **Prometheus Deployment**: Metrics collection service
3. **Grafana Deployment**: Visualization and dashboards
4. **6 ConfigMaps**:
   - `grafana-dashboards-provisioning`: Dashboard provider configuration
   - `grafana-datasource-provisioning`: Prometheus data source
   - `grafana-dashboard-api-performance`: API metrics dashboard
   - `grafana-dashboard-infrastructure`: Kubernetes resource dashboard
   - `grafana-dashboard-database`: PostgreSQL performance dashboard
   - `grafana-dashboard-nginx-traffic`: Nginx/traffic dashboard
5. **Services**: NodePort services for external access
   - Grafana: Port 3000 → NodePort 30300
   - Prometheus: Port 9090 → NodePort 30900

### Dashboard Auto-Discovery

Grafana is configured to automatically discover and load dashboards:

- **Provisioning Directory**: `/etc/grafana/provisioning/dashboards/`
- **Dashboard Files**: `/var/lib/grafana/dashboards/`
- **Scan Interval**: 10 seconds
- **Folder**: All dashboards appear in "API Demo" folder

## Available Dashboards

### 1. API Performance Dashboard

**Focus**: Application performance and health metrics

**Key Panels** (10 total):

- Request rate (req/sec) by endpoint/method
- Response time (p50, p95 percentiles)
- HTTP status code distribution
- Error rate with alerting (>5%)
- Active requests counter
- Total requests (1h window)
- Average response time
- Health status indicator
- Requests by endpoint (pie chart)
- Requests by method (pie chart)

**Use Cases**:

- Monitor API health in real-time
- Identify performance bottlenecks
- Track endpoint usage patterns
- Detect error spikes

---

### 2. Infrastructure & Resource Usage

**Focus**: Kubernetes resources and container metrics

**Key Panels** (9 total):

- CPU usage by pod (percentage)
- Memory usage by pod (MB)
- Total pod count
- Running pods count
- Container restarts (24h) with thresholds
- Network I/O (TX/RX bytes/sec)
- Disk usage by pod
- API deployment replica status
- Node resource pressure table

**Use Cases**:

- Capacity planning
- Identify resource-hungry pods
- Monitor autoscaling behavior
- Detect node issues

---

### 3. Database Performance

**Focus**: PostgreSQL database health and optimization

**Key Panels** (11 total):

- Active connections vs max connections
- Query duration (p50, p95)
- Transactions per second (commits/rollbacks)
- Cache hit ratio gauge (thresholds: <80% red, 80-95% yellow, >95% green)
- Database size (MB)
- Table row counts
- Slow queries (>1 second)
- Lock counts by type
- Replication lag (if applicable)
- Deadlock detection
- Temporary file usage

**Use Cases**:

- Optimize query performance
- Monitor connection pool health
- Identify locking issues
- Track cache efficiency

---

### 4. Nginx & Traffic Overview

**Focus**: Reverse proxy and traffic patterns

**Key Panels** (11 total):

- Nginx requests/sec by server and status
- Response time (p50, p95)
- Active connections
- Waiting connections
- Connection rate (accepted vs handled)
- HTTP status codes (color-coded: 2xx green, 3xx blue, 4xx yellow, 5xx red)
- Traffic distribution (request/response bytes)
- SSL/TLS handshakes (success/failure)
- Upstream response time
- Cache hit rate gauge
- Request method distribution (pie chart)

**Use Cases**:

- Monitor reverse proxy performance
- Track SSL/TLS handshake issues
- Analyze traffic patterns
- Optimize caching strategy

## Technical Implementation

### Terraform Resources

Located in `terraform/monitoring.tf`:

```hcl
# Namespace
resource "kubernetes_namespace" "monitoring"

# Prometheus
resource "kubernetes_deployment" "prometheus"
resource "kubernetes_service" "prometheus"

# Grafana
resource "kubernetes_deployment" "grafana"
resource "kubernetes_service" "grafana"

# Dashboard ConfigMaps (6 total)
resource "kubernetes_config_map" "grafana_dashboards_provisioning"
resource "kubernetes_config_map" "grafana_datasource_provisioning"
resource "kubernetes_config_map" "grafana_dashboard_api_performance"
resource "kubernetes_config_map" "grafana_dashboard_infrastructure"
resource "kubernetes_config_map" "grafana_dashboard_database"
resource "kubernetes_config_map" "grafana_dashboard_nginx_traffic"
```

### Volume Mount Strategy

Grafana pod configuration:

```yaml
volumes:
  - name: dashboards-provisioning
    configMap:
      name: grafana-dashboards-provisioning
  - name: dashboard-api-performance
    configMap:
      name: grafana-dashboard-api-performance
  # ... (3 more dashboard ConfigMaps)

volumeMounts:
  - name: dashboards-provisioning
    mountPath: /etc/grafana/provisioning/dashboards
  - name: dashboard-api-performance
    mountPath: /var/lib/grafana/dashboards/api-performance.json
    subPath: api-performance.json
  # ... (3 more dashboard mounts)
```

### Provisioning Configuration

**Dashboard Provider** (`dashboards.yaml`):

```yaml
apiVersion: 1
providers:
  - name: 'API Demo Dashboards'
    orgId: 1
    folder: 'API Demo'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
```

**Data Source** (`datasource.yaml`):

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
```

## Dashboard Management

### Updating Dashboards

After modifying dashboard JSON files in `monitoring/dashboards/`:

```bash
# Terraform detects changes and updates ConfigMaps
cd terraform
terraform apply \
  -var="environment=production" \
  -var="enable_monitoring=true" \
  -auto-approve

# Restart Grafana to reload dashboards
kubectl rollout restart deployment/grafana -n monitoring

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=60s
```

### Manual Dashboard Import

If you need to import additional dashboards:

1. Open Grafana: <http://localhost:3000>
2. Navigate to **Dashboards** → **Import**
3. Click **Upload JSON file**
4. Select your dashboard file
5. Choose **Prometheus** as data source
6. Click **Import**

### Exporting Dashboards

To export modified dashboards from Grafana:

1. Open the dashboard
2. Click the **Share** icon (top right)
3. Click **Export** tab
4. Click **Save to file**
5. Replace the original JSON file in `monitoring/dashboards/`
6. Re-apply Terraform to update ConfigMap

## Troubleshooting

### Dashboards Not Showing Data

**Verify Prometheus is scraping API pods**:

```bash
# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | "\(.labels.job) - \(.health)"'

# Should show:
# api - up
# api - up (one for each API pod)
# prometheus - up
```

**Generate traffic to populate metrics**:

```bash
# Quick traffic burst
./scripts/continuous-traffic.sh

# Or use the test script
make test-traffic
```

**Check metrics are available**:

```bash
# Query Prometheus directly
curl -s 'http://localhost:9090/api/v1/query?query=http_requests_total' | jq '.data.result[0]'
```

### Dashboards Not Appearing

**Check Grafana Pod**:

```bash
kubectl get pods -n monitoring
kubectl logs -n monitoring -l app=grafana
```

**Verify ConfigMaps**:

```bash
kubectl get configmaps -n monitoring | grep grafana
```

**Check Dashboard Files**:

```bash
kubectl exec -n monitoring $(kubectl get pod -n monitoring -l app=grafana -o jsonpath='{.items[0].metadata.name}') -- \
  ls -la /var/lib/grafana/dashboards/
```

**Check Provisioning Config**:

```bash
kubectl exec -n monitoring $(kubectl get pod -n monitoring -l app=grafana -o jsonpath='{.items[0].metadata.name}') -- \
  cat /etc/grafana/provisioning/dashboards/dashboards.yaml
```

### No Data in Dashboards

**Check Prometheus**:

```bash
# Access Prometheus UI
open http://localhost:9090

# Check targets
curl http://localhost:9090/api/v1/targets

# Test a query
curl 'http://localhost:9090/api/v1/query?query=up'
```

**Verify Data Source in Grafana**:

1. Settings → Data Sources → Prometheus
2. Click **Test** button
3. Should see "Data source is working"

### Prometheus Not Scraping Metrics

**Check Prometheus Targets**:

```bash
# Access Prometheus targets page
open http://localhost:9090/targets
```

**Common Issues**:

- Application not exposing metrics endpoint
- Network policy blocking scraping
- Incorrect service labels/selectors

## Metrics Collection

### Required Metric Exporters

For full dashboard functionality, applications should expose:

**API Metrics**:

- `http_requests_total` - Request counter
- `http_request_duration_seconds` - Request duration histogram
- `http_requests_in_progress` - Active requests gauge
- `api_health_status` - Health status (1=healthy, 0=unhealthy)

**Database Metrics** (requires postgres_exporter):

- `pg_stat_database_*` - Database statistics
- `pg_stat_statements_*` - Query statistics
- `pg_locks_count` - Lock information
- `pg_database_size_bytes` - Database size

**Nginx Metrics** (requires nginx-exporter):

- `nginx_http_requests_total` - Request counter
- `nginx_connections_*` - Connection metrics
- `nginx_ssl_*` - SSL/TLS metrics
- `nginx_cache_status` - Cache statistics

### Adding Custom Metrics

To add custom application metrics:

1. **Instrument Your Code**: Use Prometheus client library
2. **Expose Metrics**: Endpoint at `/metrics`
3. **Configure Scraping**: Add to Prometheus config
4. **Update Dashboard**: Add panels with your metrics
5. **Apply Changes**: Update ConfigMap and restart Grafana

## Security Considerations

### Default Credentials

**Change default Grafana password**:

```bash
# Update in terraform/monitoring.tf
env {
  name  = "GF_SECURITY_ADMIN_PASSWORD"
  value = "your-secure-password"  # Use a secret in production!
}
```

**Better: Use Kubernetes Secret**:

```yaml
env {
  name = "GF_SECURITY_ADMIN_PASSWORD"
  value_from {
    secret_key_ref {
      name = "grafana-admin-credentials"
      key  = "password"
    }
  }
}
```

### Network Policies

Consider restricting access to monitoring namespace:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: monitoring-ingress
  namespace: monitoring
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            name: api-deployment-demo
```

## Best Practices

1. **Regular Backups**: Export and version control dashboard JSON files
2. **Alert Configuration**: Set up Grafana alerts for critical metrics
3. **Data Retention**: Configure Prometheus retention period based on needs
4. **Resource Limits**: Monitor Prometheus/Grafana resource usage
5. **Dashboard Hygiene**: Keep dashboards focused and avoid clutter
6. **Documentation**: Document custom metrics and their meaning

## Additional Resources

- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [PromQL Guide](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/best-practices-for-creating-dashboards/)
