#!/bin/env bash
set -eu
# =============================================================================
# Script  : setup-db2-subsystem.sh
# Summary : Provision a Db2 subsystem using zconfig
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# - Activates the zconfig virtual environment
# - Runs zconfig apply against db2-provision.yaml
# - Verifies the subsystem is active
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"
source "$SCRIPTS_DIR/../lib/db2-status.sh"

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
print_info "YAML: db2-provision.yaml"
print_info "Db2 SSID: ${DB2_SSID}"
print_info "Db2 HLQ:  ${DB2_HLQ}"

state=$(read_db2_master_status) || exit 1
if [[ "$state" == active ]]; then
    print_error "Db2 subsystem ${DB2_SSID} is already active; refusing to provision over it"
    print_info "Use an unused SSID, or set DB2_PROVISION=false to use the existing subsystem"
    deactivate
    exit 1
fi

# Resolve values before zconfig reads the file, including optional SMS fields.
provision_file=$(mktemp "$SCRIPTS_DIR/../zconfig/db2-rendered.XXXXXX")
trap 'rm -f "$provision_file"' EXIT
if command -v chtag >/dev/null 2>&1; then
    chtag -b "$provision_file"
fi
"$PYTHON_HOME/bin/python3" "$SCRIPTS_DIR/../lib/db2_provisioning.py" render \
    "$SCRIPTS_DIR/../zconfig/db2-provision.yaml" "$provision_file"
if command -v chtag >/dev/null 2>&1; then
    chtag -tc UTF-8 "$provision_file"
fi

if zconfig apply "$provision_file" -v; then
    print_success "zconfig Db2 provisioning completed successfully!"
else
    print_error "zconfig Db2 provisioning failed"
    print_info "Check logs in: $SCRIPTS_DIR/logs"
    deactivate
    exit 1
fi

deactivate

# =========================
# Stage 2: Verify Db2 subsystem is active
# =========================
print_stage "STAGE 2: Verify Db2 subsystem is active"

print_info "Waiting up to ${DB2_PROVISION_START_TIMEOUT_SECONDS}s for Db2 subsystem ${DB2_SSID} to initialise..."
elapsed=0
while true; do
    state=$(read_db2_master_status) || exit 1
    [[ "$state" == active ]] && break
    if [ "$elapsed" -ge "$DB2_PROVISION_START_TIMEOUT_SECONDS" ]; then
        print_error "Db2 subsystem ${DB2_SSID} did not become active within ${DB2_PROVISION_START_TIMEOUT_SECONDS}s"
        exit 1
    fi
    sleep 5
    elapsed=$((elapsed + 5))
done

print_success "Db2 subsystem ${DB2_SSID} (${DB2_SSID}MSTR) is active"

print_success "Db2 subsystem setup completed"
print_info "Subsystem ID: ${DB2_SSID}"
print_info "HLQ:          ${DB2_HLQ}"

exit 0

# Made with Bob
