#!/bin/env bash

# =========================
# Source library scripts
# =========================
LOCAL_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CONFIG_FILE="${CONFIG_FILE:-$LOCAL_SCRIPTS_DIR/config.yaml}"
ENV_FILE="${LOCAL_SCRIPTS_DIR}/.env"
export LIB_DIR="$LOCAL_SCRIPTS_DIR/../lib"
source "$LIB_DIR/utilities.sh"
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/prerequisites.sh"


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


if [[ ! -f "$ENV_FILE" || "$ENV_FILE" -ot "$CONFIG_FILE" || "$ENV_FILE" -ot "${BASH_SOURCE[0]}" ]]; then
    print_warning "Creating $ENV_FILE file ..."
    print_warning " - Not already exists or not in sync with:"
    print_warning "   - '$CONFIG_FILE'"
    print_warning "   - '${BASH_SOURCE[0]}'"
    cat > "$ENV_FILE" <<EOF
# =========================
# Environment
# =========================

# Global
_BPXK_AUTOCVT=ON
PYTHONUNBUFFERED=1
ZOS_CURRENT_USER=$(printf '%s' "${USER:-${LOGNAME:-$(basename "$HOME")}}" | tr '[:lower:]' '[:upper:]')
ZOS_ADMIN_USER=$(get_section_value 'global' 'zos_admin_user')

 # Application
APP_BASE_NAME=$(get_section_value 'app' 'base_name')
APP_SHORT_NAME=$(get_section_value 'app' 'short_name')
APP_BASE_NAME_LOWER=$(echo "$(get_section_value 'app' 'base_name')" | tr '[:upper:]' '[:lower:]')
APP_ZOS_VERSION=$(get_section_value 'app' 'zos_version')
APP_FULL_VERSION=$(get_section_value 'app' 'full_version')
APP_DESCRIPTION="$(get_section_value 'app' 'description')"
APP_HLQ="$(get_section_value 'app' 'app_hlq')"

# Sandbox
SANDBOX_DIR=${SANDBOX_DIR:-$(get_section_value 'sandbox' 'path')}

# Java
JAVA_HOME=$(get_section_value 'java' 'java_home')

# Python
PYTHON_HOME=$(get_section_value 'python' 'python_home')

# Repositories
DBB_REPO_URL=$(get_section_value 'repositories' 'dbb_url')

# ZOAU
ZOAU_HOME="${ZOAU_HOME:-$(get_section_value 'zoau' 'zoau_home')}"

# ZBuuilder
ZBUILDER_SOURCE=$(get_section_value 'zbuilder' 'source_dir')
ZBUILDER_TARGET=$(get_section_value 'zbuilder' 'target_dir')

# DBB
DBB_HOME=$(get_section_value 'dbb' 'dbb_home')
DBB_BUILD=$(get_section_value 'dbb' 'dbb_build')
DBB_CWD=$(get_section_value 'dbb' 'dbb_cwd')
DBB_APP_CONF=$(get_section_value 'dbb' 'dbb_app_conf')
DBB_LOG_FOLDER=$(get_section_value 'dbb' 'dbb_log_dir')
DBB_BUILD_PATH=$(get_section_value 'dbb' 'dbb_build')
DBB_LOG_FOLDER="${DBB_LOG_FOLDER:-$(get_section_value 'dbb' 'dbb_log_dir')}"

# Wazi Deploy
DEPLOY_WAZIDEPLOY_HOME="${DEPLOY_WAZIDEPLOY_HOME:-$(get_section_value 'wazideploy' 'wazideploy_home')}"
DEPLOY_PYENV_ACTIVATE_PATH="${DEPLOY_PYENV_ACTIVATE_PATH:-$(get_section_value 'wazideploy' 'wazideploy_home')/bin/activate}"
DEPLOY_DEPLOYMENT_METHOD="${DEPLOY_DEPLOYMENT_METHOD:-$(get_section_value 'wazideploy' 'deployment_method')}"
DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-$(get_section_value 'wazideploy' 'deployment_envfile')}"
DEPLOY_ZDEPLOY_FOLDER="${DEPLOY_ZDEPLOY_FOLDER:-$(get_section_value 'wazideploy' 'zdeploy_dir')}"
DEPLOY_LOG_FOLDER="${DEPLOY_LOG_FOLDER:-$(get_section_value 'wazideploy' 'deploy_log_dir')}"
DEPLOY_TYPES_MAPPING_FILES="${DEPLOY_TYPES_MAPPING_FILES:-$(get_section_value 'wazideploy' 'types_pattern_mapping')}"

# ZCodeScan
SCAN_PYENV_ACTIVATE_PATH=${PYENV_ACTIVATE_PATH:-$(get_section_value 'zcodescan' 'zcodescan_home')/bin/activate}
SCAN_CWD_FOLDER=${SCAN_CWD_FOLDER:-$(get_section_value 'zcodescan' 'cwd_dir')}
SCAN_SOURCE_FOLDER=${SCAN_SOURCE_FOLDER:-$(get_section_value 'zcodescan' 'src_dir')}
SCAN_OUTPUT_FOLDER=${SCAN_OUTPUT_FOLDER:-$(get_section_value 'zcodescan' 'output_dir')}
SCAN_RULE_FILE=${SCAN_RULE_FILE:-$(get_section_value 'zcodescan' 'rule_file')}
SCAN_ENCODING=${SCAN_ENCODING:-$(get_section_value 'zcodescan' 'src_encoding')}
SCAN_CONFIG_FILE=${SCAN_CONFIG_FILE:-$(get_section_value 'zcodescan' 'config_file')}
SCAN_MAX_RC=${SCAN_MAX_RC:-$(get_section_value 'zcodescan' 'max_rc')}

