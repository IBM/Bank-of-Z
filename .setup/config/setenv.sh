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

# ``.env`` is a cached rendering of config.yaml.  Child setup scripts source
# this file again, so preserve explicit lifecycle overrides supplied by the
# caller before importing the cache.  In particular, a one-shot Db2 run may
# select a different SSID without editing config.yaml on the target system.
_BANKZ_CALLER_OVERRIDES=()
_BANKZ_CALLER_DB2_SSID_SET=false
_BANKZ_CALLER_DB2_PROVISION_JAVAENV_SET=false
_BANKZ_CALLER_DB2_PROVISION_JAVAENVV_SET=false
_BANKZ_CALLER_DB2_PROVISION_JVMPROPS_SET=false
_BANKZ_CALLER_DB2_PROVISION_SDSNEXIT_SET=false
[[ -n "${DB2_SSID+x}" ]] && _BANKZ_CALLER_DB2_SSID_SET=true
[[ -n "${DB2_PROVISION_JAVAENV+x}" ]] && _BANKZ_CALLER_DB2_PROVISION_JAVAENV_SET=true
[[ -n "${DB2_PROVISION_JAVAENVV+x}" ]] && _BANKZ_CALLER_DB2_PROVISION_JAVAENVV_SET=true
[[ -n "${DB2_PROVISION_JVMPROPS+x}" ]] && _BANKZ_CALLER_DB2_PROVISION_JVMPROPS_SET=true
[[ -n "${DB2_PROVISION_SDSNEXIT+x}" ]] && _BANKZ_CALLER_DB2_PROVISION_SDSNEXIT_SET=true
for _bankz_var in \
    CICS_AUTO_REPLY_GO \
    DB2_PROVISION DB2_REPROVISION DB2_HLQ DB2_SSID DB2_JAVA_FOLDER \
    DB2_PROVISION_USER_CATALOG DB2_PROVISION_AUTHID DB2_PROVISION_VOLUME \
    DB2_PROVISION_STORAGE_CLASS DB2_PROVISION_DATA_CLASS \
    DB2_PROVISION_JAVA_HOME DB2_PROVISION_JAVAENV DB2_PROVISION_JAVAENVV \
    DB2_PROVISION_JVMPROPS DB2_PROVISION_SDSNEXIT \
    DB2_PROVISION_START_TIMEOUT_SECONDS; do
    if [[ -n "${!_bankz_var+x}" ]]; then
        _BANKZ_CALLER_OVERRIDES+=("$_bankz_var=${!_bankz_var}")
    fi
done
# A profile can clear USER. Resolve it after loading profile settings because
# config.yaml uses ${USER} for z/OS user defaults.
export USER=$(printf '%s' "${USER:-${LOGNAME:-$(basename "$HOME")}}" | tr '[:lower:]' '[:upper:]')
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
CICS_AUTO_REPLY_GO="${CICS_AUTO_REPLY_GO:-{{ cics.auto_reply_go }}}"
CICS_CMCI_START_TIMEOUT_SECONDS="${CICS_CMCI_START_TIMEOUT_SECONDS:-{{ cics.cmci_start_timeout_seconds }}}"

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
DEBUG_STC_USER="{{ debug.debug_stc_user }}"
DEBUG_TCPIP_HQL="{{ debug.tcpip_hlq }}"
EQAPROF_CONF_DIR="{{ debug.eqaprof_conf_dir }}"

