#!/usr/bin/env bash
# Test Case: Get Customer Details (CICS path)
# Customer ID : C0000001 (CICS customer, numeric ID 0000001)
# Endpoint    : GET /api/customers/{customerId} on HTTP and HTTPS ports
# Expectation : lastName == "Higins" on both ports (HTTPS skipped when not configured)
#
# Environment variables:
#   BASE_URL       Base URL of the z/OS Connect API server (default: http://localhost:9080/api)
#   BASE_HTTPS_URL HTTPS base URL (default: https://localhost:9444/api; skipped when not set)
set -e

# shellcheck source=test-setup.sh
source "$(dirname "$0")/test-setup.sh"

CUSTOMER_ID="0000001"           # Strip the C prefix as per frontend parseCustomerId logic
EXPECTED_LAST_NAME="Higins"
PASS=0
FAIL=0
SKIP=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL+1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP+1)); }

check_customer_url() {
    local api_url="$1"
    echo "--- Endpoint : GET ${api_url}/customers/${CUSTOMER_ID}"

    RESPONSE=$(curl --silent --max-time 10 --insecure \
        --header "Content-Type: application/json" \
        "${api_url}/customers/${CUSTOMER_ID}")

    echo "    Response:"
    echo "${RESPONSE}" | python3 -m json.tool 2>/dev/null || echo "${RESPONSE}"

    ACTUAL_LAST_NAME=$(echo "${RESPONSE}" | python3 -c \
        "import sys,json; print(json.load(sys.stdin).get('lastName',''))" 2>/dev/null || true)

    if [ "${ACTUAL_LAST_NAME}" = "${EXPECTED_LAST_NAME}" ]; then
        pass "lastName is \"${ACTUAL_LAST_NAME}\" as expected (${api_url})"
    else
        fail "expected lastName \"${EXPECTED_LAST_NAME}\" but got \"${ACTUAL_LAST_NAME}\" (${api_url})"
    fi
    echo ""
}

echo "=== Test: Get Customer Details (CICS) ==="
echo "Customer ID : C${CUSTOMER_ID}"
echo ""

check_customer_url "${BASE_URL}"

if [[ -n "${BASE_HTTPS_URL:-}" ]]; then
    check_customer_url "${BASE_HTTPS_URL}"
else
    skip "HTTPS API test (ZOSCONNECT_HTTPS_PORT not configured)"
fi

echo "=== Summary: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped ==="
[ "${FAIL}" -eq 0 ] && exit 0 || exit 1
