#!/usr/bin/env bash

set -euo pipefail

API_URL="${API_URL:-http://localhost:8000}"
TIMEOUT="${TIMEOUT:-20}"

log() {
  echo "[$(date +%H:%M:%S)] $*"
}

check_http() {
  local url="$1"
  local label="$2"

  log "Checking ${label}: ${url}"
  curl -fsS --max-time "${TIMEOUT}" "${url}" >/dev/null
}

python_json_check() {
  local label="$1"
  local payload="$2"

  printf '%s' "${payload}" | python3 - "$label" <<'PY'
import json
import sys

label = sys.argv[1]
raw = json.load(sys.stdin)
if not isinstance(raw, dict):
    raise SystemExit(f"{label}: expected JSON object, got {type(raw).__name__}")
if label == 'health' and raw.get('status') != 'healthy':
    raise SystemExit(f"{label}: unexpected health status: {raw}")
if label == 'user' and raw.get('email') is None:
    raise SystemExit(f"{label}: missing email in user payload: {raw}")
PY
}

check_http "${API_URL}/health" "health endpoint"
check_http "${API_URL}/docs" "API docs endpoint"
check_http "${API_URL}/metrics" "metrics endpoint"

log "Checking metrics output for Prometheus labels"
curl -fsS --max-time "${TIMEOUT}" "${API_URL}/metrics" | grep -q 'http_requests_total'

log "Creating a sample user through the API"
USER_EMAIL="smoke-$(date +%s)@example.com"
USER_PAYLOAD="{\"name\":\"Smoke Test\",\"email\":\"${USER_EMAIL}\"}"
USER_RESPONSE_FILE="$(mktemp)"
HTTP_CODE=$(curl -sS --max-time "${TIMEOUT}" -w '%{http_code}' -o "${USER_RESPONSE_FILE}" -X POST "${API_URL}/users" \
  -H 'Content-Type: application/json' \
  -d "${USER_PAYLOAD}")

if [[ "${HTTP_CODE}" != "200" && "${HTTP_CODE}" != "201" ]]; then
  echo "POST /users returned HTTP ${HTTP_CODE}"
  echo "Response body:"
  cat "${USER_RESPONSE_FILE}"
  rm -f "${USER_RESPONSE_FILE}"
  exit 1
fi

python3 - "${USER_RESPONSE_FILE}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
body = path.read_text(encoding='utf-8')
if not body.strip():
    raise SystemExit(f"user creation failed: empty response body")
try:
    raw = json.loads(body)
except json.JSONDecodeError as exc:
    raise SystemExit(f"user creation failed: invalid JSON response: {body[:300]} ({exc})") from exc
if not isinstance(raw, dict) or raw.get('email') is None:
    raise SystemExit(f"user creation failed: unexpected payload: {body[:300]}")
print(f"Created user: {raw.get('email')}")
PY

rm -f "${USER_RESPONSE_FILE}"
log "Smoke test passed for ${API_URL}"
