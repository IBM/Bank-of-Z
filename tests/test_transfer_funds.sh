#!/usr/bin/env bash
# Test Case: Transfer Funds (CICS XFRFUN)
# Endpoint    : POST /accounts/{accountId}/transfer
# Expectation :
#   1. Valid transfer returns HTTP 201 with four post-transfer balance fields.
#   2. Transfer with a zero/negative amount returns HTTP 400.
#   3. Transfer referencing a non-existent source account returns HTTP 404.
#
# The test uses two well-known sample accounts; both must exist and the source
# account must have sufficient funds for the small transfer amount.
#
# Environment variables:
#   BASE_URL            Base URL of the z/OS Connect API server (default: http://localhost:9080/api)
#   BASE_HTTPS_URL      HTTPS base URL (skipped when not set)
#   FROM_ACCOUNT_ID     Source account ID (default: 00000001)
#   TO_ACCOUNT_ID       Destination account ID (default: 00000002)
#   TRANSFER_SORT_CODE  6-digit sort code for both accounts (default: 987654)
set -e

# shellcheck source=test-setup.sh
source "$(dirname "$0")/test-setup.sh"

FROM_ACCOUNT_ID="${FROM_ACCOUNT_ID:-00000001}"
TO_ACCOUNT_ID="${TO_ACCOUNT_ID:-00000002}"
SORT_CODE="${TRANSFER_SORT_CODE:-987654}"
TRANSFER_AMOUNT="1.00"

PASS=0
FAIL=0
SKIP=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL+1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP+1)); }

check_transfer_url() {
    local api_url="$1"

    # ------------------------------------------------------------------
    # 1. Valid transfer → HTTP 201 with all four balance fields
    # ------------------------------------------------------------------
    echo "--- Endpoint : POST ${api_url}/accounts/${FROM_ACCOUNT_ID}/transfer  (valid)"

    XFER_RESP=$(curl --silent --max-time 15 --insecure \
        --header "Content-Type: application/json" \
        --write-out "\n%{http_code}" \
        --data "{\"toAccountId\":\"${TO_ACCOUNT_ID}\",\"amount\":${TRANSFER_AMOUNT},\"fromSortCode\":\"${SORT_CODE}\",\"toSortCode\":\"${SORT_CODE}\"}" \
        "${api_url}/accounts/${FROM_ACCOUNT_ID}/transfer")

    HTTP_STATUS=$(echo "${XFER_RESP}" | tail -n1)
    BODY=$(echo "${XFER_RESP}" | sed '$d')

    echo "    HTTP status : ${HTTP_STATUS}"
    echo "    Response    :"
    echo "${BODY}" | python3 -m json.tool 2>/dev/null || echo "${BODY}"
    echo ""

    if [ "${HTTP_STATUS}" = "201" ]; then
        pass "POST /accounts/${FROM_ACCOUNT_ID}/transfer returned HTTP 201 (${api_url})"
    else
        fail "POST /accounts/${FROM_ACCOUNT_ID}/transfer expected HTTP 201 but got ${HTTP_STATUS} (${api_url})"
    fi

    for field in fromAccountAvailableBalance fromAccountActualBalance toAccountAvailableBalance toAccountActualBalance; do
        VALUE=$(echo "${BODY}" | python3 -c \
            "import sys,json; d=json.load(sys.stdin); print(d.get('${field}',''))" 2>/dev/null || true)
        [ -n "${VALUE}" ] \
            && pass "Response contains ${field}=\"${VALUE}\" (${api_url})" \
            || fail "Response is missing ${field} field (${api_url})"
    done

    # ------------------------------------------------------------------
    # 2. Zero amount → HTTP 400
    # ------------------------------------------------------------------
    echo "--- Endpoint : POST ${api_url}/accounts/${FROM_ACCOUNT_ID}/transfer  (amount=0 → expect 400)"

    ZERO_RESP=$(curl --silent --max-time 15 --insecure \
        --header "Content-Type: application/json" \
        --write-out "\n%{http_code}" \
        --data "{\"toAccountId\":\"${TO_ACCOUNT_ID}\",\"amount\":0}" \
        "${api_url}/accounts/${FROM_ACCOUNT_ID}/transfer")

    ZERO_STATUS=$(echo "${ZERO_RESP}" | tail -n1)
    echo "    HTTP status : ${ZERO_STATUS}"
    echo ""

    if [ "${ZERO_STATUS}" = "400" ]; then
        pass "POST transfer with amount=0 returned HTTP 400 (${api_url})"
    else
        fail "POST transfer with amount=0 expected HTTP 400 but got ${ZERO_STATUS} (${api_url})"
    fi

    # ------------------------------------------------------------------
    # 3. Non-existent source account → HTTP 404
    # ------------------------------------------------------------------
    echo "--- Endpoint : POST ${api_url}/accounts/99999999/transfer  (non-existent → expect 404)"

    NOTFOUND_RESP=$(curl --silent --max-time 15 --insecure \
        --header "Content-Type: application/json" \
        --write-out "\n%{http_code}" \
        --data "{\"toAccountId\":\"${TO_ACCOUNT_ID}\",\"amount\":1.00}" \
        "${api_url}/accounts/99999999/transfer")

    NOTFOUND_STATUS=$(echo "${NOTFOUND_RESP}" | tail -n1)
    echo "    HTTP status : ${NOTFOUND_STATUS}"
    echo ""

    if [ "${NOTFOUND_STATUS}" = "404" ]; then
        pass "POST /accounts/99999999/transfer returned HTTP 404 (${api_url})"
    else
        fail "POST /accounts/99999999/transfer expected HTTP 404 but got ${NOTFOUND_STATUS} (${api_url})"
    fi
}

echo "=== Test: Transfer Funds (CICS XFRFUN) ==="
echo "From account : ${FROM_ACCOUNT_ID}"
echo "To account   : ${TO_ACCOUNT_ID}"
echo "Sort code    : ${SORT_CODE}"
echo ""

check_transfer_url "${BASE_URL}"

if [[ -n "${BASE_HTTPS_URL:-}" ]]; then
    check_transfer_url "${BASE_HTTPS_URL}"
else
    skip "HTTPS API test (ZOSCONNECT_HTTPS_PORT not configured)"
fi

echo "=== Summary: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped ==="
[ "${FAIL}" -eq 0 ] && exit 0 || exit 1
