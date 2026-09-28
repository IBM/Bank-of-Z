#!/usr/bin/env bash
# Test Case: Create Account (CICS CREACC)
# Endpoint    : POST /accounts
# Expectation :
#   1. Valid request returns HTTP 201 with accountId and sortCode fields.
#   2. Request missing required fields returns HTTP 400.
#   3. Request with a non-existent customer number returns HTTP 400 or 404.
#
# Environment variables:
#   BASE_URL       Base URL of the z/OS Connect API server (default: http://localhost:9080/api)
#   BASE_HTTPS_URL HTTPS base URL (skipped when not set)
set -e

# shellcheck source=test-setup.sh
source "$(dirname "$0")/test-setup.sh"

# Use a well-known CICS customer that exists in the sample data set
CUSTOMER_NUMBER="0000000042"
ACCOUNT_TYPE="CURRENT"
TODAY=$(date +%Y-%m-%d)

PASS=0
FAIL=0
SKIP=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL+1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP+1)); }

check_create_account_url() {
    local api_url="$1"

    # ------------------------------------------------------------------
    # 1. Valid create-account request → HTTP 201 with accountId+sortCode
    # ------------------------------------------------------------------
    echo "--- Endpoint : POST ${api_url}/accounts  (valid request)"

    CREATE_RESP=$(curl --silent --max-time 15 --insecure \
        --header "Content-Type: application/json" \
        --write-out "\n%{http_code}" \
        --data "{\"customerNumber\":\"${CUSTOMER_NUMBER}\",\"accountType\":\"${ACCOUNT_TYPE}\",\"interestRate\":1.5,\"overdraftLimit\":200,\"openedDate\":\"${TODAY}\"}" \
        "${api_url}/accounts")

    HTTP_STATUS=$(echo "${CREATE_RESP}" | tail -n1)
    BODY=$(echo "${CREATE_RESP}" | sed '$d')

    echo "    HTTP status : ${HTTP_STATUS}"
    echo "    Response    :"
    echo "${BODY}" | python3 -m json.tool 2>/dev/null || echo "${BODY}"
    echo ""

    ACCOUNT_ID=$(echo "${BODY}" | python3 -c \
        "import sys,json; print(json.load(sys.stdin).get('accountId',''))" 2>/dev/null || true)
    SORT_CODE=$(echo "${BODY}" | python3 -c \
        "import sys,json; print(json.load(sys.stdin).get('sortCode',''))" 2>/dev/null || true)

    if [ "${HTTP_STATUS}" = "201" ]; then
        pass "POST /accounts returned HTTP 201 (${api_url})"
    else
        fail "POST /accounts expected HTTP 201 but got ${HTTP_STATUS} (${api_url})"
    fi

    [ -n "${ACCOUNT_ID}" ] \
        && pass "Response contains accountId=\"${ACCOUNT_ID}\" (${api_url})" \
        || fail "Response is missing accountId field (${api_url})"

    [ -n "${SORT_CODE}" ] \
        && pass "Response contains sortCode=\"${SORT_CODE}\" (${api_url})" \
        || fail "Response is missing sortCode field (${api_url})"

    # ------------------------------------------------------------------
    # 2. Missing required fields → HTTP 400
    # ------------------------------------------------------------------
    echo "--- Endpoint : POST ${api_url}/accounts  (missing accountType → expect 400)"

    MISSING_RESP=$(curl --silent --max-time 15 --insecure \
        --header "Content-Type: application/json" \
        --write-out "\n%{http_code}" \
        --data "{\"customerNumber\":\"${CUSTOMER_NUMBER}\"}" \
        "${api_url}/accounts")

    MISSING_STATUS=$(echo "${MISSING_RESP}" | tail -n1)
    echo "    HTTP status : ${MISSING_STATUS}"
    echo ""

    if [ "${MISSING_STATUS}" = "400" ]; then
        pass "POST /accounts with missing accountType returned HTTP 400 (${api_url})"
    else
        fail "POST /accounts with missing accountType expected HTTP 400 but got ${MISSING_STATUS} (${api_url})"
    fi

    # ------------------------------------------------------------------
    # 3. Non-existent customer → HTTP 400 or 404
    # ------------------------------------------------------------------
    echo "--- Endpoint : POST ${api_url}/accounts  (non-existent customer → expect 400 or 404)"

    NOTFOUND_RESP=$(curl --silent --max-time 15 --insecure \
        --header "Content-Type: application/json" \
        --write-out "\n%{http_code}" \
        --data "{\"customerNumber\":\"9999999999\",\"accountType\":\"SAVING\"}" \
        "${api_url}/accounts")

    NOTFOUND_STATUS=$(echo "${NOTFOUND_RESP}" | tail -n1)
    echo "    HTTP status : ${NOTFOUND_STATUS}"
    echo ""

    if [ "${NOTFOUND_STATUS}" = "400" ] || [ "${NOTFOUND_STATUS}" = "404" ]; then
        pass "POST /accounts with non-existent customer returned HTTP ${NOTFOUND_STATUS} (${api_url})"
    else
        fail "POST /accounts with non-existent customer expected 400 or 404 but got ${NOTFOUND_STATUS} (${api_url})"
    fi
}

echo "=== Test: Create Account (CICS CREACC) ==="
echo ""

check_create_account_url "${BASE_URL}"

if [[ -n "${BASE_HTTPS_URL:-}" ]]; then
    check_create_account_url "${BASE_HTTPS_URL}"
else
    skip "HTTPS API test (ZOSCONNECT_HTTPS_PORT not configured)"
fi

echo "=== Summary: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped ==="
[ "${FAIL}" -eq 0 ] && exit 0 || exit 1
