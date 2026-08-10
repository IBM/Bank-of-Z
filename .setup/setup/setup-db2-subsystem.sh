#!/bin/env bash
set -eu
# =============================================================================
# Script  : setup-db2-subsystem.sh
# Summary : Provision a Db2 subsystem using zconfig
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# - Activates the zconfig virtual environment
# - Runs zconfig apply against db2-provision-hs26o.yaml
# - Verifies the subsystem is active
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

exec > >(while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf "${CYAN}[ZCONFIG-DB2]${NC} %s\n" "${line}" 2>/dev/null || true
done) 2>&1

# =========================
# Environment
# =========================
export ZCONFIG_HOME=$(echo "$ZCONFIG_HOME" | sed "s|~|$HOME|g")
export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

# =========================
# Activate zconfig environment
# =========================
if [ -f "$ZCONFIG_HOME/bin/activate" ]; then
    source "$ZCONFIG_HOME/bin/activate"
else
    print_error "zconfig virtual environment not found at $ZCONFIG_HOME/bin/activate"
    print_info "Ensure zconfig is installed at: $ZCONFIG_HOME"
    exit 1
fi

# =========================
# Stage 1: Provision Db2 subsystem with zconfig
# =========================
print_stage "STAGE 1: Provision Db2 subsystem with zconfig"

cd "$SCRIPTS_DIR/../zconfig"

print_info "Applying Db2 provisioning configuration..."
print_info "YAML: db2-provision-hs26o.yaml"
print_info "Db2 SSID: ${DB2_SSID}"
print_info "Db2 HLQ:  ${DB2_HLQ}"

zconfig apply \
    -e db2_ssid="${DB2_SSID}" \
    -e db2_hlq="${DB2_HLQ}" \
    db2-provision-hs26o.yaml -v

RC=$?
if [ "$RC" -eq 0 ]; then
    print_success "zconfig Db2 provisioning completed successfully!"
else
    print_error "zconfig failed with return code: $RC"
    print_info "Check logs in: $SCRIPTS_DIR/logs"
    deactivate
    exit 1
fi

deactivate

# =========================
# Stage 2: Verify Db2 subsystem is active
# =========================
print_stage "STAGE 2: Verify Db2 subsystem is active"

print_info "Waiting for Db2 subsystem ${DB2_SSID} to initialise..."
sleep 15

set +e
opercmd "D A,${DB2_SSID}MSTR" 2>/dev/null | grep -q "${DB2_SSID}MSTR"
ACTIVE=$?
set -e

if [ "$ACTIVE" -eq 0 ]; then
    print_success "Db2 subsystem ${DB2_SSID} (${DB2_SSID}MSTR) is active"
else
    print_warning "Could not confirm Db2 subsystem ${DB2_SSID} is active"
    print_info "The subsystem may still be initialising — check with: opercmd 'D A,${DB2_SSID}MSTR'"
fi

print_success "Db2 subsystem setup completed"
print_info "Subsystem ID: ${DB2_SSID}"
print_info "HLQ:          ${DB2_HLQ}"

exit 0

# Made with Bob
