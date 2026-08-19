#!/usr/bin/env bash
# run-all.sh — Run every test_*.sh in the tests/ directory and report results.
#
# Environment variables forwarded to each test script:
#   BASE_URL           z/OS Connect API base URL  (e.g. http://<host>:<port>/api)
#   FRONTEND_URL       Frontend Liberty base URL  (e.g. http://<host>:<port>)
#   BASE_HTTPS_URL     z/OS Connect HTTPS URL (e.g. https://<host>:<port>/api; optional)
#   FRONTEND_HTTPS_URL Frontend Liberty HTTPS URL (e.g. https://<host>:<port>; optional)
#   IMS_DISABLED       Set to "true" to skip IMS tests
#
# Exit code: 0 if all tests pass, 1 if any test fails.
set -eu

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PASSED=0
FAILED=0
SKIPPED=0
FAILED_TESTS=()

run_test() {
    local script="$1"
    local name
    name="$(basename "$script")"

    # Skip IMS test when IMS is disabled
    if [[ "${IMS_DISABLED:-false}" == "true" && "$name" == *"_ims"* ]]; then
        echo "--- SKIP: $name (IMS_DISABLED=true)"
        SKIPPED=$(( SKIPPED + 1 ))
        return
    fi

    echo ""
    echo "================================================================"
    if bash "$script"; then
        echo "--- PASS: $name"
        PASSED=$(( PASSED + 1 ))
    else
        echo "--- FAIL: $name" >&2
        FAILED=$(( FAILED + 1 ))
        FAILED_TESTS+=("$name")
    fi
}

echo "================================================================"
echo " Bank of Z — Installation Verification Tests"
echo "================================================================"
echo " BASE_URL           : ${BASE_URL:-<not set, using script defaults>}"
echo " FRONTEND_URL       : ${FRONTEND_URL:-<not set, using script defaults>}"
echo " BASE_HTTPS_URL     : ${BASE_HTTPS_URL:-<not set, HTTPS tests will be skipped>}"
echo " FRONTEND_HTTPS_URL : ${FRONTEND_HTTPS_URL:-<not set, HTTPS tests will be skipped>}"
echo " IMS_DISABLED       : ${IMS_DISABLED:-false}"
echo "================================================================"

for script in "$TESTS_DIR"/test_*.sh; do
    [ -f "$script" ] || continue
    run_test "$script"
done

echo ""
echo "================================================================"
echo " Results: ${PASSED} passed  |  ${FAILED} failed  |  ${SKIPPED} skipped"
echo "================================================================"

if [ "${FAILED}" -gt 0 ]; then
    echo "FAILED tests:"
    for t in "${FAILED_TESTS[@]}"; do
        echo "  - $t"
    done
    exit 1
fi

exit 0
