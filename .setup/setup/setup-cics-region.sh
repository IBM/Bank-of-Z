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

exec > >(while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf "${CYAN}[ZCONFIG-CICS]${NC} %s\n" "${line}" 2>/dev/null || true
done) 2>&1

finalize_results() {
    RC=$?
    if [ -f "$BACKUP_FILE" ]; then
        mv "$BACKUP_FILE" "$DEFINITION_FILE"
        chtag -tc $YAML_ENCODING "$DEFINITION_FILE"
    fi
    if [ -f "$DEBUG_BACKUP" ]; then
        mv "$DEBUG_BACKUP" "$DEBUG_FILE"
        chtag -tc $YAML_ENCODING "$DEBUG_FILE"
    fi
    exit $RC
}

trap finalize_results EXIT


# =========================
# Environment
# =========================
export ZCONFIG_HOME=$(echo "$ZCONFIG_HOME" | sed "s|~|$HOME|g")
export ZCONFIG_ZCB_HOME=$(echo "$ZCONFIG_ZCB_HOME" | sed "s|~|$HOME|g")


export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

# =========================
# Cancel CICS region
# Ignore errors if already cancelled
# =========================
set +e
export DEFINITION_FILE="$SCRIPTS_DIR/../zconfig/bank-of-z-definitions.yaml"
export BACKUP_FILE="${DEFINITION_FILE}.back"
export DEBUG_FILE="$SCRIPTS_DIR/../zconfig/debug-definitions.yaml"
export DEBUG_BACKUP="${DEBUG_FILE}.back"
export YAML_ENCODING=$(chtag -p "$DEFINITION_FILE" | awk '{print $2}')
if [[ "$APP_HLQ" != "BANKZ" ]]; then
    chtag -tc ISO8859-1 "$DEFINITION_FILE"
    chtag -tc ISO8859-1 "$DEBUG_FILE"
    mv "$DEFINITION_FILE" "$BACKUP_FILE"
    mv "$DEBUG_FILE" "$DEBUG_BACKUP"
    cat "$BACKUP_FILE" | sed "s/BANKZ.${APP_ZOS_VERSION}/${APP_HLQ}.${APP_ZOS_VERSION}/" > "$DEFINITION_FILE"
    cat "$DEBUG_BACKUP" | sed "s/BANKZ.CICSBOZ/${APP_HLQ}.CICS${APP_SHORT_NAME}/" > "$DEBUG_FILE"
fi

if [[ "$DB2_SSID" != "DBD1" ]]; then
    if [ ! -f "$BACKUP_FILE" ]; then
        cp "$DEFINITION_FILE" "$BACKUP_FILE"
    fi
    # Use binary read/write via python3 to avoid _BPXK_AUTOCVT corrupting
    # the YAML file's encoding tag when writing through a shell redirect.
    _BPXK_AUTOCVT=OFF python3 - "$DEFINITION_FILE" "$DB2_SSID" <<'PYEOF'
import sys, re
path, ssid = sys.argv[1], sys.argv[2]
with open(path, 'rb') as f:
    data = f.read()
data = data.replace(b'DBD1', ssid.encode('latin-1'))
with open(path, 'wb') as f:
    f.write(data)
PYEOF
fi

# =========================
# Cleanup
# =========================
opercmd "C CICS${APP_SHORT_NAME}"  2>/dev/null
jcan P "${CICS_SYS_PROCLIB}(CICS${APP_SHORT_NAME})" 2>/dev/null || true
sleep 10
drm "${APP_HLQ}.${APP_ZOS_VERSION}.*" 2>/dev/null
drm "${APP_HLQ}.CICS${APP_SHORT_NAME}.*"  2>/dev/null
drm "${APP_HLQ}.DBB.*"  2>/dev/null
sleep 5
rm -rf "$SCRIPTS_DIR/logs"
rm -rf "$SANDBOX_DIR/CICS${APP_SHORT_NAME}"
rm -rf "$SANDBOX_DIR/diagnostics"
set -e

