# Changelog

## [2026-01-12] Performance & Reliability Improvements

### Autoscaling Enhancements

- **HPA CPU Threshold**: Reduced from 70% to 50% for more responsive scaling
  - File: [terraform/hpa.tf](terraform/hpa.tf)
  - Triggers autoscaling earlier to handle traffic spikes more effectively
  - Maintains min 2 replicas, scales up to 10 replicas
  - Aggressive scale-up policy: 100% or 4 pods per 15 seconds

- **HPA Metrics Reliability**: Improved dependency management
  - Added `kubernetes_api_service_v1.metrics_server` to HPA dependencies
  - Ensures metrics API is fully registered before HPA starts
  - Reduces "failed to get metrics" warnings during startup

### Metrics Server Improvements

- **Readiness Probe**: Increased initial delay from 20s to 30s
  - File: [terraform/monitoring.tf](terraform/monitoring.tf)
  - Allows more time for metrics server to fully initialize
  - Reduces premature readiness failures

- **Verification Tooling**: Added metrics verification script
  - File: [scripts/verify-metrics.sh](scripts/verify-metrics.sh)
  - Command: `make verify-metrics`
  - Diagnoses metrics server and HPA issues
  - Provides troubleshooting recommendations

### Load Testing Improvements

- **Stress Endpoint**: Increased CPU intensity from 10,000 to 75,000 prime calculations
  - File: [api/main.py](api/main.py)
  - Generates significantly higher CPU load for HPA testing
  - Better demonstrates autoscaling behavior under realistic conditions

### Health Check Resilience

- **Startup Probe**: Added dedicated startup probe for initial container startup
  - File: [terraform/production.tf](terraform/production.tf)
  - 120 seconds max startup time (12 failures × 10s)
  - Separates startup time from liveness checks
  - Prevents premature restarts during initialization

- **Liveness Probe**: Enhanced configuration for high CPU load scenarios
  - Removed `initial_delay_seconds` (handled by startup probe)
  - Period: 10s → **30s** (checks less frequently)
  - Timeout: 5s → **10s** (more time for saturated pods to respond)
  - Failure threshold: 5 → **6**
  - Total grace: **180 seconds** (6 × 30s) before pod restart
  - Prevents restarts during CPU-intensive operations like load tests
  
- **Readiness Probe**: Improved timeout handling
  - Timeout: 5s → **10s**
  - Period: 5s → **10s**
  - Failure threshold: **3** (unchanged)
  - Total grace: **30 seconds** before traffic removal

### Code Modernization

- **FastAPI Lifespan Events**: Migrated from deprecated `@app.on_event()`
  - File: [api/main.py](api/main.py)
  - Implemented modern `@asynccontextmanager` pattern
  - Added `contextlib.asynccontextmanager` import
  - Better resource management for startup/shutdown

### Bug Fixes

- **Terraform Path Resolution**: Fixed path references in Docker and staging resources
  - Files: [terraform/docker.tf](terraform/docker.tf), [terraform/staging.tf](terraform/staging.tf)
  - Changed `path.cwd` to `path.module` for correct resolution
  - Wrapped paths with `abspath()` for Docker volume mounts
  - Resolves "not a directory" and "must be an absolute path" errors

### Documentation Updates

- **Load Test Scripts**: Updated references from 70% to 50% CPU threshold
  - File: [scripts/load-test.sh](scripts/load-test.sh)
  - Reflects new HPA configuration
  - Updated expected behavior messaging

- **Terraform Outputs**: Added autoscaling and health check configuration details
  - File: [terraform/outputs.tf](terraform/outputs.tf)
  - New `autoscaling_config` output
  - New `health_check_config` output
  - Improved visibility into deployment configuration

- **Makefile**: Added metrics verification command
  - Command: `make verify-metrics`
  - Quick diagnostics for HPA and metrics server issues

## Testing

After applying these changes, verify with:

```bash
# Apply infrastructure changes
terraform -chdir=terraform apply -auto-approve

# Verify metrics server is working
make verify-metrics

# Rebuild and deploy updated API
make production-deploy

# Test autoscaling behavior
make test-load
```

## Expected Results

- HPA should trigger scaling at 50% CPU (previously 70%)
- Load tests should generate higher CPU usage
- Health check warnings should be eliminated
- No deprecation warnings from FastAPI
- Faster and more aggressive pod scaling under load
- Reduced "failed to get metrics" warnings (transient warnings during startup are normal)

## Troubleshooting

If you see "failed to get metrics" warnings:

1. Run `make verify-metrics` to diagnose the issue
2. Wait 30-60 seconds for metrics server to collect initial data
3. Warnings during pod startup are normal and self-resolve
4. Check metrics server logs: `kubectl logs -n kube-system -l app=metrics-server`
