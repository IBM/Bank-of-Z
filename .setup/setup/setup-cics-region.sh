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

export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

# =========================
# Cancel CICS region
# Ignore errors if already cancelled
# =========================
set +e
jcan P "CICS${APP_SHORT_NAME}" & 2>/dev/null
opercmd "C CICS${APP_SHORT_NAME}" & 2>/dev/null
sleep 10
drm "${APP_BASE_NAME}.${APP_VERSION}.*" & 2>/dev/null
drm "${APP_BASE_NAME}.CICS${APP_SHORT_NAME}.*" & 2>/dev/null
drm "${APP_BASE_NAME}.DBB.*" & 2>/dev/null
sleep 5
tsocmd "ALLOC DA('${APP_BASE_NAME}.${APP_VERSION}.LOADLIB') NEW CATALOG DSNTYPE(LIBRARY) DSORG(PO) RECFM(U) BLKSIZE(32760) SPACE(5,5) CYL DIR(20)"
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
# Stage 4: Start CICS region
# =========================
print_stage "STAGE 4: Start CICS region"

jsub "${APP_BASE_NAME}.CICS${APP_SHORT_NAME}.DFHSTART" &
sleep 10
print_info "${CYAN}[ZCONFIG-INSTALL]${NC} CICS Region Job Started"
sleep 10

# =========================
# Stage 5: Cleanup
# =========================
rm -f "$zconfig_dir/EYUSMSSJ.jvmprofile"
exit 0