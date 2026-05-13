#!/bin/env bash
set -eu
# =============================================================================
# Script  : create-cics-region.sh
# Summary : Create and configure CICS region with zconfig
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# - Verifies prerequisites
# - Creates CICS region using zconfig
# - Configures CICS IPC connection
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

exec > >(while IFS= read -r line; do print_info "${CYAN}[ZCONFIG-INSTALL]${NC} $line"; done) 2>&1

# =========================
# Environment
# =========================
export CMCI_PORT=${CMCI_PORT:-$(get_section_value 'cics' 'cmci_port')}
export IPIC_PORT=${IPIC_PORT:-$(get_section_value 'cics' 'ipic_port')}
export ZOAU_HOME=${ZOAU_HOME:-$(get_section_value 'zoau' 'zoau_home')}
export ZCONFIG_HOME=$(get_section_value 'zconfig' 'zconfig_home')
export ZCONFIG_HOME=$(echo "$ZCONFIG_HOME" | sed "s|~|$HOME|g")
export ZCS_HOME=$(get_section_value 'zconfig' 'zcb_home')
export ZCS_HOME=$(echo "$ZCS_HOME" | sed "s|~|$HOME|g")
export JAVA_HOME=$(get_section_value 'zconfig' 'java_home')
export DBB_BUILD_PATH=$(get_section_value 'dbb' 'dbb_build')

export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

# =========================
# Cleanup
# =========================
rm -rf "$SCRIPTS_DIR/logs"

# =========================
# Cancel CICS region (ignore errors if already cancelled)
# =========================
set +e
jcan P "CICS${APP_SHORT_NAME}" & 2>/dev/null
opercmd "C CICS${APP_SHORT_NAME}" & 2>/dev/null
sleep 10
drm "${APP_BASE_NAME}.CICS${APP_SHORT_NAME}.*" & 2>/dev/null
set -e

# =========================
# Stage 1: Create CICS instance with zconfig
# =========================
print_stage "STAGE 2: Create CICS instance with zconfig"

export PATH="$ZCS_HOME/bin:$PATH"

if [ -f "$ZCONFIG_HOME/bin/activate" ]; then
    source "$ZCONFIG_HOME/bin/activate"
else
    print_warning "zconfig virtual environment not found at $ZCONFIG_HOME/bin/activate"
fi

cd "$SCRIPTS_DIR/../zconfig"
rm -rf "$SANDBOX_DIR/CICS${APP_BASE_NAME}"
zconfig apply \
  -e applid="CICS${APP_SHORT_NAME}" \
  -e sysid="${APP_SHORT_NAME}" \
  -e region_hlq="${APP_BASE_NAME}" \
  -e jvm_profile_dir="$SANDBOX_DIR" \
  -e java_home="/usr/lpp/java/java21/current_64" \
  -e cmci_port="$CMCI_PORT" \
  cics-region.yaml

RC=$?
if [ $RC -eq 0 ]; then
    print_success "ZConfig completed successfully!"
else
    print_error "ZConfig failed with return code: $RC"
    print_error "Check logs in: $SCRIPTS_DIR/logs"
    exit 1
fi

deactivate

# =========================
# Stage 2 - Start CICS region
# =========================
jsub "${APP_BASE_NAME}.CICS${APP_SHORT_NAME}.DFHSTART" &
sleep 10
print_info "${CYAN}[ZCONFIG-INSTALL]${NC} CICS Region Job Started"
sleep 10
# =========================
# Stage 3 - Configure CICS IPC connection
# =========================
submit_jcl "$SCRIPTS_DIR/../jcl/Cics-ipc.jcl"
sleep 3
opercmd "F CICS${APP_SHORT_NAME},CEDA INSTALL TCPIPSERVICE(ZOSCONN) GROUP(${APP_BASE_NAME}GRP)" &
sleep 2
opercmd "F CICS${APP_SHORT_NAME},CEDA INSTALL IPCONN(ZOSCONN) GROUP(${APP_BASE_NAME}GRP)" &
sleep 2
opercmd "F CICS${APP_SHORT_NAME},CEMT SET TCPIPSERVICE(ZOSCONN) OPEN" &
sleep 2

exit 0
