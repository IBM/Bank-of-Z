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
# Cleanup
# =========================
drm "${MQ_QMGR_HLQ}.*"  2>/dev/null

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

cd "$SCRIPTS_DIR/../zconfig"

#TODO: need to have MQ and CICS zconfig in the same place.
export PATH=/usr/lpp/IBM/cyp/v3r14/pyz/bin:$PATH

zconfig apply \
  -e mq_qmgr_name="${MQ_QMGR_NAME}" \
  -e mq_install_hlq="${MQ_INSTALL_HLQ}" \
  -e mq_qmgr_hlq="${MQ_QMGR_HLQ}" \
  -e mq_cpf="${MQ_CPF}" \
  -e mq_proclib="${MQ_PROCLIB}" \
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
print_info "${CYAN}[ZCONFIG-INSTALL]${NC} MQ queue manager Started"
sleep 10

exit 0