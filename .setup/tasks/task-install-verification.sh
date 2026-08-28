#!/bin/env bash
set -eu
# =============================================================================
# Script  : task-install-verification.sh
# Summary : Post-install Verification Tests
#
# - Relies on environment exported by pipeline-common.sh / setup-common.sh
# - Exports IMS_DISABLED (defaults to false)
# - Makes all test scripts executable
# - Runs tests/run-all.sh and reports pass/fail
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../lib/utilities.sh"
source "$SCRIPTS_DIR/../lib/colors.sh"

exec > >(while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf "${CYAN}[VERIFY]${NC} %s\n" "${line}"
done) 2>&1

# =========================
# Environment
# =========================
export IMS_DISABLED="${IMS_DISABLED:-false}"

print_info "IMS_DISABLED : ${IMS_DISABLED}"

# =========================
# Locate test runner
# =========================
TESTS_DIR="${SCRIPTS_DIR}/../../tests"
RUN_ALL="${TESTS_DIR}/run-all.sh"

if [ ! -f "$RUN_ALL" ]; then
    print_error "Test runner not found: $RUN_ALL"
    exit 1
fi
# Disable UNBOUND check
set +u
chmod +x "${TESTS_DIR}"/test_*.sh "$RUN_ALL" 2>/dev/null || true

# =========================
# Run tests
# =========================
print_info "Running verification tests in ${TESTS_DIR} ..."

set -o pipefail
if bash "$RUN_ALL"; then
    print_success "All verification tests passed"
else
    print_error "One or more verification tests failed"
    exit 1
fi
