#!/usr/bin/env bash
# Test Case: Frontend availability
# Endpoint    : GET /admin.html on the Frontend Liberty server
# Expectation : HTTP 200 on HTTP port; HTTP 200 on HTTPS port (skipped when not configured)
#
# Environment variables:
#   FRONTEND_URL        Base URL of the Frontend Liberty server (default: http://localhost:9081)
#   FRONTEND_HTTPS_URL  HTTPS base URL (default: https://localhost:9445; skipped when not set)
set -e

# shellcheck source=test-setup.sh
source "$(dirname "$0")/test-setup.sh"

PASS=0
FAIL=0
SKIP=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL+1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP+1)); }

check_admin_url() {
    local url="$1"
    echo "--- Endpoint : GET ${url}"
    HTTP_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" \
        --max-time 10 --insecure "${url}" || true)
    echo "    HTTP status : ${HTTP_STATUS:-000}"
    if [ "${HTTP_STATUS}" = "200" ]; then
        pass "${url} returned HTTP 200"
    else
        fail "${url} returned HTTP ${HTTP_STATUS:-000}"
    fi
    echo ""
}

echo "=== Test: Frontend Availability ==="
echo ""

check_admin_url "${ADMIN_URL}"

if [[ -n "${ADMIN_HTTPS_URL:-}" ]]; then
    check_admin_url "${ADMIN_HTTPS_URL}"
else
    skip "HTTPS frontend test (FRONTEND_HTTPS_PORT not configured)"
fi

echo "=== Summary: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped ==="
[ "${FAIL}" -eq 0 ] && exit 0 || exit 1