# z/OS Connect
ZOSCONNECT_HOME=$(get_section_value 'zosconnect' 'zosconnect_home')
ZOSCONNECT_HTTP_PORT=$(get_section_value 'zosconnect' 'http_port')
ZOSCONNECT_HTTPS_PORT=$(get_section_value 'zosconnect' 'https_port')
ZOSCONNECT_SERVER_FOLDER="${ZOSCONNECT_SERVER_FOLDER:-$(get_section_value 'zosconnect' 'server_dir')/servers/$(echo "$(get_section_value 'app' 'base_name')" | tr '[:upper:]' '[:lower:]')Server}"
ZOSCONNECT_SYS_PROCLIB=$(get_section_value 'zosconnect' 'sys_proclib')
ZOSCONNECT_TASK_USER=$(get_section_value 'zosconnect' 'task_user')

# Fronted
FRONTEND_LIBERTY_HOME=$(get_section_value 'frontend' 'liberty_home')
FRONTEND_HTTP_PORT=$(get_section_value 'frontend' 'http_port')
FRONTEND_HTTPS_PORT=$(get_section_value 'frontend' 'https_port')
FRONTEND_SYS_PROCLIB=$(get_section_value 'frontend' 'sys_proclib')
FRONTEND_TASK_USER=$(get_section_value 'frontend' 'task_user')

# CICS
CICS_USER=${CICS_USER:-$(get_section_value 'cics' 'user')}
CICS_PASSWORD=${CICS_PASSWORD:-$(get_section_value 'cics' 'password')} #pragma: allowlist secret
CICS_IPIC_PORT=$(get_section_value 'cics' 'ipic_port')
CICS_CMCI_PORT=${CICS_CMCI_PORT:-$(get_section_value 'cics' 'cmci_port')}
CICS_DEBUG_PORT=${CICS_DEBUG_PORT:-$(get_section_value 'cics' 'debug_port')}
CICS_HLQ=${CICS_HLQ:-$(get_section_value 'cics' 'cics_hlq')}
CICS_USS_DIR=${CICS_USS_DIR:-$(get_section_value 'cics' 'uss_dir')}
CICS_SEC=${CICS_SEC:-$(get_section_value 'cics' 'cics_sec')}
CICS_SYS_PROCLIB=$(get_section_value 'cics' 'sys_proclib')

# IMS
IMS_DISABLED=${IMS_DISABLED:-$(get_section_value 'ims' 'disabled')}
IMS_APP_HLQ=${IMS_APP_HLQ:-$(get_section_value 'ims' 'ims_hlq')}
IMS_SYS_HLQ=${IMS_SYS_HLQ:-$(get_section_value 'ims' 'ims_sys_hlq')}
IMS_HOST=${IMS_HOST:-$(get_section_value 'ims' 'host')}
IMS_PORT=${IMS_PORT:-$(get_section_value 'ims' 'port')}
IMS_USER=${IMS_USER:-$(get_section_value 'ims' 'user')}
IMS_PASSWORD=${IMS_PASSWORD:-$(get_section_value 'ims' 'password')} #pragma: allowlist secret
IMS_DATASTORE=${IMS_DATASTORE:-$(get_section_value 'ims' 'datastore')}
IMS_PLEX=${IMS_PLEX:-$(get_section_value 'ims' 'dfs_imsplex')}
IMS_JAVA_CONF_PATH=${IMS_JAVA_CONF_PATH:-$(get_section_value 'ims' 'java_conf_path')}
IMS_DFS_IMS_SSID=${IMS_DFS_IMS_SSID:-$(get_section_value 'ims' 'dfs_ims_ssid')}
IMS_JAVA_HOME="${IMS_JAVA_HOME:-$(get_section_value 'ims' 'ims_java_home')}"

# zconfig
ZCONFIG_ZCB_HOME=$(get_section_value 'zconfig' 'zcb_home')
ZCONFIG_HOME="${ZCONFIG_HOME:-$(get_section_value 'zconfig' 'zconfig_home')}"

# Debug
DEBUG_HLQ=$(get_section_value 'debug' 'debug_hlq')
DEBUG_TCPIP_HQL=$(get_section_value 'debug' 'tcpip_hlq')

# Db2
DB2_HLQ="${DB2_HLQ:-$(get_section_value 'db2' 'db2_hlq')}"
DB2_SSID="${DB2_SSID:-$(get_section_value 'db2' 'ssid')}"
DB2_JAVA_HOME="${DB2_JAVA_HOME:-$(get_section_value 'db2' 'db2_java_home')}"

# Zowe Configuration
ZOWE_RSE_PROFILE=$(get_section_value 'zowe' 'rse_profile')
RSE_PROFILE_ARG="--rse-profile $(get_section_value 'zowe' 'rse_profile')"
EOF
fi

set -a
chmod 777 "$ENV_FILE" 2>/dev/null || true
source "$ENV_FILE"
set +a
export PATH=${PYTHON_HOME:-}/bin:$JAVA_HOME:/bin:$PATH
