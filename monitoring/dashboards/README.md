# Grafana Dashboards

This directory contains pre-configured Grafana dashboards for monitoring the API Deployment Demo infrastructure.

## Automated Deployment

**Dashboards are automatically deployed when monitoring is enabled!**

When you run:

```bash
make deploy
# or
cd terraform && terraform apply
```

The following happens automatically:

1. **ConfigMaps Created**: All 4 dashboard JSON files are loaded into Kubernetes ConfigMaps
2. **Grafana Provisioning**: Dashboards are mounted into Grafana at `/etc/grafana/provisioning/dashboards/`
3. **Auto-Discovery**: Grafana automatically discovers and loads dashboards on startup
4. **Prometheus Configured**: Prometheus data source is pre-configured and set as default

**No manual import needed!** Just access Grafana at `http://localhost:3000` (admin/admin) and navigate to **Dashboards → Browse → API Demo** folder.

---

## Available Dashboards

### 1. API Performance Dashboard (`api-performance.json`)

**Purpose**: Monitor API application performance and health

**Key Metrics:**

- Request rate (requests/sec) by endpoint and method
- Response time percentiles (p50, p95)
- HTTP status code distribution
- Error rate percentage with alerting (threshold: 5%)
- Active requests in progress
- Total requests per hour
- Average response time
- Health status indicator
- Traffic distribution by endpoint and HTTP method

**Alerts:**

- High error rate (>5%) triggers alert

**Use Cases:**

- Identify performance bottlenecks
- Monitor API health in real-time
- Track endpoint usage patterns
- Detect traffic anomalies

---

### 2. Infrastructure & Resource Usage (`infrastructure.json`)

**Purpose**: Monitor Kubernetes infrastructure and container resources

**Key Metrics:**

- CPU usage by pod (percentage)
- Memory usage by pod (MB)
- Total pod count
- Running pods count
- Container restarts in 24 hours
- Network I/O (transmit/receive bytes per second)
- Disk usage by pod
- API deployment replica status (desired vs available vs ready)
- Node resource pressure (memory, disk, PID)

**Alerts:**

- Container restart threshold monitoring (0=green, 1-4=yellow, 5+=red)

**Use Cases:**

- Capacity planning
- Identify resource-hungry pods
- Monitor autoscaling behavior
- Detect node issues

---

### 3. Database Performance (`database.json`)

**Purpose**: Monitor PostgreSQL database performance and health

**Key Metrics:**

- Active database connections vs max connections
- Query duration percentiles (p50, p95)
- Transactions per second (commits vs rollbacks)
- Cache hit ratio (gauge: 0-100%)
- Database size (MB)
- Table row counts
- Slow queries (>1 second)
- Lock counts by type
- Replication lag (seconds)
- Deadlocks per second
- Temporary file usage

**Alerts:**

- Cache hit ratio (red: <80%, yellow: 80-95%, green: >95%)
- Replication lag (green: <30s, yellow: 30-60s, red: >60s)
- Deadlock detection (green: 0, red: >0)

**Use Cases:**

- Optimize query performance
- Monitor connection pool health
- Identify locking issues
- Track cache efficiency

---

### 4. Nginx & Traffic Overview (`nginx-traffic.json`)

**Purpose**: Monitor Nginx web server and traffic patterns

**Key Metrics:**

- Nginx requests per second by server and status
- Response time percentiles (p50, p95)
- Active connections
- Waiting connections
- Connection rate (accepted vs handled)
- HTTP status code distribution
- Traffic volume (request/response bytes)
- SSL/TLS handshake success/failure rate
- Upstream (backend API) response time
- Cache hit rate (gauge: 0-100%)
- Request method distribution (GET, POST, etc.)

**Alerts:**

- Cache hit rate (red: <50%, yellow: 50-80%, green: >80%)

**Use Cases:**

- Monitor reverse proxy performance
- Track SSL/TLS handshake issues
- Analyze traffic patterns
- Optimize caching strategy

---

## Dashboard Access

Once monitoring is deployed, access your dashboards:

1. **Open Grafana**: `http://localhost:3000`
2. **Login**: Username `admin`, Password `admin`
3. **Navigate**: Click **Dashboards** → **Browse** → **API Demo** folder
4. **Select**: Choose any of the 4 pre-loaded dashboards

All dashboards include:

- **Prometheus Data Source**: Pre-configured and ready to use
- **Real-time Metrics**: Auto-refresh enabled (10-30 seconds)
- **Interactive Graphs**: Click and drag to zoom, hover for details
- **Alert Indicators**: Visual warnings when thresholds are breached