tsocmd "ALLOC DA('${APP_HLQ}.${APP_ZOS_VERSION}.LOADLIB') NEW CATALOG DSNTYPE(LIBRARY) DSORG(PO) RECFM(U) BLKSIZE(32760) SPACE(100,20) CYL"

# =============================================
# Stage 1: Create JVM profile file
# =============================================
print_stage "STAGE 1: Create JVM profile file"

zconfig_dir="$SCRIPTS_DIR/../zconfig"

cat > "$zconfig_dir/EYUSMSSJ.jvmprofile" <<EOF
JAVA_HOME=$JAVA_HOME
WORK_DIR=$SANDBOX_DIR
-Xms128M
-Xmx1G
-Xmso1M
-Dfile.encoding=ISO-8859-1
WLP_INSTALL_DIR=${CICS_USS_DIR}/wlp
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
schemaVersion: resourceOverrides/1.0
resourceOverrides:
  - tcpipservice:
    - selector:
        name: ZOSEE
        group: BANKZGRP
      overrides:
        portnumber: $CICS_IPIC_PORT
    - selector:
        name: EQADTCN
        group: EQA
      overrides:
        portnumber: $CICS_DEBUG_PORT
EOF

print_success "Overrides file created successfully!"

# =========================
# Stage 3: Create CICS instance with zconfig
# =========================
print_stage "STAGE 3: Create CICS instance with zconfig"

export PATH="$ZCONFIG_ZCB_HOME/bin:$PATH"

if [ -f "$ZCONFIG_HOME/bin/activate" ]; then
    source "$ZCONFIG_HOME/bin/activate"
else
    print_warning "zconfig virtual environment not found at $ZCONFIG_HOME/bin/activate"
fi

cd "$SCRIPTS_DIR/../zconfig"
zconfig apply \
  -e applid="CICS${APP_SHORT_NAME}" \
  -e sysid="${APP_SHORT_NAME}" \
  -e region_hlq="${APP_HLQ}" \
  -e region_uss_dir="$SANDBOX_DIR" \
  -e java_home="$JAVA_HOME" \
  -e cmci_port="$CICS_CMCI_PORT" \
  -e debug_hlq="$DEBUG_HLQ" \
  -e db2_hlq="${DB2_HLQ}" \
  -e cics_hlq="${CICS_HLQ}" \
  -e cics_uss_dir="${CICS_USS_DIR}" \
  -e tcpip_hlq="${DEBUG_TCPIP_HQL}" \
  -e cics_sec="${CICS_SEC}" \
  -e db2_ssid="${DB2_SSID}" \
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
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "cics_hlq=${APP_HLQ}.CICS${APP_SHORT_NAME}" --extraVar "applid_line=${LEFT}${MIDDLE}${RIGHT}" \
    --extraVar "tcpip_hlq=${DEBUG_TCPIP_HQL}" \
    --templateFile "$SCRIPTS_DIR/../jcl/cics/tcpip-create.j2"  --outputFile "/tmp/tcpip-create-$$.jcl"
run_job_and_wait "/tmp/tcpip-create-$$.jcl"

# =========================
# # Stage 5: Configure RACF STARTED profile
# =========================
print_stage "Stage 5: Configure RACF STARTED profile"
print_info "Configuring RACF STARTED profile..."
set +e
print_info "Defining RACF STARTED class..."
tsocmd "RDEFINE STARTED CICS${APP_SHORT_NAME}.* STDATA(USER(${CICS_USER}) TRUSTED(YES))" 2>/dev/null
print_info "Altering RACF STARTED class (update if already exists)..."
tsocmd "RALTER STARTED CICS${APP_SHORT_NAME}.* STDATA(USER(${CICS_USER}) TRUSTED(YES))" 2>/dev/null
print_info "Refreshing RACF..."
tsocmd "SETROPTS RACLIST(STARTED) REFRESH" 2>/dev/null
#print_info "Removing old PROCLIB member..."
#mrm "${CICS_SYS_PROCLIB}(CICS${APP_SHORT_NAME})" 2>/dev/null || true
chmod 777 "$SANDBOX_DIR"
chmod -R 777 "$SANDBOX_DIR/CICS${APP_SHORT_NAME}"
chown -R "$CICS_USER" "$SANDBOX_DIR/CICS${APP_SHORT_NAME}"
set -e

