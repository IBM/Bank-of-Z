#!/bin/env bash

# =========================
# Source library scripts
# =========================
LOCAL_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CONFIG_FILE="$LOCAL_SCRIPTS_DIR/config.yaml"
set +e
# Load CICS/IMS credentials
if [[ -f $HOME/.profile.bankz ]]; then
    source $HOME/.profile.bankz 2>/dev/null
else
    source $HOME/.profile 2>/dev/null
fi
if git rev-parse --show-toplevel >/dev/null 2>&1; then
    repo_name=$(basename "$(git rev-parse --show-toplevel)")
    if [[ "$repo_name" =~ ^Bank-of-Z ]]; then
        export REPO_NAME=${repo_name}
    else
        export REPO_NAME="Bank-of-Z"
    fi
else
    export REPO_NAME="Bank-of-Z"
fi
if command -v chtag >/dev/null 2>&1; then
    chtag -t -c ISO8859-1 "$CONFIG_FILE"
fi
set -e

export LIB_DIR="$LOCAL_SCRIPTS_DIR/../lib"
source "$LIB_DIR/utilities.sh"
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/prerequisites.sh"

ENV_FILE="${LOCAL_SCRIPTS_DIR}/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    cat > "$ENV_FILE" <<EOF
# =========================
# Environment
# =========================
APP_BASE_NAME=$(get_section_value 'app' 'base_name')
APP_SHORT_NAME=$(get_section_value 'app' 'short_name')
APP_BASE_NAME_LOWER=$(echo "$(get_section_value 'app' 'base_name')" | tr '[:upper:]' '[:lower:]')
APP_ZOS_VERSION=$(get_section_value 'app' 'zos_version')
APP_VERSION=$(get_section_value 'app' 'zos_version')
SANDBOX_DIR=${SANDBOX_DIR:-$(get_section_value 'sandbox' 'path')}
JAVA_HOME=$(get_section_value 'java' 'java_home')
PYTHON_HOME=$(get_section_value 'python' 'python_home')
DBB_REPO_URL=$(get_section_value 'repositories' 'dbb_url')
ZBUILDER_SOURCE=$(get_section_value 'zbuilder' 'source_dir')
ZBUILDER_TARGET=$(get_section_value 'zbuilder' 'target_dir')
_BPXK_AUTOCVT=ON
ZOS_USER=$(printf '%s' "${USER:-${LOGNAME:-$(basename "$HOME")}}" | tr '[:lower:]' '[:upper:]')

# =========================
# Zowe Configuration
# =========================
ZOWE_RSE_PROFILE=$(get_section_value 'zowe' 'rse_profile')
bashRSE_PROFILE_ARG="--rse-profile $(get_section_value 'zowe' 'rse_profile')"
EOF
fi

set -a
source "$ENV_FILE"
set +a
export PATH=${PYTHON_HOME:-}/bin:$JAVA_HOME:/bin:$PATH
