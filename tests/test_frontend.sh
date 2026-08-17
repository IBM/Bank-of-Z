#!/usr/bin/env bash
# Test Case: Frontend availability
# Endpoint    : GET /admin.html on the Frontend Liberty server
# Expectation : HTTP 200
#
# Environment variables:
#   FRONTEND_URL   Base URL of the Frontend Liberty server (default: http://9.47.80.84:9081)
set -eu

FRONTEND_URL="${FRONTEND_URL:-http://9.47.80.84:9081}"
ADMIN_URL="${FRONTEND_URL}/admin.html"

echo "=== Test: Frontend Availability ==="
echo "Endpoint : GET ${ADMIN_URL}"
echo ""

HTTP_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" \
    --max-time 10 --insecure "${ADMIN_URL}" || true)
CURL_EXIT=$?

echo "HTTP status : ${HTTP_STATUS:-000}  (curl exit: ${CURL_EXIT})"
echo ""

if [ "${HTTP_STATUS}" = "200" ]; then
    echo "PASS: ${ADMIN_URL} returned HTTP 200"
    exit 0
fi

echo "FAIL: ${ADMIN_URL} returned HTTP ${HTTP_STATUS:-000} (curl exit code: ${CURL_EXIT})" >&2
# curl exit codes: 6=DNS failure, 7=connection refused, 28=timeout, 35=SSL error
exit 1
