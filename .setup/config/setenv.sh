#!/bin/env bash

set -e

# =========================
# Source library scripts
# =========================
LOCAL_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if git rev-parse --show-toplevel >/dev/null 2>&1; then
    export REPO_NAME="$(basename "$(git rev-parse --show-toplevel)")"
else
    export REPO_NAME="Bank-of-Z"
fi
export CONFIG_FILE="$LOCAL_SCRIPTS_DIR/config.yaml"
if command -v chtag >/dev/null 2>&1; then
    chtag -t -c ISO8859-1 "$CONFIG_FILE"
fi
export LIB_DIR="$LOCAL_SCRIPTS_DIR/../lib"
source "$LIB_DIR/utilities.sh"
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/prerequisites.sh"

# =========================
# Environment
# =========================
export APP_BASE_NAME=$(get_section_value 'app' 'base_name')
export APP_SHORT_NAME=$(get_section_value 'app' 'short_name')
export APP_BASE_NAME_LOWER=$(echo "$APP_BASE_NAME" | tr '[:upper:]' '[:lower:]')
export APP_ZOS_VERSION=$(get_section_value 'app' 'zos_version')
export APP_VERSION=$(get_section_value 'app' 'zos_version')
export SANDBOX_DIR=${SANDBOX_DIR:-$(get_section_value 'sandbox' 'path')}
export JAVA_HOME=${JAVA_HOME:-$(get_section_value 'java' 'java_home')}
export DBB_REPO_URL=$(get_section_value 'repositories' 'url')
export ZBUILDER_SOURCE=$(get_section_value 'zbuilder' 'source_dir')
export ZBUILDER_TARGET=$(get_section_value 'zbuilder' 'target_dir')
export _BPXK_AUTOCVT=ON
export ZOS_USER="$(printf '%s' "${USER:-${LOGNAME:-$(basename "$HOME")}}" | tr '[:lower:]' '[:upper:]')"

# =========================
# Zowe Configuration
# =========================
export ZOWE_RSE_PROFILE=$(get_section_value 'zowe' 'rse_profile')
export RSE_PROFILE_ARG="--rse-profile ${ZOWE_RSE_PROFILE}"

