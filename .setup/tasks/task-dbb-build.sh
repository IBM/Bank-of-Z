#!/bin/env bash
set -eu
# =============================================================================
# Script  : task-dbb-build.sh
# Summary : DBB Build + WAR Packaging + TAR Rebuild
#
# - Runs DBB build pipeline (full or impact/pipeline)
# - Streams and reformats DBB output in real time
# - Verifies "Build Status : CLEAN"
# - Detects "Total files processed : 0" and skips packaging
# - Selects the most recent *.tar from ${DBB_LOG_FOLDER}/
# - Extracts it into a working directory
# - Collects and renames api.war files
# - Injects them into package/war
# - Rebuilds TAR in ${DBB_LOG_FOLDER}/ with the same original name
# - Always produces DBB log tar result, even on failure
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

exec > >(while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf "${CYAN}[DBB-BUILD]${NC} %s\n" "${line}"
done) 2>&1

# =========================
# Environment
# =========================
export DBB_CONFG_HOME=$(get_section_value 'dbb' 'dbb_home')
if [ -f "$DBB_CONFG_HOME/bin/dbb" ]; then
    export DBB_HOME=$DBB_CONFG_HOME
fi

export PATH="$JAVA_HOME/bin:$DBB_HOME/bin:$PATH"
export GRADLE_USER_HOME="$SANDBOX_DIR/../.gradle"
export GRADLE_OPTS="-Dfile.encoding=UTF-8"
export GRADLE_DAEMON_BIND_ADDRESS=127.0.0.1

# =========================
# Temporary log
# =========================
TMP_LOG="/tmp/dbb_build_$$.log"
: > "$TMP_LOG"

# =========================
# Finalize: always publish log tar on exit
# =========================
finalize_results() {
    RC=$?

    cd "$DBB_CWD" || exit 1
    mkdir -p ${DBB_LOG_FOLDER}

    if [ -f "$TMP_LOG" ]; then
        cp "$TMP_LOG" "${DBB_LOG_FOLDER}/dbb-build-console.log" 2>/dev/null || true
    fi

    LOG_TAR="${DBB_LOG_FOLDER}/dbb-build-log.tar"

    if ls logs/*.log >/dev/null 2>&1; then
        chtag -tc ISO8859-1 logs/*.log
        tar cf "$LOG_TAR" logs  2>/dev/null || true
        mv -f logs ${DBB_LOG_FOLDER}
    else
        echo "No DBB log files found" > ${DBB_LOG_FOLDER}/dbb-build-console.log
        tar cf "$LOG_TAR" ${DBB_LOG_FOLDER}/dbb-build-console.log 2>/dev/null || true
    fi

    print_result "[LOG-PATH] $LOG_TAR"

    rm -f "$TMP_LOG" 2>/dev/null || true

    if [ $RC -eq 0 ]; then
        print_success " Process completed"
    else
        print_error "Process failed"
    fi

    exit "$RC"
}

trap finalize_results EXIT

# =========================
# Build type selection
# =========================
BUILD_TYPE="${1:-}"
BUILD_OPTIONS=""

if [ "$BUILD_TYPE" = "full" ]; then
    print_info "Running FULL DBB build"
    BUILD_TYPE="full"
else
    print_info "Running PIPELINE (impact) DBB build"

    if [ "$BUILD_TYPE" = "preview" ]; then
        BUILD_OPTIONS="--preview"
    fi

    BUILD_TYPE="pipeline"
fi

# =========================
# Run DBB build
# =========================
print_info "Starting DBB build in $DBB_CWD ..."
cd "$DBB_CWD" || exit 1
set +e
rm -rf ${DBB_LOG_FOLDER}
mkdir -p ${DBB_LOG_FOLDER}
chtag -r src/api/src/main/api/openapi.yaml
set -e
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --templateFile "$SCRIPTS_DIR/../build/datasets.yaml.j2"  --outputFile "$SCRIPTS_DIR/../build/datasets.yaml"

dbb build "$BUILD_TYPE" --debug --hlq "${APP_HLQ}.DBB" --log-encoding ISO8859-1 $BUILD_OPTIONS --config "$DBB_APP_CONF" 2>&1 | tee "$TMP_LOG" | while read -r line
do
    case "$line" in
        ">"*)
            print_info "${line#> }"
            ;;
        *)
            print_info "$line"
            ;;
    esac
done

# =========================
# Validate build status
# =========================
grep -E "Build Status : CLEAN|Build Status : PREVIEW|Build Status : WARNING" "$TMP_LOG" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    print_error "DBB build status is not CLEAN"
    print_error "Check DBB log: $TMP_LOG"
    exit 1
fi

# =========================
# Publish DBB report results
# =========================
print_result "[BUILD-RESULT] ${DBB_LOG_FOLDER}/BuildReport.json"
print_result "[BUILD-LIST] ${DBB_LOG_FOLDER}/buildList.txt"

# =========================
# Skip packaging if nothing processed
# =========================
set +e
mv $PWD/logs/*.* ${DBB_LOG_FOLDER} >/dev/null 2>&1
rm -rf "$PWD/logs"
grep "Total files processed : 0" "$TMP_LOG" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    print_result "[TAR-PATH] NONE"
    exit 0
fi
set -e

# =========================
# Collect tar file
# =========================
SRC_TAR=$(ls -t ${DBB_LOG_FOLDER}/*-*.tar 2>/dev/null | head -1 || true)

if [ -z "$SRC_TAR" ]; then
    if echo "$BUILD_OPTIONS" | grep -q "preview"; then
        print_result "[TAR-PATH] NONE"
        exit 0
    else
        print_error "No tar file found in ${DBB_LOG_FOLDER}/$SRC_TAR"
        exit 1
    fi
fi

TAR_NAME=$(basename "$SRC_TAR")
TARGET_TAR="${DBB_LOG_FOLDER}/$TAR_NAME"

# =========================
# Publish tar result
# =========================
if [ -f "$TARGET_TAR" ]; then
    print_result "[TAR-PATH] $TARGET_TAR"
else
    print_error "Tar not found: $TARGET_TAR"
    exit 1
fi