---

## Manual Dashboard Management (Optional)

### Updating Dashboards

If you modify dashboard JSON files locally:

```bash
# Terraform will automatically detect changes and update ConfigMaps
cd terraform
terraform apply -var="environment=production" -var="enable_monitoring=true" -auto-approve

# Restart Grafana to reload dashboards
kubectl rollout restart deployment/grafana -n monitoring
```

### Manual Import (Alternative)

To import dashboards manually via UI:

1. Access Grafana: `http://localhost:3000` (admin/admin)
2. Navigate to **Dashboards** → **Import**
3. Click **Upload JSON file**
4. Select dashboard file from `monitoring/dashboards/`
5. Choose **Prometheus** as data source
6. Click **Import**

### API Import

```bash
# Import via Grafana API
curl -X POST \
  -H "Content-Type: application/json" \
  -d @monitoring/dashboards/api-performance.json \
  http://admin:admin@localhost:3000/api/dashboards/db
```

---

## Technical Details

### Terraform Implementation

Dashboards are deployed via Terraform resources in `terraform/monitoring.tf`:

- **6 ConfigMaps**: 1 provisioning config + 1 datasource config + 4 dashboard configs
- **Volume Mounts**: All ConfigMaps mounted into Grafana pod at `/etc/grafana/provisioning/`
- **Auto-Discovery**: Grafana scans provisioning directory every 10 seconds
- **Data Source**: Prometheus auto-configured at `http://prometheus:9090`

### ConfigMap Structure

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-api-performance
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  api-performance.json: |
    { "dashboard": { ... } }
```

---

## Dashboard Customization

### Modifying Panels

Each dashboard JSON contains a `panels` array. Panel properties:

- `id`: Unique panel identifier
- `title`: Panel display name
- `type`: Visualization type (graph, stat, gauge, piechart, table)
- `gridPos`: Position and size (`x`, `y`, `w`, `h`)
- `targets`: Prometheus queries
- `yaxes`: Y-axis configuration
- `options`: Panel-specific options

### Adding Alerts

Example alert configuration:

```json
"alert": {
  "conditions": [
    {
      "evaluator": {"params": [5], "type": "gt"},
      "operator": {"type": "and"},
      "query": {"params": ["A", "5m", "now"]},
      "reducer": {"params": [], "type": "avg"},
      "type": "query"
    }
  ],
  "name": "High Error Rate Alert"
}
```

### Common Prometheus Queries

```promql
# Request rate
rate(http_requests_total[1m])

# Error rate percentage
100 * (sum(rate(http_requests_total{status=~"5.."}[1m])) / sum(rate(http_requests_total[1m])))

# Response time 95th percentile
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# CPU usage
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="api-deployment-demo"}[5m])) * 100

# Memory usage
sum by (pod) (container_memory_usage_bytes{namespace="api-deployment-demo"}) / 1024 / 1024
```

---

## Troubleshooting

### No Data Showing

1. **Check Prometheus is scraping metrics:**

   ```bash
   curl http://localhost:9090/api/v1/targets
   ```

2. **Verify metrics exist:**

   ```bash
   curl http://localhost:9090/api/v1/query?query=up
   ```

3. **Check Grafana data source:**
   - Settings → Data Sources → Prometheus
   - Click "Test" button

### Dashboard Not Loading

1. **Check JSON syntax:**

   ```bash
   cat dashboard.json | jq .
   ```

2. **Verify Grafana version compatibility:**
   - Dashboard `schemaVersion` should match Grafana version

3. **Check Grafana logs:**

   ```bash
   kubectl logs -n production -l app=grafana
   ```

### Queries Returning Empty

1. **Verify label selectors match your deployment:**
   - `namespace="api-deployment-demo"`
   - `app="api-demo"`

2. **Check metric names in Prometheus:**

   ```bash
   curl http://localhost:9090/api/v1/label/__name__/values
   ```

3. **Adjust time range** in dashboard settings

---

## Best Practices

1. **Dashboard Organization:**
   - Group related metrics on same row
   - Use consistent color schemes
   - Limit panels per dashboard (10-15 max)

2. **Performance:**
   - Use appropriate time ranges for queries
   - Avoid overly complex PromQL expressions
   - Set reasonable refresh intervals

3. **Alerting:**
   - Set meaningful thresholds
   - Use notification channels
   - Document alert response procedures

4. **Maintenance:**
   - Version control dashboard JSON files
   - Document custom modifications
   - Test dashboards after Grafana upgrades

---

## Additional Resources

- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Querying](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/best-practices-for-creating-dashboards/)
- [PromQL Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)
