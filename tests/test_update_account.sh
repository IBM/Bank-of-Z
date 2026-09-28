#!/usr/bin/env bash
# Test Case: Update Account (CICS UPDACC)
# Endpoint    : PUT /accounts/{accountId}
# Expectation :
#   1. Valid update request returns HTTP 200 with updated account fields.
#   2. Request with invalid field values returns HTTP 400.
#   3. Request for a non-existent account returns HTTP 404.
#
# Environment variables:
#   BASE_URL              Base URL of the z/OS Connect API server (default: http://localhost:9080/api)
#   BASE_HTTPS_URL        HTTPS base URL (skipped when not set)
#   TEST_ACCOUNT_ID       Existing account ID to use for the update test (default: 00000001)
set -e

# shellcheck source=test-setup.sh
source "$(dirname "$0")/test-setup.sh"

# A well-known account that exists in the sample data set
ACCOUNT_ID="${TEST_ACCOUNT_ID:-00000001}"

PASS=0
FAIL=0
SKIP=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL+1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP+1)); }

check_update_account_url() {
    local api_url="$1"

    # ------------------------------------------------------------------
    # 1. Valid update request → HTTP 200 with account fields in response
    # ------------------------------------------------------------------
    echo "--- Endpoint : PUT ${api_url}/accounts/${ACCOUNT_ID}  (valid update)"

    UPDATE_RESP=$(curl --silent --max-time 15 --insecure \
        --header "Content-Type: application/json" \
        --request PUT \
        --write-out "\n%{http_code}" \
        --data '{"accountType":"CURRENT","interestRate":2.0,"overdraftLimit":500}' \
        "${api_url}/accounts/${ACCOUNT_ID}")

    HTTP_STATUS=$(echo "${UPDATE_RESP}" | tail -n1)
    BODY=$(echo "${UPDATE_RESP}" | sed '$d')

    echo "    HTTP status : ${HTTP_STATUS}"
    echo "    Response    :"
    echo "${BODY}" | python3 -m json.tool 2>/dev/null || echo "${BODY}"
    echo ""

    if [ "${HTTP_STATUS}" = "200" ]; then
        pass "PUT /accounts/${ACCOUNT_ID} returned HTTP 200 (${api_url})"
    else
        fail "PUT /accounts/${ACCOUNT_ID} expected HTTP 200 but got ${HTTP_STATUS} (${api_url})"
    fi

    RESP_ACCOUNT_ID=$(echo "${BODY}" | python3 -c \
        "import sys,json; print(json.load(sys.stdin).get('accountId',''))" 2>/dev/null || true)

    [ -n "${RESP_ACCOUNT_ID}" ] \
        && pass "Response contains accountId=\"${RESP_ACCOUNT_ID}\" (${api_url})" \
        || fail "Response is missing accountId field (${api_url})"

    # ------------------------------------------------------------------
    # 2. Invalid field value (interest rate out of range) → HTTP 400
    # ------------------------------------------------------------------
    echo "--- Endpoint : PUT ${api_url}/accounts/${ACCOUNT_ID}  (interestRate=999 → expect 400)"

    INVALID_RESP=$(curl --silent --max-time 15 --insecure \
        --header "Content-Type: application/json" \
        --request PUT \
        --write-out "\n%{http_code}" \
        --data '{"accountType":"CURRENT","interestRate":999,"overdraftLimit":500}' \
        "${api_url}/accounts/${ACCOUNT_ID}")

    INVALID_STATUS=$(echo "${INVALID_RESP}" | tail -n1)
    echo "    HTTP status : ${INVALID_STATUS}"
    echo ""

    if [ "${INVALID_STATUS}" = "400" ]; then
        pass "PUT /accounts with out-of-range interestRate returned HTTP 400 (${api_url})"
    else
        fail "PUT /accounts with out-of-range interestRate expected HTTP 400 but got ${INVALID_STATUS} (${api_url})"
    fi

    # ------------------------------------------------------------------
    # 3. Non-existent account → HTTP 404
    # ------------------------------------------------------------------
    echo "--- Endpoint : PUT ${api_url}/accounts/99999999  (non-existent → expect 404)"

    NOTFOUND_RESP=$(curl --silent --max-time 15 --insecure \
        --header "Content-Type: application/json" \
        --request PUT \
        --write-out "\n%{http_code}" \
        --data '{"accountType":"SAVING","interestRate":1.0,"overdraftLimit":0}' \
        "${api_url}/accounts/99999999")

    NOTFOUND_STATUS=$(echo "${NOTFOUND_RESP}" | tail -n1)
    echo "    HTTP status : ${NOTFOUND_STATUS}"
    echo ""

    if [ "${NOTFOUND_STATUS}" = "404" ]; then
        pass "PUT /accounts/99999999 returned HTTP 404 (${api_url})"
    else
        fail "PUT /accounts/99999999 expected HTTP 404 but got ${NOTFOUND_STATUS} (${api_url})"
    fi
}

echo "=== Test: Update Account (CICS UPDACC) ==="
echo "Account ID  : ${ACCOUNT_ID}"
echo ""

check_update_account_url "${BASE_URL}"

if [[ -n "${BASE_HTTPS_URL:-}" ]]; then
    check_update_account_url "${BASE_HTTPS_URL}"
else
    skip "HTTPS API test (ZOSCONNECT_HTTPS_PORT not configured)"
fi

echo "=== Summary: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped ==="
[ "${FAIL}" -eq 0 ] && exit 0 || exit 1
