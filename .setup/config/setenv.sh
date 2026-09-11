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
export USER=$(printf '%s' "${USER:-${LOGNAME:-$(basename "$HOME")}}" | tr '[:lower:]' '[:upper:]')
set +e
# Load CICS/IMS credentials
if [[ -f $HOME/.profile.bankz ]]; then
    source $HOME/.profile.bankz 2>/dev/null
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


TEMPLATE_FILE="${LOCAL_SCRIPTS_DIR}/.env.template"

if [[ ! -f "$ENV_FILE" || "$ENV_FILE" -ot "$CONFIG_FILE" || "$ENV_FILE" -ot "${BASH_SOURCE[0]}" ]]; then
    print_warning "Creating $ENV_FILE file ..."
    print_warning " - Not already exists or not in sync with:"
    print_warning "   - '$CONFIG_FILE'"
    print_warning "   - '${BASH_SOURCE[0]}'"
    cat > "$TEMPLATE_FILE" <<'EOF'
# =========================
# Environment
# =========================

# Global
_BPXK_AUTOCVT=ON
PYTHONUNBUFFERED=1
ZOS_CURRENT_USER="{{ global.zos_current_user }}"
ZOS_ADMIN_USER="{{ global.zos_admin_user }}"
ZOS_CA_LABEL="{{ global.zos_ca_label }}"
ZOS_KEYRING="{{ global.zos_keyring }}"
ZOS_CREATE_CERTS="{{ global.zos_create_certs }}"

# Application
APP_BASE_NAME="{{ app.base_name }}"
APP_SHORT_NAME="{{ app.short_name }}"
APP_BASE_NAME_LOWER="{{ app.base_name | lower }}"
APP_ZOS_VERSION="{{ app.zos_version }}"
APP_FULL_VERSION="{{ app.full_version }}"
APP_DESCRIPTION="{{ app.description }}"
APP_HLQ="{{ app.app_hlq }}"

# Sandbox
SANDBOX_DIR="${SANDBOX_DIR:-{{ sandbox.path }}}"

# Java
JAVA_HOME="{{ java.java_home }}"

# Python
PYTHON_HOME="{{ python.python_home }}"

# Repositories
DBB_REPO_URL="{{ repositories.dbb_url }}"

# ZOAU
ZOAU_HOME="${ZOAU_HOME:-{{ zoau.zoau_home }}}"

# ZBuilder
ZBUILDER_SOURCE="{{ zbuilder.source_dir }}"
ZBUILDER_TARGET="{{ zbuilder.target_dir }}"

# DBB
DBB_HOME="{{ dbb.dbb_home }}"
DBB_BUILD="{{ dbb.dbb_build }}"
DBB_CWD="{{ dbb.dbb_cwd }}"
DBB_APP_CONF="{{ dbb.dbb_app_conf }}"
DBB_LOG_FOLDER="${DBB_LOG_FOLDER:-{{ dbb.dbb_log_dir }}}"
DBB_BUILD_PATH="{{ dbb.dbb_build }}"

# Wazi Deploy
DEPLOY_WAZIDEPLOY_HOME="${DEPLOY_WAZIDEPLOY_HOME:-{{ wazideploy.wazideploy_home }}}"
DEPLOY_PYENV_ACTIVATE_PATH="${DEPLOY_PYENV_ACTIVATE_PATH:-{{ wazideploy.wazideploy_home }}/bin/activate}"
DEPLOY_DEPLOYMENT_METHOD="${DEPLOY_DEPLOYMENT_METHOD:-{{ wazideploy.deployment_method }}}"
DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-{{ wazideploy.deployment_envfile }}}"
DEPLOY_ZDEPLOY_FOLDER="${DEPLOY_ZDEPLOY_FOLDER:-{{ wazideploy.zdeploy_dir }}}"
DEPLOY_LOG_FOLDER="${DEPLOY_LOG_FOLDER:-{{ wazideploy.deploy_log_dir }}}"
DEPLOY_TYPES_MAPPING_FILES="${DEPLOY_TYPES_MAPPING_FILES:-{{ wazideploy.types_pattern_mapping }}}"

