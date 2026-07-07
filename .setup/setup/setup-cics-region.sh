#!/bin/env bash
set -eu
# =============================================================================
# Script  : setup-cics-region.sh
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
export DEBUG_PORT=${DEBUG_PORT:-$(get_section_value 'cics' 'debug_port')}
export ZOAU_HOME=${ZOAU_HOME:-$(get_section_value 'zoau' 'zoau_home')}
export ZCONFIG_HOME=$(get_section_value 'zconfig' 'zconfig_home')
export ZCONFIG_HOME=$(echo "$ZCONFIG_HOME" | sed "s|~|$HOME|g")
export ZCS_HOME=$(get_section_value 'zconfig' 'zcb_home')
export ZCS_HOME=$(echo "$ZCS_HOME" | sed "s|~|$HOME|g")
export JAVA_HOME=$(get_section_value 'zconfig' 'java_home')
export DBB_BUILD_PATH=$(get_section_value 'dbb' 'dbb_build')
export EQAW_HLQ=$(get_section_value 'taz' 'hlq')

export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

# =========================
# Cancel CICS region
# Ignore errors if already cancelled
# =========================
set +e
jcan P "CICS${APP_SHORT_NAME}"  2>/dev/null
opercmd "C CICS${APP_SHORT_NAME}"  2>/dev/null
sleep 10
drm "${APP_BASE_NAME}.${APP_VERSION}.*" 2>/dev/null
drm "${APP_BASE_NAME}.CICS${APP_SHORT_NAME}.*"  2>/dev/null
drm "${APP_BASE_NAME}.DBB.*"  2>/dev/null
sleep 5
tsocmd "ALLOC DA('${APP_BASE_NAME}.${APP_VERSION}.LOADLIB') NEW CATALOG DSNTYPE(LIBRARY) DSORG(PO) RECFM(U) BLKSIZE(32760) SPACE(100,20) CYL"
# =========================
# Cleanup
# =========================
rm -rf "$SCRIPTS_DIR/logs"
rm -rf "$SANDBOX_DIR/CICS${APP_SHORT_NAME}"
rm -rf "$SANDBOX_DIR/diagnostics"
set -e

# =============================================
# Stage 1: Create JVM profile file
# =============================================
print_stage "STAGE 1: Create JVM profile file"

zconfig_dir="$SCRIPTS_DIR/../zconfig"

cat > "$zconfig_dir/EYUSMSSJ.jvmprofile" <<EOF
JAVA_HOME=/usr/lpp/java/java21/current_64
WORK_DIR=$SANDBOX_DIR
-Xms128M
-Xmx1G
-Xmso1M
-Dfile.encoding=ISO-8859-1
WLP_INSTALL_DIR=/usr/lpp/cicsts/cicsts63/wlp
STDOUT=//DD:JVMOUT
STDERR=//DD:JVMERR
JVMTRACE=//DD:JVMTRACE
JVMLOG=//DD:JVMLOG
-Xgcpolicy:gencon
-Xscmx128M
-Xshareclasses:name=cicsts.&APPLID;,groupAccess,nonfatal
_BPXK_DISABLE_SHLIB=YES
-Dcom.ibm.tools.attach.enable=no
EOF

print_success "JVM profile file created successfully!"

# =============================================
# Stage 2: Create CICS resource overrides file
# =============================================
print_stage "STAGE 2: Create CICS resource overrides file"

uss_config_dir="$SANDBOX_DIR/CICS$APP_SHORT_NAME/config"
rm -rf "$uss_config_dir"
mkdir -p "$uss_config_dir/resourceoverrides"

cat > "$uss_config_dir/resourceoverrides/resourceOverrides.cicsoverrides.yaml" <<EOF
schemaVersion: resourceOverrides/1.200
resourceOverrides:
  - tcpipservice:
    - selector:
        name: ZOSEE
        group: BANKZGRP
      overrides:
        portnumber: $IPIC_PORT
    - selector:
        name: EQADTCN
        group: EQA
      overrides:
        portnumber: $DEBUG_PORT
  - ipconn:
    - selector:
        name: ZOSCONN
        group: BANKZGRP
      overrides:
        port: $IPIC_PORT
