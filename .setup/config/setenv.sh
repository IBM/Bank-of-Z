#!/bin/env bash

set -e

# =========================
# Source library scripts
# =========================
LOCAL_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
export APP_BASE_NAME_LOWER=${APP_BASE_NAME,,}
export APP_ZOS_VERSION=$(get_section_value 'app' 'zos_version')
export APP_VERSION=$(get_section_value 'app' 'zos_version')
export SANDBOX_DIR=${SANDBOX_DIR:-$(get_section_value 'sandbox' 'path')}
export _BPXK_AUTOCVT=ON

