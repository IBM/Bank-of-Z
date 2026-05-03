#!/bin/env bash

# -----------------------------------------------------------------------------
# Summary:
# This script runs TAZ unit tests on a remote z/OS environment.
# It prepares the Java and TAZ runtime environment, moves to the working
# directory, and executes the TAZ unittest command using the parameters provided
# by the Tekton Task through environment variables.
#
# Enhanced:
# - Always produces LOG-PATH result when possible
# - Always produces TAR-PATH result when test XML files exist
# - Preserves real return code (RC)
# -----------------------------------------------------------------------------

set +e

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPTS_DIR/config.yaml"
chtag -t -c ISO8859-1 "$CONFIG_FILE"

LIB_DIR="$SCRIPTS_DIR/lib"
source "$LIB_DIR/utilities.sh"
source "$LIB_DIR/colors.sh"

# Define the Java runtime used by TAZ
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
# Logs + trap (IMPORTANT)
# =========================
TMP_LOG="/tmp/taz_unittest_$$.log"
: > "$TMP_LOG"

TAZ_RESULTS_DIR="$PWD/.taz-edt-results"
TAZ_LOG_DIR="$PWD/.taz-edt/logs"
TAZ_TAR_FILE="$TAZ_RESULTS_DIR/taz-junit-results.tar"
TAZ_LOG_TAR="$PWD/taz-unittest-log.tar"

finalize_results() {
    RC=$?

    # ----------------------------------------------------------
    # Create TAR when XML result files exist
    # ----------------------------------------------------------
    if [ -d "$TAZ_RESULTS_DIR" ]; then
        XML_FILES=$(find "$TAZ_RESULTS_DIR" -name "*.xml" 2>/dev/null)

        if [ -n "$XML_FILES" ]; then
            tar -cf "$TAZ_TAR_FILE" $XML_FILES 2>/dev/null || true

            if [ -f "$TAZ_TAR_FILE" ]; then
                print_result "${GREEN}[TAZ-UNITTEST][TAR-PATH]${NC} $TAZ_TAR_FILE"
            else
                print_result "${GREEN}[TAZ-UNITTEST][TAR-PATH]${NC} NONE"
            fi
        else
            print_result "${GREEN}[TAZ-UNITTEST][TAR-PATH]${NC} NONE"
        fi
    else
        print_result "${GREEN}[TAZ-UNITTEST][TAR-PATH]${NC} NONE"
    fi

    # ----------------------------------------------------------
    # Create LOG archive when possible
    # ----------------------------------------------------------
    if [ -d "$TAZ_LOG_DIR" ] && ls "$TAZ_LOG_DIR"/* >/dev/null 2>&1; then
        tar -cf "$TAZ_LOG_TAR" -C "$TAZ_LOG_DIR" . 2>/dev/null || true
    else
        echo "No TAZ log files found" > "$TMP_LOG"
        tar -cf "$TAZ_LOG_TAR" "$TMP_LOG" 2>/dev/null || true
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

print_info "${CYAN}[TAZ-UNITTEST]${NC} Starting unit tests ..."

# Run TAZ unit tests with:
# --procLib     : procedure library used by the tests
# --userLibrary : user load library used by the tests
# --verbose     : enable detailed output
# -k0           : keep test artifacts according to TAZ CLI behavior

# Run TAZ unit tests and capture logs
rm -rf .taz-edt*

"${TAZ_CLI}" unittest run "${TAZ_TEST_PATH}" \
  --procLib "${PROCLIB}" \
  --userLibrary "${APP_LIBRARY}" \
  -k0 2>&1 | tee "$TMP_LOG" | while IFS= read -r line
do
    print_info "${CYAN}[TAZ-UNITTEST]${NC} $line"
done

TAZ_RC=${PIPESTATUS[0]}

if [ "$TAZ_RC" -ne 0 ]; then
    print_info "${RED}[TAZ-UNITTEST][ERROR] TAZ command failed with RC=$TAZ_RC${NC}"
    exit "$TAZ_RC"
fi

# Validate test results
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
  print_info "${RED}[TAZ-UNITTEST][ERROR] Tests failed (Failures=$failures, Errors=$errors)${NC}"
  exit 1
fi

print_info "${CYAN}[TAZ-UNITTEST]${NC} Tests succeed ..."
exit 0