EOF

print_success "Overrides file created successfully!"

# =========================
# Stage 3: Create CICS instance with zconfig
# =========================
print_stage "STAGE 3: Create CICS instance with zconfig"

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
  -e region_uss_dir="$SANDBOX_DIR" \
  -e java_home="/usr/lpp/java/java21/current_64" \
  -e cmci_port="$CMCI_PORT" \
  -e eqaw_hlq="$EQAW_HLQ" \
  cics-region.yaml

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
# Stage 4: Create DEBUG Items
# =========================
print_stage "Stage 4: Create DEBUG Items"
export RIGHT='APPLID of CICS                       X'
export LEFT='               APPLID=CICS'
export SPACES=$((8-${#APP_SHORT_NAME} - 1))
export MIDDLE=$(printf '%s,%*s' ${APP_SHORT_NAME} $SPACES "")

rm -f "/tmp/tcpip-create*"
rm -f "/tmp/plt-create*"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "cics_hlq=${APP_BASE_NAME}.CICS${APP_SHORT_NAME}" --extraVar "applid_line=${LEFT}${MIDDLE}${RIGHT}" \
    --templateFile "$SCRIPTS_DIR/../jcl/cics/tcpip-create.j2"  --outputFile "/tmp/tcpip-create-$$.jcl"
run_job_and_wait "/tmp/tcpip-create-$$.jcl" "8"

python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "cics_hlq=${APP_BASE_NAME}.CICS${APP_SHORT_NAME}" --templateFile "$SCRIPTS_DIR/../jcl/cics/plt-create.j2"  --outputFile "/tmp/plt-create-$$.jcl"
run_job_and_wait "/tmp/plt-create-$$.jcl" "8"


# =========================
# Stage 5: Start CICS region
# =========================
print_stage "STAGE 5: Start CICS region"

jsub "${APP_BASE_NAME}.CICS${APP_SHORT_NAME}.DFHSTART" 
sleep 10
print_info "${CYAN}[ZCONFIG-INSTALL]${NC} CICS Region Job Started"
sleep 10


# ======================================
# Stage 6: Add CICS region to dtcn.ports
# ======================================
print_stage "Stage 6: Add CICS region to dtcn.ports"
# =========================
# Update /etc/debug/dtcn.ports
# =========================
DTCN_PORTS="/etc/debug/dtcn.ports"
DTCN_PORTS_TMP="/tmp/dtcn.ports$$"
print_info "${CYAN}[ZCONFIG-INSTALL]${NC} Checking ${DTCN_PORTS} for CICS${APP_SHORT_NAME}..."

if grep -Eq "^[[:space:]]*CICS${APP_SHORT_NAME}:27103([[:space:]]*)$" "${DTCN_PORTS}"; then
    print_info "${CYAN}[ZCONFIG-INSTALL]${NC} CICSBOZ already present in ${DTCN_PORTS}"
else
    print_info "${CYAN}[ZCONFIG-INSTALL]${NC} Adding CICS${APP_SHORT_NAME}:27103 to ${DTCN_PORTS}"
    
  
    if netstat | grep -q "EQARMTD"
    then 
      echo "EQARMTD is started";
    else
      echo "Starting Remote Debug Service (EQARMTD)"
      opercmd "S EQARMTD"
    fi

    chtag -tc IBM-1047 "$DTCN_PORTS"
    rm -f /tmp/dtcn.ports*
    cp "${DTCN_PORTS}" "${DTCN_PORTS_TMP}"
    echo "" >> "$DTCN_PORTS_TMP"
    echo "  CICS${APP_SHORT_NAME}:27103" >> "$DTCN_PORTS_TMP"
    cp "${DTCN_PORTS_TMP}" "$DTCN_PORTS"
    chtag -r "$DTCN_PORTS"
    opercmd "C EQAPROF"  
    sleep 5
    opercmd "S EQAPROF" 
    sleep 5
fi

# =========================
# Stage 7: Cleanup
# =========================
rm -f "$zconfig_dir/EYUSMSSJ.jvmprofile"
exit 0