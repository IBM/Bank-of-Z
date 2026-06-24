#!/bin/env bash

# =========================
# Source library scripts
# =========================
set +e
# For Grub and or ZOWE CLI
source /etc/profile 2>/dev/null
source $HOME/.profile 2>/dev/null
set -e
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



check_python_deps() {
    missing=""

    python3 -c "import yaml" >/dev/null 2>&1 \
        || missing="${missing} PyYAML"

    python3 -c "from jinja2 import Template" >/dev/null 2>&1 \
        || missing="${missing} Jinja2"

    if [[ -n "$missing" ]]; then
        echo "Installing:$missing"
        pip3 install --user $missing
        echo "pip rc=$?"
    fi
}

check_python_deps

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

