#!/bin/env bash
set -eu
# -----------------------------------------------------------------------------
# Summary:
# This script runs an IBM ZCodeScan static analysis on a remote z/OS environment.
# It prepares the runtime environment (encoding, Java, PATH), navigates to the
# target working directory, activates the required Python environment, and
# executes the scan with the provided configuration and parameters.
#
# Enhanced:
# - Always produces LOG-PATH result
# - Always exposes scan result paths if available
# - Preserves real return code (RC)
# -----------------------------------------------------------------------------

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPTS_DIR/config.yaml"
chtag -t -c ISO8859-1 "$CONFIG_FILE"

LIB_DIR="$SCRIPTS_DIR/lib"
source "$LIB_DIR/utilities.sh"
source "$LIB_DIR/colors.sh"

# Enable automatic character encoding conversion (important on z/OS)
export _BPXK_AUTOCVT=ON

# =========================
# Logs + trap (IMPORTANT)
# =========================
TMP_LOG="/tmp/zcodescan_$$.log"
: > "$TMP_LOG"

LOG_DIR="$SCRIPTS_DIR/logs"
LOG_TAR="$SCRIPTS_DIR/zcodescan-log.tar"

finalize_results() {
    RC=$?

    if [ -f "$TMP_LOG" ]; then
        cp "$TMP_LOG" "$LOG_DIR/zcodescan-console.log" 2>/dev/null || true
    fi

    if ls "$LOG_DIR"/*.log >/dev/null 2>&1; then
        tar cf "$LOG_TAR" -C "$LOG_DIR" . 2>/dev/null || true
    else
        echo "No ZCodeScan logs found" > "$LOG_DIR/zcodescan-console.log"
        tar cf "$LOG_TAR" -C "$LOG_DIR" . 2>/dev/null || true
    fi

    print_result "${GREEN}[ZCODESCAN][LOG-PATH]${NC} $LOG_TAR"

    rm -f "$TMP_LOG" 2>/dev/null || true

    exit "$RC"
}

trap finalize_results EXIT

# =========================
# Step 1: DBB preview
# =========================
print_info "Run DBB in preview mode to have the list of sources to scan"
bash $SCRIPTS_DIR/dbb-build.sh preview 2>&1 | tee "$TMP_LOG" | while read line
do
    case "$line" in
        ">"*)
            msg=${line#> }
            print_info "${CYAN}[ZCODESCAN]${NC} $msg"
            ;;
        *)
            print_info "${CYAN}[ZCODESCAN]${NC} $line"
            ;;
    esac
done

if grep -q "ERROR" "$TMP_LOG"; then
    print_error "DBB Build failed"
    exit 1
fi

if grep -q "Total files processed : 0$" "$TMP_LOG"; then
    print_info "The DBB Build list is empty or not found"
    exit 0
fi

BUILD_LIST=$(sed -n 's/.*\[BUILD-LIST\][[:space:]]*//p' "$TMP_LOG" | tail -1)

# =========================
# Environment
# =========================
export JAVA_HOME=${JAVA_HOME_REMOTE:-$(get_section_value 'zcodescan' 'java_home')}
export PATH="${JAVA_HOME}/bin:${REMOTE_EXTRA_PATH:-}:$PATH"
export PYENV_ACTIVATE_PATH=${PYENV_ACTIVATE_PATH:-$(get_section_value 'zcodescan' 'zcodescan_home')/bin/activate}
export SCAN_CWD_FOLDER=${SCAN_CWD_FOLDER:-$(get_section_value 'zcodescan' 'cwd_folder')}
export SCAN_SOURCE_FOLDER=${SCAN_SOURCE_FOLDER:-$(get_section_value 'zcodescan' 'src_folder')}
export SCAN_OUTPUT_FILE=${SCAN_OUTPUT_FILE:-$(get_section_value 'zcodescan' 'output_folder')/zcs_export.json}
export SCAN_ENCODING=${SCAN_ENCODING:-$(get_section_value 'zcodescan' 'src_encoding')}

cd "${SCAN_CWD_FOLDER}"
source "${PYENV_ACTIVATE_PATH}"

# =========================
# Step 2: ZCodeScan
# =========================
: > "$TMP_LOG"

export SCAN_CONFIG_FILE="$SCRIPTS_DIR/config.yml"
echo "license_server:" > ${SCAN_CONFIG_FILE}
echo "  url: https://127.0.0.1:8195" >> ${SCAN_CONFIG_FILE}
echo "  user: IBMUSER" >> ${SCAN_CONFIG_FILE}
echo "  password: SYS1SYS1" >> ${SCAN_CONFIG_FILE}
echo "  verify: false" >> ${SCAN_CONFIG_FILE}

export ZCS_AUTO_GEN_KEY=True
export ZCS_GEN_KEY=True

rm -rf "$LOG_DIR"
rm -f "*.log"
mkdir -p "$LOG_DIR"

PYTHONUNBUFFERED=1 zcodescan \
  -sfl "$BUILD_LIST" \
  -if "${SCAN_SOURCE_FOLDER}" \
  -cf "${SCAN_CONFIG_FILE}" \
  -of "${SCAN_OUTPUT_FILE}" \
  -et sonarqube,junit \
  -e "${SCAN_ENCODING}" 2>&1 | tee "$TMP_LOG" | while read line
do
    case "$line" in
        ">"*)
            msg=${line#> }
            print_info "${CYAN}[ZCODESCAN]${NC} $msg"
            ;;
        *)
            print_info "${CYAN}[ZCODESCAN]${NC} $line"
            ;;
    esac
done
cp zcodescan.log "$LOG_DIR"

# =========================
# Extract result paths
# =========================
while IFS= read -r line; do
    case "$line" in
        *"Generate SonarQube export to "*)
            path=$(echo "$line" | sed 's/.*Generate SonarQube export to //')
            cp -f "$path" "$LOG_DIR"
            ;;
        *"Generate JUnit export to "*)
            path=$(echo "$line" | sed 's/.*Generate JUnit export to //')
            cp -f "$path" "$LOG_DIR"
            ;;
        *"Generate output to "*)
            path=$(echo "$line" | sed 's/.*Generate output to //')
            cp -f "$path" "$LOG_DIR"
            ;;
    esac
done < "$TMP_LOG"

# =========================
# RC handling
# =========================
rc=$(sed -n 's/.*RC=\([0-9][0-9]*\).*/\1/p' "$TMP_LOG" | tail -1)

deactivate

if [ -n "$rc" ] && [ "$rc" -ne 0 ]; then
    print_warning "[ZCODESCAN] RC=$rc"
    exit "$rc"
fi

exit 0