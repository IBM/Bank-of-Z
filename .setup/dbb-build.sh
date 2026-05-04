#!/bin/env bash
set -eu
###############################################################################
# Script: DBB Build + WAR Packaging + TAR Rebuild
#
# Description:
# - Runs DBB build pipeline
# - Streams DBB output in real time
# - Reformats DBB log lines
# - Verifies "Build Status : CLEAN"
# - Detects "Total files processed : 0"
# - Skips packaging when nothing was built
# - Selects the most recent *.tar from logs/
# - Extracts it into a working directory
# - Collects and renames api.war files
# - Injects them into package/war
# - Rebuilds TAR in packages/ with the same original name
# - Always produces DBB log tar result, even on failure
#
###############################################################################

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPTS_DIR/config.yaml"
chtag -t -c ISO8859-1 "$CONFIG_FILE"

LIB_DIR="$SCRIPTS_DIR/lib"
source "$LIB_DIR/utilities.sh"
source "$LIB_DIR/colors.sh"

# =========================
# Environment
# =========================
export DBB_HOME=$(get_section_value 'dbb' 'dbb_home')
export DBB_BUILD=$(get_section_value 'dbb' 'dbb_build')
export DBB_CWD=$(get_section_value 'dbb' 'dbb_cwd')
export DBB_APP_CONF=$(get_section_value 'dbb' 'dbb_app_conf')
export JAVA_HOME=$(get_section_value 'dbb' 'java_home')
export APP_BASE_NAME=$(get_section_value 'app' 'base_name')
export API_BASE=$(get_section_value 'dbb' 'api_base')

export PATH="$JAVA_HOME/bin:$DBB_HOME/bin:$PATH"
export GRADLE_USER_HOME="$(get_section_value 'sandbox' 'path')/.gradle"
export GRADLE_OPTS="-Dfile.encoding=UTF-8"

# =========================
# Start build
# =========================
print_info "${CYAN}[DBB-BUILD]${NC} Starting DBB build in $DBB_CWD ..."
cd "$DBB_CWD" || exit 1

TMP_LOG="/tmp/dbb_build_$$.log"
: > "$TMP_LOG"

# =========================
# Always publish log result
# =========================
finalize_results() {
    RC=$?

    cd "$DBB_CWD" || exit 1
    mkdir -p logs
    if [ -f "$TMP_LOG" ]; then
        cp "$TMP_LOG" "logs/dbb-build-console.log" 2>/dev/null || true
    fi

    LOG_TAR="$PWD/logs/dbb-build-log.tar"

    if ls logs/*.log >/dev/null 2>&1; then
        tar cf "$LOG_TAR" logs/*.log 2>/dev/null || true
    else
        echo "No DBB log files found" > logs/dbb-build-console.log
        tar cf "$LOG_TAR" logs/dbb-build-console.log 2>/dev/null || true
    fi

    print_result "${GREEN}[DBB-BUILD][LOG-PATH]${NC} $LOG_TAR"

    rm -f "$TMP_LOG" 2>/dev/null || true
    
    if [ $RC -eq 0 ]; then
        print_success "${GREEN}[DBB-BUILD]${NC} Process completed"
    fi

    exit "$RC"
}

trap finalize_results EXIT

BUILD_TYPE="${1:-}"
BUILD_OPTIONS=""

if [ "$BUILD_TYPE" = "full" ]; then
    print_info "${CYAN}[DBB-BUILD]${NC} Running FULL DBB build"
    BUILD_TYPE="full"
else
    print_info "${CYAN}[DBB-BUILD]${NC} Running PIPELINE (impact) DBB build"

    if [ "$BUILD_TYPE" = "preview" ]; then
        BUILD_OPTIONS="--preview"
    fi

    BUILD_TYPE="pipeline"
fi

rm -rf logs
mkdir -p logs

dbb build "$BUILD_TYPE" --hlq "${APP_BASE_NAME}.DBB" $BUILD_OPTIONS --config "$DBB_APP_CONF" 2>&1 | tee "$TMP_LOG" | while read -r line
do
    case "$line" in
        ">"*)
            msg=${line#> }
            print_info "${CYAN}[DBB-BUILD]${NC} $msg"
            ;;
        *)
            print_info "${CYAN}[DBB-BUILD]${NC} $line"
            ;;
    esac
done

grep -E "Build Status : CLEAN|Build Status : PREVIEW" "$TMP_LOG" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    print_error "${RED}[DBB-BUILD]${NC} DBB build status is not CLEAN"
    print_error "${RED}[DBB-BUILD]${NC} Check DBB log: $TMP_LOG"
    exit 1
fi

# =========================
# Publish DBB report results
# =========================
print_result "${GREEN}[DBB-BUILD][BUILD-RESULT]${NC} $PWD/logs/BuildReport.json"
print_result "${GREEN}[DBB-BUILD][BUILD-LIST]${NC} $PWD/logs/buildList.txt"

# =========================
# Skip packaging if nothing processed
# =========================
set +e
grep "Total files processed : 0" "$TMP_LOG" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    print_result "${GREEN}[DBB-BUILD][TAR-PATH]${NC} NONE"
    exit 0
fi
set -e


# =========================
# Variables
# =========================
PACKAGE_DIR="logs/package"
WAR_DIR="$PACKAGE_DIR/war"

SRC_TAR=$(ls -t logs/*-*.tar 2>/dev/null | head -1 || true)

if [ -z "$SRC_TAR" ]; then
    if echo "$BUILD_OPTIONS" | grep -q "preview"; then
        print_result "${GREEN}[DBB-BUILD][TAR-PATH]${NC} NONE"
        exit 0
    else
        print_error "No tar file found in logs/"
        exit 1
    fi
fi

TAR_NAME=$(basename "$SRC_TAR")
TARGET_TAR="logs/$TAR_NAME"

# =========================
# Prepare package
# =========================
rm -rf "$PACKAGE_DIR"
mkdir -p "$WAR_DIR"

# =========================
# Extract tar
# =========================
tar -xf "$SRC_TAR" -C "$PACKAGE_DIR"

# =========================
# Copy WAR files
# =========================
if [ -d "$API_BASE" ]; then
    find "$API_BASE" -name "api.war" 2>/dev/null | while read -r war_file
    do
        api_dir=$(dirname "$war_file")
        api_dir=$(dirname "$api_dir")
        api_dir=$(dirname "$api_dir")
        api_name=$(basename "$api_dir")

        if [ -z "$api_name" ]; then
            print_error "Empty API name for $war_file"
            exit 1
        fi

        target="$WAR_DIR/${api_name}.war"
        cp "$war_file" "$target"
    done
fi

# =========================
# Recreate tar
# =========================
tar -cf "$TARGET_TAR" -C "$PACKAGE_DIR" .

# =========================
# Display generated tar
# =========================
if [ -f "$TARGET_TAR" ]; then
    print_result "${GREEN}[DBB-BUILD][TAR-PATH]${NC} $PWD/$TARGET_TAR"
else
    print_error "Tar not found: $PWD/$TARGET_TAR"
    exit 1
fi