# ZCodeScan
SCAN_PYENV_ACTIVATE_PATH="${SCAN_PYENV_ACTIVATE_PATH:-{{ zcodescan.zcodescan_home }}/bin/activate}"
SCAN_CWD_FOLDER="${SCAN_CWD_FOLDER:-{{ zcodescan.cwd_dir }}}"
SCAN_SOURCE_FOLDER="${SCAN_SOURCE_FOLDER:-{{ zcodescan.src_dir }}}"
SCAN_OUTPUT_FOLDER="${SCAN_OUTPUT_FOLDER:-{{ zcodescan.output_dir }}}"
SCAN_RULE_FILE="${SCAN_RULE_FILE:-{{ zcodescan.rule_file }}}"
SCAN_ENCODING="${SCAN_ENCODING:-{{ zcodescan.src_encoding }}}"
SCAN_CONFIG_FILE="${SCAN_CONFIG_FILE:-{{ zcodescan.config_file }}}"
SCAN_MAX_RC="${SCAN_MAX_RC:-{{ zcodescan.max_rc }}}"

# z/OS Connect
ZOSCONNECT_HOME="{{ zosconnect.zosconnect_home }}"
ZOSCONNECT_HTTP_PORT="{{ zosconnect.http_port }}"
ZOSCONNECT_HTTPS_PORT="{{ zosconnect.https_port }}"
ZOSCONNECT_SERVER_FOLDER="${ZOSCONNECT_SERVER_FOLDER:-{{ zosconnect.server_dir }}/servers/{{ app.base_name | lower }}Server}"
ZOSCONNECT_SYS_PROCLIB="{{ zosconnect.sys_proclib }}"
ZOSCONNECT_TASK_USER="{{ zosconnect.task_user }}"

# Frontend
FRONTEND_LIBERTY_HOME="{{ frontend.liberty_home }}"
FRONTEND_HTTP_PORT="{{ frontend.http_port }}"
FRONTEND_HTTPS_PORT="{{ frontend.https_port }}"
FRONTEND_SYS_PROCLIB="{{ frontend.sys_proclib }}"
FRONTEND_TASK_USER="{{ frontend.task_user }}"

# CICS
CICS_USER="${CICS_USER:-{{ cics.user }}}"
CICS_PASSWORD="${CICS_PASSWORD:-{{ cics.password }}}" #pragma: allowlist secret
CICS_IPIC_PORT="{{ cics.ipic_port }}"
CICS_CMCI_PORT="${CICS_CMCI_PORT:-{{ cics.cmci_port }}}"
CICS_DEBUG_PORT="${CICS_DEBUG_PORT:-{{ cics.debug_port }}}"
CICS_HLQ="${CICS_HLQ:-{{ cics.cics_hlq }}}"
CICS_USS_DIR="${CICS_USS_DIR:-{{ cics.uss_dir }}}"
CICS_SEC="${CICS_SEC:-{{ cics.cics_sec }}}"
CICS_SYS_PROCLIB="{{ cics.sys_proclib }}"
CICS_HOST="${CICS_HOST:-{{ cics.host }}}"

