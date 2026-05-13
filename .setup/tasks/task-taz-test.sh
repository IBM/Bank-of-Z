#!/bin/env bash
set -eu
# =============================================================================
# Script  : task-taz-test.sh
# Summary : TAZ Unit Tests Runner
#
# - Prepares Java and TAZ runtime environment
# - Moves to the working directory
# - Executes TAZ unittest command
# - Always produces LOG-PATH result when possible
# - Preserves real return code (RC)
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

# =========================
# Environment
# =========================
export JAVA_HOME=$(get_section_value 'zcodescan' 'java_home')
export REMOTE_EXTRA_PATH=${REMOTE_EXTRA_PATH:-"/usr/lpp/IBM/foz/v1r1/bin"}
export TAZ_INSTALL_DIR=${TAZ_INSTALL_DIR:-$(get_section_value 'taz' 'taz_home')}
export TAZ_TEST_PATH=${TAZ_TEST_PATH:-$(get_section_value 'taz' 'test_folder')}
export PROCLIB=${PROCLIB:-$(get_section_value 'taz' 'proclib')}
export APP_LIBRARY=${APP_LIBRARY:-$(get_section_value 'taz' 'library')}
export ENGINE_DSN=${ENGINE_DSN:-$(get_section_value 'taz' 'steplib')}

export PATH="${JAVA_HOME}/bin:${REMOTE_EXTRA_PATH}:$PATH"
export STEPLIB="${ENGINE_DSN}"
export TAZ_CLI="${TAZ_INSTALL_DIR}/bin/taz"

# =========================
# Temporary log
# =========================
TMP_LOG="/tmp/taz_unittest_$$.log"
: > "$TMP_LOG"

TAZ_RESULTS_DIR="$SCRIPTS_DIR/.taz-edt-results"
TAZ_LOG_DIR="$SCRIPTS_DIR/.taz-edt/logs"
TAZ_LOG_TAR="$SCRIPTS_DIR/taz-unittest-log.tar"

# =========================
# Finalize: always publish log tar on exit
# =========================
finalize_results() {
    RC=$?

    if [ -d "$TAZ_LOG_DIR" ] && ls "$TAZ_LOG_DIR"/* >/dev/null 2>&1; then
        if [ -d "$TAZ_RESULTS_DIR" ]; then
            set +e
            for file in $(find "$TAZ_RESULTS_DIR" -name "*.xml")
            do
                cp -f "$file" "$TAZ_LOG_DIR"
            done
            set -e
        fi
        tar -cf "$TAZ_LOG_TAR" -C "$TAZ_LOG_DIR" . 2>/dev/null || true
    else
        print_warning "No TAZ log files found"
    fi

    if [ -f "$TAZ_LOG_TAR" ]; then
        print_result "${GREEN}[TAZ-UNITTEST][LOG-PATH]${NC} $TAZ_LOG_TAR"
    else
        print_result "${GREEN}[TAZ-UNITTEST][LOG-PATH]${NC} NONE"
    fi

    rm -f "$TMP_LOG" 2>/dev/null || true

    exit "$RC"
}

trap finalize_results EXIT

# =========================
# Run TAZ unit tests
# =========================
cd "$SCRIPTS_DIR"
rm -rf .taz-edt*

print_info "${CYAN}[TAZ-UNITTEST]${NC} Starting unit tests in $PWD ..."

"${TAZ_CLI}" unittest run "${TAZ_TEST_PATH}" \
  --procLib "${PROCLIB}" \
  --userLibrary "${APP_LIBRARY}" \
  -k0 2>&1 | tee "$TMP_LOG" | while IFS= read -r line
do
    print_info "${CYAN}[TAZ-UNITTEST]${NC} $line"
done

TAZ_RC=${PIPESTATUS[0]}

if [ "$TAZ_RC" -ne 0 ]; then
    print_error "${RED}[TAZ-UNITTEST]${NC} TAZ command failed with RC=$TAZ_RC"
    exit "$TAZ_RC"
fi

# =========================
# Validate test results
# =========================
failures=0
errors=0

while IFS= read -r line; do
    case "$line" in
        *"Tests run:"*"Failures:"*"Errors:"*)
            tmp="${line##*Failures: }"
            failures="${tmp%%,*}"

            tmp="${line##*Errors: }"
            errors="${tmp%%[^0-9]*}"
            ;;
    esac
done < "$TMP_LOG"

if [[ "$failures" -ne 0 || "$errors" -ne 0 ]]; then
    print_error "${RED}[TAZ-UNITTEST]${NC} Tests failed (Failures=$failures, Errors=$errors)"
    exit 1
fi

print_info "${CYAN}[TAZ-UNITTEST]${NC} Tests succeeded"

exit 0
