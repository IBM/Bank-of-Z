#!/usr/bin/env bash
# Test Case: Get Customer Details (IMS path)
# Customer ID : 000000015 (IMS customer — routed via /api/ims/)
# Endpoints   : GET /api/ims/customers/{customerId}
#               GET /api/ims/customers/{customerId}/accounts
#               GET /api/ims/accounts/{customerId}/balances
# Expectation : customer fields present, accounts list non-empty, balances returned
#
# Environment variables:
#   BASE_URL   Base URL of the z/OS Connect API server (default: http://localhost:9080/api)
set -eu

# shellcheck source=test-setup.sh
source "$(dirname "$0")/test-setup.sh"
CUSTOMER_ID="000000015"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL+1)); }

# ---------------------------------------------------------------------------
# 1. GET /api/ims/customers/{customerId}
# ---------------------------------------------------------------------------
echo "=== Test: Get Customer Details (IMS) ==="
echo "Endpoint : GET ${BASE_URL}/ims/customers/${CUSTOMER_ID}"
echo ""

CUSTOMER_RESP=$(curl --silent --max-time 10 \
    --header "Content-Type: application/json" \
    "${BASE_URL}/ims/customers/${CUSTOMER_ID}")

echo "Response:"
echo "${CUSTOMER_RESP}" | python3 -m json.tool 2>/dev/null || echo "${CUSTOMER_RESP}"
echo ""

LAST_NAME=$(echo "${CUSTOMER_RESP}" | python3 -c \
    "import sys,json; print(json.load(sys.stdin).get('lastName',''))" 2>/dev/null || true)
FIRST_NAME=$(echo "${CUSTOMER_RESP}" | python3 -c \
    "import sys,json; print(json.load(sys.stdin).get('firstName',''))" 2>/dev/null || true)
CUST_STATUS=$(echo "${CUSTOMER_RESP}" | python3 -c \
    "import sys,json; print(json.load(sys.stdin).get('customerStatus',''))" 2>/dev/null || true)
RESP_CUST_ID=$(echo "${CUSTOMER_RESP}" | python3 -c \
    "import sys,json; print(json.load(sys.stdin).get('customerId',''))" 2>/dev/null || true)

[ -n "${LAST_NAME}" ]    && pass "lastName is \"${LAST_NAME}\""      || fail "lastName is empty or missing"
[ -n "${FIRST_NAME}" ]   && pass "firstName is \"${FIRST_NAME}\""    || fail "firstName is empty or missing"
[ -n "${CUST_STATUS}" ]  && pass "customerStatus is \"${CUST_STATUS}\"" || fail "customerStatus is empty or missing"
[ "${RESP_CUST_ID}" = "${CUSTOMER_ID}" ] \
    && pass "customerId matches \"${CUSTOMER_ID}\"" \
    || fail "customerId mismatch: expected \"${CUSTOMER_ID}\", got \"${RESP_CUST_ID}\""

echo ""

# ---------------------------------------------------------------------------
# 2. GET /api/ims/customers/{customerId}/accounts
# ---------------------------------------------------------------------------
echo "=== Test: Get Customer Accounts (IMS) ==="
echo "Endpoint : GET ${BASE_URL}/ims/customers/${CUSTOMER_ID}/accounts"
echo ""

ACCOUNTS_RESP=$(curl --silent --max-time 10 \
    --header "Content-Type: application/json" \
    "${BASE_URL}/ims/customers/${CUSTOMER_ID}/accounts")

echo "Response:"
echo "${ACCOUNTS_RESP}" | python3 -m json.tool 2>/dev/null || echo "${ACCOUNTS_RESP}"
echo ""

ACCOUNT_COUNT=$(echo "${ACCOUNTS_RESP}" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(len(d.get('accounts',[])))" 2>/dev/null || true)

[ "${ACCOUNT_COUNT:-0}" -gt 0 ] \
    && pass "accounts list has ${ACCOUNT_COUNT} entry/entries" \
    || fail "accounts list is empty or missing"

echo ""

# ---------------------------------------------------------------------------
# 3. GET /api/ims/accounts/{customerId}/balances
# ---------------------------------------------------------------------------
echo "=== Test: Get Account Balances (IMS) ==="
echo "Endpoint : GET ${BASE_URL}/ims/accounts/${CUSTOMER_ID}/balances"
echo ""

BALANCES_RESP=$(curl --silent --max-time 10 \
    --header "Content-Type: application/json" \
    "${BASE_URL}/ims/accounts/${CUSTOMER_ID}/balances")

echo "Response:"
echo "${BALANCES_RESP}" | python3 -m json.tool 2>/dev/null || echo "${BALANCES_RESP}"
echo ""

BALANCE_TYPE=$(echo "${BALANCES_RESP}" | python3 -c \
    "import sys,json; print(json.load(sys.stdin).get('balanceType',''))" 2>/dev/null || true)
AMOUNT_COUNT=$(echo "${BALANCES_RESP}" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(len(d.get('amount',[])))" 2>/dev/null || true)

[ -n "${BALANCE_TYPE}" ]         && pass "balanceType is \"${BALANCE_TYPE}\""         || fail "balanceType is empty or missing"
[ "${AMOUNT_COUNT:-0}" -gt 0 ]   && pass "amount array has ${AMOUNT_COUNT} entry/entries" || fail "amount array is empty or missing"

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Summary: ${PASS} passed, ${FAIL} failed ==="
[ "${FAIL}" -eq 0 ] && exit 0 || exit 1
