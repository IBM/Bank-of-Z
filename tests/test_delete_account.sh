#!/usr/bin/env bash
# Test Case: Delete Account (CICS DELACC)
# Endpoint    : DELETE /accounts/{accountId}
# Expectation :
#   1. Deleting a just-created account returns HTTP 204 (no body).
#   2. Deleting the same account a second time returns HTTP 404 (already gone).
#   3. DELETE for a non-existent account ID returns HTTP 404.
#
# The test creates a fresh account via POST /accounts first so that it does
# not destroy any fixed sample-data accounts.
#
# Environment variables:
#   BASE_URL              Base URL of the z/OS Connect API server (default: http://localhost:9080/api)
#   BASE_HTTPS_URL        HTTPS base URL (skipped when not set)
#   DELETE_CUSTOMER_ID    Customer number used when creating the throwaway account (default: 0000000042)
set -e

# shellcheck source=test-setup.sh
source "$(dirname "$0")/test-setup.sh"

CUSTOMER_NUMBER="${DELETE_CUSTOMER_ID:-0000000042}"
TODAY=$(date +%Y-%m-%d)

PASS=0
FAIL=0
SKIP=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL+1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP+1)); }

check_delete_account_url() {
    local api_url="$1"

    # ------------------------------------------------------------------
    # 0. Create a throwaway account so we have something to delete
    # ------------------------------------------------------------------
    echo "--- Setup     : POST ${api_url}/accounts  (create throwaway account)"

    CREATE_RESP=$(curl --silent --max-time 15 --insecure \
        --header "Content-Type: application/json" \
        --write-out "\n%{http_code}" \
        --data "{\"customerNumber\":\"${CUSTOMER_NUMBER}\",\"accountType\":\"SAVING\",\"interestRate\":0,\"overdraftLimit\":0,\"openedDate\":\"${TODAY}\"}" \
        "${api_url}/accounts")

    CREATE_STATUS=$(echo "${CREATE_RESP}" | tail -n1)
    CREATE_BODY=$(echo "${CREATE_RESP}" | sed '$d')

    echo "    HTTP status : ${CREATE_STATUS}"
    echo "    Response    :"
    echo "${CREATE_BODY}" | python3 -m json.tool 2>/dev/null || echo "${CREATE_BODY}"
    echo ""

    if [ "${CREATE_STATUS}" != "201" ]; then
        fail "Setup: POST /accounts expected HTTP 201 but got ${CREATE_STATUS} — skipping delete tests for ${api_url}"
        return
    fi

    NEW_ACCOUNT_ID=$(echo "${CREATE_BODY}" | python3 -c \
        "import sys,json; print(json.load(sys.stdin).get('accountId',''))" 2>/dev/null || true)

    if [ -z "${NEW_ACCOUNT_ID}" ]; then
        fail "Setup: accountId missing from POST /accounts response — skipping delete tests for ${api_url}"
        return
    fi

    pass "Setup: created throwaway account ${NEW_ACCOUNT_ID} (${api_url})"

    # ------------------------------------------------------------------
    # 1. Delete the just-created account → HTTP 204
    # ------------------------------------------------------------------
    echo "--- Endpoint : DELETE ${api_url}/accounts/${NEW_ACCOUNT_ID}  (expect 204)"

    DELETE_STATUS=$(curl --silent --max-time 15 --insecure \
        --request DELETE \
        --write-out "%{http_code}" \
        --output /dev/null \
        "${api_url}/accounts/${NEW_ACCOUNT_ID}")

    echo "    HTTP status : ${DELETE_STATUS}"
    echo ""

    if [ "${DELETE_STATUS}" = "204" ]; then
        pass "DELETE /accounts/${NEW_ACCOUNT_ID} returned HTTP 204 (${api_url})"
    else
        fail "DELETE /accounts/${NEW_ACCOUNT_ID} expected HTTP 204 but got ${DELETE_STATUS} (${api_url})"
    fi

    # ------------------------------------------------------------------
    # 2. Delete the same account again → HTTP 404
    # ------------------------------------------------------------------
    echo "--- Endpoint : DELETE ${api_url}/accounts/${NEW_ACCOUNT_ID}  (repeat → expect 404)"

    REPEAT_STATUS=$(curl --silent --max-time 15 --insecure \
        --request DELETE \
        --write-out "%{http_code}" \
        --output /dev/null \
        "${api_url}/accounts/${NEW_ACCOUNT_ID}")

    echo "    HTTP status : ${REPEAT_STATUS}"
    echo ""

    if [ "${REPEAT_STATUS}" = "404" ]; then
        pass "DELETE /accounts/${NEW_ACCOUNT_ID} (repeat) returned HTTP 404 (${api_url})"
    else
        fail "DELETE /accounts/${NEW_ACCOUNT_ID} (repeat) expected HTTP 404 but got ${REPEAT_STATUS} (${api_url})"
    fi

    # ------------------------------------------------------------------
    # 3. Delete a never-existing account ID → HTTP 404
    # ------------------------------------------------------------------
    echo "--- Endpoint : DELETE ${api_url}/accounts/99999999  (non-existent → expect 404)"

    NOTFOUND_STATUS=$(curl --silent --max-time 15 --insecure \
        --request DELETE \
        --write-out "%{http_code}" \
        --output /dev/null \
        "${api_url}/accounts/99999999")

    echo "    HTTP status : ${NOTFOUND_STATUS}"
    echo ""

    if [ "${NOTFOUND_STATUS}" = "404" ]; then
        pass "DELETE /accounts/99999999 returned HTTP 404 (${api_url})"
    else
        fail "DELETE /accounts/99999999 expected HTTP 404 but got ${NOTFOUND_STATUS} (${api_url})"
    fi
}

echo "=== Test: Delete Account (CICS DELACC) ==="
echo "Customer ID : ${CUSTOMER_NUMBER}"
echo ""

check_delete_account_url "${BASE_URL}"

if [[ -n "${BASE_HTTPS_URL:-}" ]]; then
    check_delete_account_url "${BASE_HTTPS_URL}"
else
    skip "HTTPS API test (ZOSCONNECT_HTTPS_PORT not configured)"
fi

echo "=== Summary: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped ==="
[ "${FAIL}" -eq 0 ] && exit 0 || exit 1
