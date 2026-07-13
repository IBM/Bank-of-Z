#!/bin/env bash
set -eu
# =============================================================================
# Script  : setup-mq-queue-manager.sh
# Summary : Create and configure MQ queue manager with zconfig
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# - Verifies prerequisites
# - Creates MQ queue manager using zconfig
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
export ZCONFIG_HOME=$(echo "$ZCONFIG_HOME" | sed "s|~|$HOME|g")
export ZCONFIG_ZCB_HOME=$(echo "$ZCONFIG_ZCB_HOME" | sed "s|~|$HOME|g")

export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"


# =========================
# Stop queue manager
# =========================
set +e
opercmd "${MQ_CPF} STOP QMGR MODE(FORCE)"  2>/dev/null

# =========================
# TODO: any of this needed?
# Cleanup
# =========================
rm -rf "$SCRIPTS_DIR/logs"
rm -rf "$SANDBOX_DIR/CICS${APP_SHORT_NAME}"
rm -rf "$SANDBOX_DIR/diagnostics"
set -e

# =========================
# Stage 1: Create MQ queue manager with zconfig
# =========================
print_stage "STAGE 1: Create MQ queue manager with zconfig"

export PATH="$ZCONFIG_ZCB_HOME/bin:$PATH"

if [ -f "$ZCONFIG_HOME/bin/activate" ]; then
    source "$ZCONFIG_HOME/bin/activate"
else
    print_warning "zconfig virtual environment not found at $ZCONFIG_HOME/bin/activate"
fi

#TODO:
#cd "$SCRIPTS_DIR/../zconfig"
#rm -rf "$SANDBOX_DIR/CICS${APP_BASE_NAME}"

zconfig apply \
  -e install_hlq="${MQ_INSTALL_HLQ}" \
  -e qmgr_hlq="${MQ_QMGR_HLQ}" \
  -e port="${MQ_PORT}" \
  -e cpf="${MQ_CPF}"
  mq-queue-manager.yaml

RC=$?
if [ "$RC" -eq 0 ]; then
    print_success "ZConfig completed successfully!"
else
    print_error "ZConfig failed with return code: $RC"
    print_error "Check logs in: $SCRIPTS_DIR/logs"
    exit 1
fi

deactivate

# =========================
# Stage 2: Start MQ queue manager
# =========================
print_stage "STAGE 2: Start MQ queue manager"

set +e
opercmd "${MQ_CPF} START QMGR"  2>/dev/null
set -e

sleep 10
print_info "${CYAN}[ZCONFIG-INSTALL]${NC} MQ Queue Manager Started"
sleep 10

exit 0