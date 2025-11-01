# Archived Scripts

This directory contains scripts that have been archived due to being obsolete or superseded by more modern automation approaches.

## Archived on: October 31, 2025

### Port-Forwarding Related Scripts (Obsolete)
These scripts used manual port-forwarding, which is no longer needed due to Kind cluster port mapping configuration:

- **`start-monitoring.sh`** - Manual port-forwarding for Grafana/Prometheus
- **`verify-dashboard.sh`** - Uses port-forwarding for dashboard verification

### Redundant Setup Scripts
These scripts provided manual setup functionality that is now automated through the Makefile:

- **`setup-local-cluster.sh`** - Manual cluster setup (replaced by `make kind-cluster`)
- **`enable-https.sh`** - Manual HTTPS setup (replaced by Makefile SSL automation)
- **`health-check-host.sh`** - Manual health checking (replaced by Makefile health checks)
- **`verify-cleanup.sh`** - Manual cleanup verification (replaced by `make clean-*` targets)
- **`verify-monitoring.sh`** - Manual monitoring verification (replaced by `make monitoring-status`)

### Demo/Documentation Scripts
These scripts were used for demonstrations but may no longer be current:

- **`demo-architecture.sh`** - Architecture demonstration script
- **`demo-automation.sh`** - Automation benefits demonstration
- **`test-configuration.sh`** - Large configuration test script (overlaps with `test-production-deployment.sh`)

## Current Active Scripts (Located in parent directory)

Essential scripts still in use by the Makefile automation:

- `generate-secrets.sh` - Environment-based secret generation
- `generate-traffic.sh` - Test traffic generation for dashboards
- `get-grafana-password.sh` - Secure Grafana password retrieval
- `validate-ssl-certificates.sh` - SSL certificate generation and validation
- `cleanup-all.sh` - Comprehensive environment cleanup
- `test-automated-deployment.sh` - Automated deployment testing
- `test-production-deployment.sh` - Production deployment validation
- `promote-to-production.sh` - Production promotion workflow

## Why These Were Archived

1. **Port Mapping Evolution**: Kind cluster now uses direct port mapping (80→30080, 443→30443, etc.), eliminating the need for manual port-forwarding scripts.

2. **Makefile Automation**: The comprehensive Makefile now handles all setup, deployment, monitoring, and cleanup operations automatically.

3. **Reduced Complexity**: Modern setup focuses on `make` commands rather than individual script execution.

4. **Maintenance Burden**: These scripts required manual updates and could become stale compared to the actively maintained Makefile targets.

## Recovery

If any of these scripts are needed in the future, they can be moved back to the parent scripts directory. However, consider updating them to work with the current port mapping and automation setup first.