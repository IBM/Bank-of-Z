#!/bin/env bash
set -eu
# =============================================================================
# Script  : task-zcodescan-static-scan.sh
# Summary : IBM ZCodeScan Static Analysis
#
# - Prepares runtime environment (encoding, Java, PATH)
# - Runs DBB in preview mode to get the list of sources to scan
# - Activates Python environment
# - Executes ZCodeScan with provided configuration and parameters
# - Always produces LOG-PATH result
# - Exposes scan result paths if available
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
export JAVA_HOME=${JAVA_HOME_REMOTE:-$(get_section_value 'zcodescan' 'java_home')}
export PYENV_ACTIVATE_PATH=${PYENV_ACTIVATE_PATH:-$(get_section_value 'zcodescan' 'zcodescan_home')/bin/activate}
export SCAN_CWD_FOLDER=${SCAN_CWD_FOLDER:-$(get_section_value 'zcodescan' 'cwd_folder')}
export SCAN_SOURCE_FOLDER=${SCAN_SOURCE_FOLDER:-$(get_section_value 'zcodescan' 'src_folder')}
export SCAN_OUTPUT_FILE=${SCAN_OUTPUT_FILE:-$(get_section_value 'zcodescan' 'output_folder')/zcs_export.yaml}
export SCAN_RULE_FILE=${SCAN_RULE_FILE:-$(get_section_value 'zcodescan' 'rule_file')}
export SCAN_ENCODING=${SCAN_ENCODING:-$(get_section_value 'zcodescan' 'src_encoding')}
export ZCS_RESAPI_URL=${ZCS_RESAPI_URL:-$(get_section_value 'zcodescan' 'rseapi_url')}
export ZCS_RESAPI_USER=${ZCS_RESAPI_USER:-$(get_section_value 'zcodescan' 'rseapi_user')}
export ZCS_RESAPI_PASSWORD=${ZCS_RESAPI_PASSWORD:-$(get_section_value 'zcodescan' 'rseapi_password')}
export ZCS_RESAPI_VERIFY=${ZCS_RESAPI_VERIFY:-$(get_section_value 'zcodescan' 'rseapi_verify')}

export PATH="${JAVA_HOME}/bin:${REMOTE_EXTRA_PATH:-}:$PATH"

# =========================
# Temporary log
# =========================
TMP_LOG="/tmp/zcodescan_$$.log"
: > "$TMP_LOG"

LOG_DIR="$SCRIPTS_DIR/logs"
LOG_TAR="$SCRIPTS_DIR/zcodescan-log.tar"

# =========================
# Finalize: always publish log tar on exit
# =========================
finalize_results() {
    RC=$?

    if [ -f "$TMP_LOG" ]; then
        cp "$TMP_LOG" "$LOG_DIR/zcodescan-console.log" 2>/dev/null || true
    fi

    if ls "$LOG_DIR"/*.log >/dev/null 2>&1; then
        tar cf "$LOG_TAR" -C "$LOG_DIR" . 2>/dev/null || true
    else
        mkdir -p "$LOG_DIR"
        echo "No ZCodeScan logs found" > "$LOG_DIR/zcodescan-console.log"
        tar cf "$LOG_TAR" -C "$LOG_DIR" . 2>/dev/null || true
    fi

    print_result "${GREEN}[ZCODESCAN][LOG-PATH]${NC} $LOG_TAR"

    rm -f "$TMP_LOG" 2>/dev/null || true

    exit "$RC"
}

trap finalize_results EXIT

# =========================
# Step 1: DBB preview (get source list)
# =========================
print_info "${CYAN}[ZCODESCAN]${NC} Running DBB in preview mode to get the list of sources to scan"

bash "$SCRIPTS_DIR/../tasks/task-dbb-build.sh" preview 2>&1 | tee "$TMP_LOG" | while read -r line
do
    case "$line" in
        ">"*)
            print_info "${CYAN}[ZCODESCAN]${NC} ${line#> }"
            ;;
        *)
            print_info "${CYAN}[ZCODESCAN]${NC} $line"
            ;;
    esac
done

if grep -q "ERROR" "$TMP_LOG"; then
    print_error "${RED}[ZCODESCAN]${NC} DBB build failed"
    exit 1
fi

if grep -q "Total files processed : 0$" "$TMP_LOG"; then
    print_info "${CYAN}[ZCODESCAN]${NC} DBB build list is empty - nothing to scan"
    exit 0
fi

BUILD_LIST=$(sed -n 's/.*\[BUILD-LIST\][[:space:]]*//p' "$TMP_LOG" | tail -1)

cd "${SCAN_CWD_FOLDER}"
source "${PYENV_ACTIVATE_PATH}"

# =========================
# Step 2: Run ZCodeScan
# =========================
: > "$TMP_LOG"

export SCAN_CONFIG_FILE="$SCRIPTS_DIR/config.yml"

cat > "${SCAN_CONFIG_FILE}" << EOF
license_server:
  url: ${ZCS_RESAPI_URL}
  user: ${ZCS_RESAPI_USER}
  password: ${ZCS_RESAPI_PASSWORD}
  verify: ${ZCS_RESAPI_VERIFY}
EOF

rm -rf "$LOG_DIR"
rm -f ./*.log
mkdir -p "$LOG_DIR"

print_info "${CYAN}[ZCODESCAN]${NC} Starting ZCodeScan analysis ..."

PYTHONUNBUFFERED=1 zcodescan \
  -sfl "$BUILD_LIST" \
  -if "${SCAN_SOURCE_FOLDER}" \
  -cf "${SCAN_CONFIG_FILE}" \
  -of "${SCAN_OUTPUT_FILE}" \
  -rf "${SCAN_RULE_FILE}" \
  -et sonarqube,junit \
  -e "${SCAN_ENCODING}" 2>&1 | tee "$TMP_LOG" | while read -r line
do
    case "$line" in
        ">"*)
            print_info "${CYAN}[ZCODESCAN]${NC} ${line#> }"
            ;;
        *)
            print_info "${CYAN}[ZCODESCAN]${NC} $line"
            ;;
    esac
done

cp zcodescan.log "$LOG_DIR"

# =========================
# Collect result files
# =========================
while IFS= read -r line; do
    case "$line" in
        *"Generate SonarQube export to "*)
            cp -f "${line##*Generate SonarQube export to }" "$LOG_DIR"
            ;;
        *"Generate JUnit export to "*)
            cp -f "${line##*Generate JUnit export to }" "$LOG_DIR"
            ;;
        *"Generate output to "*)
            cp -f "${line##*Generate output to }" "$LOG_DIR"
            ;;
    esac
done < "$TMP_LOG"

deactivate

# =========================
# Validate return code
# =========================
rc=$(sed -n 's/.*RC=\(-\?[0-9][0-9]*\).*/\1/p' "$TMP_LOG" | tail -1)

if [ -z "$rc" ]; then
    print_error "${RED}[ZCODESCAN]${NC} RC not found in log"
    exit 1
fi

if [ "$rc" -eq 255 ] || [ "$rc" -lt 0 ] 2>/dev/null; then
    print_error "${RED}[ZCODESCAN]${NC} RC=$rc (error)"
    exit 1
fi

if [ "$rc" -gt 4 ]; then
    print_error "${RED}[ZCODESCAN]${NC} RC=$rc"
    exit 1
fi

exit 0