# Db2
DB2_PROVISION="${DB2_PROVISION:-{{ global.db2_provision }}}"
DB2_REPROVISION="${DB2_REPROVISION:-{{ global.db2_reprovision }}}"
DB2_HLQ="${DB2_HLQ:-{{ db2.db2_hlq }}}"
DB2_SSID="${DB2_SSID:-{{ db2.ssid }}}"
DB2_JAVA_FOLDER="${DB2_JAVA_FOLDER:-{{ db2.db2_java_dir }}}"
DB2_PROVISION_USER_CATALOG="${DB2_PROVISION_USER_CATALOG:-{{ db2_provisioning.user_catalog }}}"
DB2_PROVISION_AUTHID="${DB2_PROVISION_AUTHID:-{{ db2_provisioning.authid }}}"
DB2_PROVISION_VOLUME="${DB2_PROVISION_VOLUME:-{{ db2_provisioning.volume }}}"
DB2_PROVISION_STORAGE_CLASS="${DB2_PROVISION_STORAGE_CLASS:-{{ db2_provisioning.storage_class }}}"
DB2_PROVISION_DATA_CLASS="${DB2_PROVISION_DATA_CLASS:-{{ db2_provisioning.data_class }}}"
DB2_PROVISION_JAVA_HOME="${DB2_PROVISION_JAVA_HOME:-{{ db2_provisioning.java_home }}}"
DB2_PROVISION_JAVAENV="${DB2_PROVISION_JAVAENV:-{{ db2_provisioning.javaenv }}}"
DB2_PROVISION_JAVAENVV="${DB2_PROVISION_JAVAENVV:-{{ db2_provisioning.javaenvv }}}"
DB2_PROVISION_JVMPROPS="${DB2_PROVISION_JVMPROPS:-{{ db2_provisioning.jvmprops }}}"
DB2_PROVISION_SDSNEXIT="${DB2_PROVISION_SDSNEXIT:-{{ db2_provisioning.sdsnexit }}}"
DB2_PROVISION_START_TIMEOUT_SECONDS="${DB2_PROVISION_START_TIMEOUT_SECONDS:-{{ db2_provisioning.start_timeout_seconds }}}"

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

# Read the configured SSID from config.yaml rather than from .env: an explicit
# caller override can already be cached there while its dependent values still
# reflect the original configuration.
_BANKZ_CONFIG_DB2_SSID="$(get_section_value 'cfg' 'db2_ssid')"
_BANKZ_CONFIG_DB2_SSID_LOWER="$(printf '%s' "$_BANKZ_CONFIG_DB2_SSID" | tr '[:upper:]' '[:lower:]')"
for _bankz_override in "${_BANKZ_CALLER_OVERRIDES[@]}"; do
    export "$_bankz_override"
done

if [[ "$_BANKZ_CALLER_DB2_SSID_SET" == true ]] && [[ "$DB2_SSID" != "$_BANKZ_CONFIG_DB2_SSID" ]]; then
    _BANKZ_CALLER_DB2_SSID_LOWER="$(printf '%s' "$DB2_SSID" | tr '[:upper:]' '[:lower:]')"
    if [[ "$_BANKZ_CALLER_DB2_PROVISION_JAVAENV_SET" == false ]]; then
        DB2_PROVISION_JAVAENV="${DB2_PROVISION_JAVAENV//$_BANKZ_CONFIG_DB2_SSID/$DB2_SSID}"
    fi
    if [[ "$_BANKZ_CALLER_DB2_PROVISION_JAVAENVV_SET" == false ]]; then
        DB2_PROVISION_JAVAENVV="${DB2_PROVISION_JAVAENVV//$_BANKZ_CONFIG_DB2_SSID_LOWER/$_BANKZ_CALLER_DB2_SSID_LOWER}"
    fi
    if [[ "$_BANKZ_CALLER_DB2_PROVISION_JVMPROPS_SET" == false ]]; then
        DB2_PROVISION_JVMPROPS="${DB2_PROVISION_JVMPROPS//$_BANKZ_CONFIG_DB2_SSID_LOWER/$_BANKZ_CALLER_DB2_SSID_LOWER}"
    fi
    if [[ "$_BANKZ_CALLER_DB2_PROVISION_SDSNEXIT_SET" == false ]]; then
        DB2_PROVISION_SDSNEXIT="${DB2_PROVISION_SDSNEXIT//$_BANKZ_CONFIG_DB2_SSID/$DB2_SSID}"
    fi
fi

unset _BANKZ_CALLER_OVERRIDES _BANKZ_CALLER_DB2_SSID_SET \
    _BANKZ_CALLER_DB2_PROVISION_JAVAENV_SET \
    _BANKZ_CALLER_DB2_PROVISION_JAVAENVV_SET \
    _BANKZ_CALLER_DB2_PROVISION_JVMPROPS_SET \
    _BANKZ_CALLER_DB2_PROVISION_SDSNEXIT_SET \
    _BANKZ_CONFIG_DB2_SSID _BANKZ_CONFIG_DB2_SSID_LOWER \
    _BANKZ_CALLER_DB2_SSID_LOWER _bankz_override _bankz_var

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
