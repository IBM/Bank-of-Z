#!/bin/env bash
set -eu
# =============================================================================
# Script  : setup-ims-region.sh
# Summary : Create and configure IMS region with zconfig
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# - Verifies prerequisites
# - Creates IMS region using zconfig
# - Configures IMS Connect
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

exec > >(while IFS= read -r line; do print_info "${CYAN}[ZCONFIG-IMS]${NC} $line"; done) 2>&1

# =========================
# Environment
# =========================
export IMS_PORT=${IMS_PORT:-$(get_section_value 'ims' 'port')}
export IMS_DATASTORE=${IMS_DATASTORE:-$(get_section_value 'ims' 'datastore')}
export ZOAU_HOME=${ZOAU_HOME:-$(get_section_value 'zoau' 'zoau_home')}
export ZCONFIG_HOME=$(get_section_value 'zconfig' 'zconfig_home')
export ZCONFIG_HOME=$(echo "$ZCONFIG_HOME" | sed "s|~|$HOME|g")
export JAVA_HOME=$(get_section_value 'zconfig' 'java_home')
export BOZ_IMS_HLQ=${BOZ_IMS_HLQ:-$(get_section_value 'ims' 'ims_hlq')}

export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

# =========================
# Stop IBM BOZ regions
# =========================
set +e
jsub "${BOZ_IMS_HLQ}.JOBS(STOPMPP1)"  2>/dev/null
jsub "${BOZ_IMS_HLQ}.JOBS(STOPMPP2)"  2>/dev/null
jsub "${BOZ_IMS_HLQ}.IMSJAVA.JOBS(STOPJMP)"  2>/dev/null
sleep 5
jcan P "IMS2JMP1" 2>/dev/null
jcan P "IMS2MPP1" 2>/dev/null
jcan P "IMS2MPP2" 2>/dev/null
sleep 5
set -e
# =========================
# Activate zconfig environment
# =========================
if [ -f "$ZCONFIG_HOME/bin/activate" ]; then
    source "$ZCONFIG_HOME/bin/activate"
else
    print_warning "zconfig virtual environment not found at $ZCONFIG_HOME/bin/activate"
fi

# =========================
# Check and remove existing IMS region using zconfig
# =========================
cd "$SCRIPTS_DIR/../zconfig"

print_info "${CYAN}[ZCONFIG-IMS]${NC} Checking for existing IMS regions..."
if zconfig ls 2>/dev/null | grep -q "ims://${IMS_DATASTORE}"; then
    print_info "${CYAN}[ZCONFIG-IMS]${NC} Found existing IMS region ims://${IMS_DATASTORE}, removing..."
else
    print_info "${CYAN}[ZCONFIG-IMS]${NC} No existing IMS region found in zconfig, attempting cleanup anyway..."
fi

# Always attempt to remove the IMS region to clean up any leftover datasets
set +e
zconfig rm ims://${IMS_DATASTORE} -v
sleep 5
set -e
print_success "IMS region cleanup completed"

# =========================
# Cleanup USS directories
# =========================
rm -rf "$SCRIPTS_DIR/logs"
rm -rf "$SANDBOX_DIR/${IMS_DATASTORE}"
rm -rf "$SANDBOX_DIR/diagnostics"

# =========================
# Stage 1: Create IMS instance with zconfig
# =========================
print_stage "STAGE 1: Create IMS instance with zconfig"

cd "$SCRIPTS_DIR/../zconfig"

# Set IMS user to current user instead of ibmuser
# Ensure ZOS_USER is set (fallback to USER if not set)
: ${ZOS_USER:=$(printf '%s' "${USER:-${LOGNAME}}" | tr '[:lower:]' '[:upper:]')}
print_info "${CYAN}[ZCONFIG-IMS]${NC} Setting IMS user to ${ZOS_USER}"

zconfig apply -e ims_user="${ZOS_USER}" ims-region.yaml -v

RC=$?
if [ "$RC" -eq 0 ]; then
    print_success "ZConfig IMS region creation completed successfully!"
else
    print_error "ZConfig failed with return code: $RC"
    print_error "Check logs in: $SCRIPTS_DIR/logs"
    exit 1
fi

deactivate

# =========================
# Stage 2: Verify IMS region
# =========================
print_stage "STAGE 2: Verify IMS region"

print_info "${CYAN}[ZCONFIG-IMS]${NC} Waiting for IMS regions to start..."
sleep 15

# Check if IMS Control Region is running
print_info "${CYAN}[ZCONFIG-IMS]${NC} Checking IMS Control Region status..."
if opercmd "D A,${IMS_DATASTORE}" 2>/dev/null | grep -q "${IMS_DATASTORE}"; then
    print_success "IMS Control Region (${IMS_DATASTORE}) is running"
else
    print_warning "IMS Control Region (${IMS_DATASTORE}) status could not be verified"
fi

# Check if IMS Connect is running
print_info "${CYAN}[ZCONFIG-IMS]${NC} Checking IMS Connect status..."
IMS_HWS_JOB="${IMS_DATASTORE}HWS"
if opercmd "D A,${IMS_HWS_JOB}" 2>/dev/null | grep -q "${IMS_HWS_JOB}"; then
    print_success "IMS Connect (${IMS_HWS_JOB}) is running"
else
    print_warning "IMS Connect (${IMS_HWS_JOB}) status could not be verified"
fi

# Check if port is listening
print_info "${CYAN}[ZCONFIG-IMS]${NC} Checking if IMS Connect port ${IMS_PORT} is listening..."
if netstat -a 2>/dev/null | grep -q ":${IMS_PORT}.*LISTEN"; then
    print_success "IMS Connect is listening on port ${IMS_PORT}"
else
    print_warning "Port ${IMS_PORT} status could not be verified (may still be initializing)"
fi

print_success "IMS region setup completed!"
print_info "IMS Datastore: ${IMS_DATASTORE}"
print_info "IMS Connect Port: ${IMS_PORT}"

exit 0

# Made with Bob
