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

_opercmd_out=$(opercmd "D A,${DB2_SSID}MSTR" 2>/dev/null || true)
print_info "opercmd output: ${_opercmd_out}"
if echo "${_opercmd_out}" | grep -v "NOT FOUND" | grep -v "D A,${DB2_SSID}MSTR" | grep -q "${DB2_SSID}MSTR"; then
    print_error "Db2 subsystem ${DB2_SSID} is already active; refusing to provision over it"
    print_info "Use an unused SSID, or set DB2_PROVISION=false to use the existing subsystem"
    deactivate
    exit 1
fi

if zconfig apply \
    -e db2_ssid="${DB2_SSID}" \
    -e db2_hlq="${DB2_HLQ}" \
    -e db2_user_catalog="${DB2_PROVISION_USER_CATALOG}" \
    -e db2_authid="${DB2_PROVISION_AUTHID}" \
    -e db2_volume="${DB2_PROVISION_VOLUME}" \
    -e db2_storage_class="${DB2_PROVISION_STORAGE_CLASS}" \
    -e db2_data_class="${DB2_PROVISION_DATA_CLASS}" \
    -e db2_java_home="${DB2_PROVISION_JAVA_HOME}" \
    -e db2_javaenv="${DB2_PROVISION_JAVAENV}" \
    -e db2_javaenvv="${DB2_PROVISION_JAVAENVV}" \
    -e db2_jvmprops="${DB2_PROVISION_JVMPROPS}" \
    -e db2_sdsnexit="${DB2_PROVISION_SDSNEXIT}" \
    -e cics_hlq="${CICS_HLQ}" \
    db2-provision.yaml -v; then
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
until opercmd "D A,${DB2_SSID}MSTR" 2>/dev/null | grep -v "NOT FOUND" | grep -v "D A,${DB2_SSID}MSTR" | grep -q "${DB2_SSID}MSTR"; do
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
