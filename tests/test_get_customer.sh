#!/usr/bin/env bash
# Test Case: Get Customer Details
# Customer ID : C0000001 (CICS customer, numeric ID 0000001)
# Endpoint    : GET /api/customers/{customerId}
# Expectation : lastName == "Higins"
set -eu

BASE_URL="http://9.47.80.84:9080/api"
CUSTOMER_ID="0000001"           # Strip the C prefix as per frontend parseCustomerId logic
EXPECTED_LAST_NAME="Higins"

echo "=== Test: Get Customer Details ==="
echo "Customer ID : C${CUSTOMER_ID}"
echo "Endpoint    : GET ${BASE_URL}/customers/${CUSTOMER_ID}"
echo ""

RESPONSE=$(curl --silent --max-time 10 \
    --header "Content-Type: application/json" \
    "${BASE_URL}/customers/${CUSTOMER_ID}")

echo "Response:"
echo "${RESPONSE}" | python3 -m json.tool 2>/dev/null || echo "${RESPONSE}"
echo ""

# Extract lastName from the JSON response
ACTUAL_LAST_NAME=$(echo "${RESPONSE}" | python3 -c \
    "import sys,json; print(json.load(sys.stdin).get('lastName',''))" 2>/dev/null || true)

if [ "${ACTUAL_LAST_NAME}" = "${EXPECTED_LAST_NAME}" ]; then
    echo "PASS: lastName is \"${ACTUAL_LAST_NAME}\" as expected"
    exit 0
else
    echo "FAIL: expected lastName \"${EXPECTED_LAST_NAME}\" but got \"${ACTUAL_LAST_NAME}\"" >&2
    exit 1
fi
