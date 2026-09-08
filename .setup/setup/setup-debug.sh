#!/bin/env bash
set -eu

# =============================================================================
# Script  : setup-debug.sh
# Summary : Configure Debug Profile Service (DPS, EQAPROF) to work with 
#           Bank of Z CICS and IMS regions
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# - Verifies prerequisites
# - Stops EQAPROF task
# - Configures dtcn.ports for CICS
# - Configures eqaprof.env for IMS
# - Starts debug services
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

exec > >(while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf "${CYAN}[DEBUG]${NC} %s\n" "${line}" 2>/dev/null || true
done) 2>&1

# =========================
# Environment
# =========================
export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"
export CICS_REGION="CICS${APP_SHORT_NAME}"

# =========================
# Stage 1: Stop EQAPROF
# =========================
set +e
print_stage "Stage 1: Stop EQAPROF task"
opercmd "C EQAPROF" 
sleep 5

mkdir -p "${EQAPROF_CONF_DIR}"
set -e


# ======================================
# Stage 2: Add CICS region to dtcn.ports
# ======================================
print_stage "Stage 2: Add CICS region to dtcn.ports"
# =========================
# Update /etc/debug/dtcn.ports
# =========================
DTCN_PORTS="/etc/debug/dtcn.ports"
DTCN_PORTS_TMP="/tmp/dtcn.ports$$"
print_info "Checking ${DTCN_PORTS} for CICS${APP_SHORT_NAME}..."

if grep -Eq "^[[:space:]]*CICS${APP_SHORT_NAME}:${CICS_DEBUG_PORT}([[:space:]]*)$" "${DTCN_PORTS}"; then
    print_info "CICSBOZ already present in ${DTCN_PORTS}"
    cp "${DTCN_PORTS}" "${EQAPROF_CONF_DIR}/dtcn.ports"
else
    print_info "Trying to add CICS${APP_SHORT_NAME}:${CICS_DEBUG_PORT} to ${DTCN_PORTS}"
    set +e
    chtag -tc IBM-1047 "$DTCN_PORTS"
    RC=$?
    set -e
    if [ $RC -eq 0 ]; then
        rm -f /tmp/dtcn.ports*
        cp "${DTCN_PORTS}" "${DTCN_PORTS_TMP}"
        echo "" >> "$DTCN_PORTS_TMP"
        echo "  CICS${APP_SHORT_NAME}:${CICS_DEBUG_PORT}" >> "$DTCN_PORTS_TMP"
        cp "${DTCN_PORTS_TMP}" "${EQAPROF_CONF_DIR}/dtcn.ports"
        chtag -r "$DTCN_PORTS"
    else
        print_warning "Fail adding CICS${APP_SHORT_NAME}:${CICS_DEBUG_PORT} to ${DTCN_PORTS} (maybe permission deny)."
    fi
fi

# =======================================================
# Stage 3: Modify eqaprof.env to customize for BANKZ IMS
# =======================================================
print_stage "Stage 3: Modify eqaprof.env to customize for BANKZ IMS"

EQADREST_ENV="/etc/debug/eqadrest.env"

if [ -f "${EQADREST_ENV}" ]; then
    cp "${EQADREST_ENV}" "${EQAPROF_CONF_DIR}/eqadrest.env"
else
    print_warning "${EQADREST_ENV} does not exists (maybe not installed)."
fi

python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "ims_hlq=${IMS_APP_HLQ}" \
    --extraVar "debug_hlq=${DEBUG_HLQ}" \
    --extraVar "app_hlq=${APP_HLQ}" \
    --templateFile "$SCRIPTS_DIR/../debug_config/eqaprof.env.j2"  --outputFile "${EQAPROF_CONF_DIR}/eqaprof.env"

# =======================================================
# Stage 4: Grant RACF permissions for STCDBG user
# =======================================================
set +e
print_stage "Stage 4: Granting RACF permissions for STCDBG..."
run_tso "RDEFINE FACILITY BPX.SERVER UACC(NONE)"
run_tso "PERMIT BPX.SERVER CLASS(FACILITY) ID(STCDBG) ACCESS(UPDATE)"
run_tso "SETROPTS RACLIST(FACILITY) REFRESH"
run_tso "RLIST FACILITY BPX.SERVER ALL"

run_tso "RDEFINE SURROGAT BPX.SRV.** UACC(NONE)"
run_tso "PERMIT BPX.SRV.** CLASS(SURROGAT) ID(STCDBG) ACCESS(READ)"
run_tso "SETROPTS RACLIST(SURROGAT) REFRESH"
run_tso "RLIST SURROGAT BPX.SRV.** ALL"
set -e



# ===================================
# Stage 5: Start EQAPROF and EQARMTD
# ===================================
set +e
print_stage "Stage 5: Start EQAPROF task"
opercmd -p "S EQAPROF,CFGDIR='${EQAPROF_CONF_DIR}'" 

if netstat | grep -q "EQARMTD"
then 
    echo "EQARMTD is started";
else
    echo "Starting Remote Debug Service (EQARMTD)"
    opercmd "S EQARMTD"
fi
sleep 5

set -e