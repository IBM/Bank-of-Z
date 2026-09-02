#!/bin/env bash
set -eu
# =============================================================================
# Script  : deprovision-db2-subsystem.sh
# Summary : Remove a Db2 subsystem previously provisioned by zconfig.
#
# This is deliberately not part of the normal `environment` phase. Removing
# a Db2 subsystem deletes its zconfig-managed resources and is destructive.
# Invoke through setup-common.sh with DB2_DEPROVISION_CONFIRM set to the exact
# configured SSID.
# =============================================================================

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

exec > >(while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf "${CYAN}[ZCONFIG-DB2]${NC} %s\n" "$line" 2>/dev/null || true
done) 2>&1

export ZCONFIG_HOME=$(echo "$ZCONFIG_HOME" | sed "s|~|$HOME|g")
export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

if [[ "${DB2_DEPROVISION_CONFIRM:-}" != "$DB2_SSID" ]]; then
    print_error "Refusing to deprovision Db2 subsystem ${DB2_SSID} without explicit confirmation"
    print_info "Run: DB2_DEPROVISION_CONFIRM=${DB2_SSID} .setup/setup-common.sh deprovision-db2"
    exit 2
fi

if [[ ! -f "$ZCONFIG_HOME/bin/activate" ]]; then
    print_error "zconfig virtual environment not found at $ZCONFIG_HOME/bin/activate"
    exit 1
fi

source "$ZCONFIG_HOME/bin/activate"
target_id="db2://${DB2_SSID}"

print_stage "Deprovision Db2 subsystem with zconfig"
print_warning "Removing zconfig-managed Db2 subsystem ${DB2_SSID}"

if ! zconfig ls 2>/dev/null | grep -Fq "$target_id"; then
    print_error "No zconfig state exists for ${target_id}; refusing to remove an unknown subsystem"
    deactivate
    exit 1
fi

if ! zconfig rm "$target_id" -v; then
    print_error "zconfig failed to remove ${target_id}"
    deactivate
    exit 1
fi

if zconfig ls 2>/dev/null | grep -Fq "$target_id"; then
    print_error "zconfig still reports ${target_id} after removal"
    deactivate
    exit 1
fi

_opercmd_out=$(opercmd "D A,${DB2_SSID}MSTR" 2>/dev/null || true)
if echo "${_opercmd_out}" | grep -v "NOT FOUND" | grep -v "D A,${DB2_SSID}MSTR" | grep -q "${DB2_SSID}MSTR"; then
    print_error "Db2 subsystem ${DB2_SSID} is still active after zconfig removal"
    deactivate
    exit 1
fi

deactivate
print_success "Db2 subsystem ${DB2_SSID} deprovisioned successfully"
