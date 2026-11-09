#!/bin/env bash
set -eu
# =============================================================================
# Script  : deprovision-db2-subsystem.sh
# Summary : Remove a Db2 subsystem previously provisioned by zconfig.
#
# Removing a Db2 subsystem deletes its zconfig-managed resources and is
# destructive. It also runs during environment setup if DB2_REPROVISION=true.
# Invoke through setup-common.sh with DB2_DEPROVISION_CONFIRM set to the exact
# configured SSID. Bank consumers must already be stopped; this script never
# stops IMS, CICS, MQ, or frontend servers.
# =============================================================================

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"
source "$SCRIPTS_DIR/../lib/db2-status.sh"

"$PYTHON_HOME/bin/python3" "$SCRIPTS_DIR/../lib/db2_provisioning.py" \
    check-config "$CONFIG_FILE" || exit 1

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
ssid_pattern='^[A-Z$#@][A-Z0-9$#@]{0,3}$'
if [[ ! "$DB2_SSID" =~ $ssid_pattern ]]; then
    print_error "Invalid Db2 subsystem ID; refusing removal"
    exit 1
fi
target_id="db2://${DB2_SSID}"

print_stage "Deprovision Db2 subsystem with zconfig"
print_warning "Removing zconfig-managed Db2 subsystem ${DB2_SSID}"

managed=$(read_db2_managed_state) || exit 1
if [[ "$managed" != present ]]; then
    print_error "No zconfig state exists for ${target_id}; refusing to remove an unknown subsystem"
    deactivate
    exit 1
fi

verify_db2_consumers_stopped || exit 1

print_info "Using zconfig --ie so an already-absent Db2 resource does not block repeatable teardown"
if ! zconfig rm "$target_id" -v --ie; then
    print_error "zconfig failed to remove ${target_id}"
    deactivate
    exit 1
fi

managed=$(read_db2_managed_state) || exit 1
if [[ "$managed" != absent ]]; then
    print_error "zconfig still reports ${target_id} after removal"
    deactivate
    exit 1
fi

state=$(read_db2_master_status) || exit 1
if [[ "$state" == active ]]; then
    print_error "Db2 subsystem ${DB2_SSID} is still active after zconfig removal"
    deactivate
    exit 1
fi

deactivate
print_success "Db2 subsystem ${DB2_SSID} deprovisioned successfully"