# =========================
# # Stage 6: Grant RACF access to credit-check transactions (OCR1-OCR5)
# CRECUST runs these asynchronously via EXEC CICS RUN TRANSID.
# With SEC=YES, CICS CSMI performs a FASTAUTH check against ACICSPCT
# for each child transaction even when XTRAN=NO. Without these permits
# the RUN TRANSID call fails with RESP=NOTAUTH(70), causing every
# Create Customer request to return a 400.
# No CICS region restart is required — SETROPTS RACLIST REFRESH is
# picked up immediately by the running region.
# =========================
print_stage "Stage 6: Grant RACF access to credit-check transactions (OCR1-OCR5)"
set +e
for TXN in OCR1 OCR2 OCR3 OCR4 OCR5; do
    print_info "Defining ACICSPCT profile for ${TXN}..."
    tsocmd "RDEFINE ACICSPCT ${TXN} UACC(NONE)" 2>/dev/null
    print_info "Permitting CICSUSER to run ${TXN}..."
    tsocmd "PERMIT ${TXN} CLASS(ACICSPCT) ID(CICSUSER) ACCESS(READ)" 2>/dev/null
done
print_info "Refreshing ACICSPCT RACLIST..."
tsocmd "SETROPTS RACLIST(ACICSPCT) REFRESH" 2>/dev/null
set -e
print_success "RACF access granted for OCR1-OCR5 to CICSUSER"

# =========================
# Stage 7: Define MVS log streams for CICS journal
# zconfig creates the CICS PROC in VENDOR.PROCLIB; we just need
# the DASD-only log streams that CICS requires before starting.
# =========================
print_stage "Stage 8: Define MVS log streams"
rm -f "/tmp/LOGSTREAM-$$.jcl"
cat > "/tmp/LOGSTREAM-$$.jcl" <<LOGEOF
//DEFLOGS  JOB CLASS=A,MSGCLASS=H,NOTIFY=&SYSUID
//STEP1    EXEC PGM=IXCMIAPU
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
  DATA TYPE(LOGR) REPORT(NO)
  DEFINE LOGSTREAM NAME(STCOPER.CICS${APP_SHORT_NAME}.DFHLOG)
         DASDONLY(YES)
         MAXBUFSIZE(4096)
  DEFINE LOGSTREAM NAME(STCOPER.CICS${APP_SHORT_NAME}.DFHSHUNT)
         DASDONLY(YES)
         MAXBUFSIZE(4096)
/*
LOGEOF

a2e -f ISO8859-1 -t IBM-1047 "/tmp/LOGSTREAM-$$.jcl"
set +e
jsub "/tmp/LOGSTREAM-$$.jcl" 2>/dev/null
sleep 5
set -e
rm -f "/tmp/LOGSTREAM-$$.jcl"
print_info "Log streams defined (or already exist - OK)"

# =========================
# # Stage 8: Start CICS region
# zconfig wrote the PROC to VENDOR.PROCLIB — start it directly.
# =========================
print_stage "Stage 8: Start CICS region"
print_stage "STAGE 9: Start CICS region"
opercmd "S CICS${APP_SHORT_NAME}"
sleep 5
print_info "CICS Region Job Started"
sleep 10
print_info ""
print_info "To manage the region:"
print_info "  Start:  opercmd 'S CICS${APP_SHORT_NAME}'"
print_info "  Stop:   opercmd 'C CICS${APP_SHORT_NAME}'"
print_info ""

# =========================
# Stage 9: Cleanup
# =========================
rm -f "$zconfig_dir/EYUSMSSJ.jvmprofile"
print_success "CICS Bank of Z setup completed"
 
exit 0