# IMS
IMS_DISABLED="${IMS_DISABLED:-{{ ims.disabled }}}"
IMS_APP_HLQ="${IMS_APP_HLQ:-{{ ims.ims_hlq }}}"
IMS_SYS_HLQ="${IMS_SYS_HLQ:-{{ ims.ims_sys_hlq }}}"
IMS_HOST="${IMS_HOST:-{{ ims.host }}}"
IMS_PORT="${IMS_PORT:-{{ ims.port }}}"
IMS_USER="${IMS_USER:-{{ ims.user }}}"
IMS_PASSWORD="${IMS_PASSWORD:-{{ ims.password }}}" #pragma: allowlist secret
IMS_DATASTORE="${IMS_DATASTORE:-{{ ims.datastore }}}"
IMS_PLEX="${IMS_PLEX:-{{ ims.dfs_imsplex }}}"
IMS_JAVA_CONF_PATH="${IMS_JAVA_CONF_PATH:-{{ ims.java_conf_path }}}"
IMS_DFS_IMS_SSID="${IMS_DFS_IMS_SSID:-{{ ims.dfs_ims_ssid }}}"
IMS_JAVA_FOLDER="${IMS_JAVA_FOLDER:-{{ ims.ims_java_dir }}}"
IMS_JAVA_HOME="${IMS_JAVA_HOME:-{{ ims.ims_java_home }}}"
IMS_IXVOLSER="${IMS_IXVOLSER:-{{ ims.ixvolser }}}"
IMS_IRLM_ENABLEMENT="${IMS_IRLM_ENABLEMENT:-{{ ims.irlm_enablement }}}"
IMS_DATABASE_LOCK_MANAGER_SERVER_NAME="${IMS_DATABASE_LOCK_MANAGER_SERVER_NAME:-{{ ims.database_lock_manager_server_name }}}"

# zconfig
ZCONFIG_ZCB_HOME="{{ zconfig.zcb_home }}"
ZCONFIG_HOME="${ZCONFIG_HOME:-{{ zconfig.zconfig_home }}}"

# Debug
DEBUG_HLQ="{{ debug.debug_hlq }}"
DEBUG_TCPIP_HQL="{{ debug.tcpip_hlq }}"
EQAPROF_CONF_DIR="{{ debug.eqaprof_conf_dir }}"

# Db2
DB2_HLQ="${DB2_HLQ:-{{ db2.db2_hlq }}}"
DB2_SSID="${DB2_SSID:-{{ db2.ssid }}}"
DB2_JAVA_FOLDER="${DB2_JAVA_FOLDER:-{{ db2.db2_java_dir }}}"

# MQ
MQ_QMGR_NAME=$(get_section_value 'mq' 'qmgr_name')
MQ_INSTALL_HLQ=$(get_section_value 'mq' 'install_hlq')
MQ_QMGR_HLQ=$(get_section_value 'mq' 'qmgr_hlq')
MQ_CPF=$(get_section_value 'mq' 'cpf')
MQ_PROCLIB=$(get_section_value 'mq' 'proclib')
MQ_OTMA_GROUP=$(get_section_value 'mq' 'otma_group')
MQ_OTMA_IMS=$(get_section_value 'mq' 'otma_ims')

# Zowe Configuration
ZOWE_RSE_PROFILE="{{ zowe.rse_profile }}"
RSE_PROFILE_ARG="--rse-profile {{ zowe.rse_profile }}"
EOF
    python3 "$LIB_DIR/config.py" --resolve-template "$TEMPLATE_FILE" > "$ENV_FILE"
    rm -f "$TEMPLATE_FILE"
fi

set -a
chmod 777 "$ENV_FILE" 2>/dev/null || true
source "$ENV_FILE"
set +a

# List of variables to check
VARS_TO_CHECK=(
  NEXUS_USER
  NEXUS_PASSWORD
  IMS_USER
  IMS_PASSWORD
  CICS_USER
  CICS_PASSWORD
)

error=0

if [ "$(uname)" = "OS/390" ]; then
    for var in "${VARS_TO_CHECK[@]}"; do
      if [ -z "${!var}" ]; then
        print_error "Error: variable '$var' is not set or is empty." >&2
        error=1
      fi
    done
    
    if [ "$error" -eq 1 ]; then
      print_error "One or more variables are missing. Stopping script." >&2
      rm -f "$ENV_FILE"
      exit 1
    fi
    print_info "All variables are properly set."
fi

export PATH=${PYTHON_HOME:-}/bin:$JAVA_HOME:/bin:$PATH

