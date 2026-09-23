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
trap 'exec >&- 2>&-; wait' EXIT

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


# =========================
# Cleanup
# =========================
opercmd "C CICS${APP_SHORT_NAME}"  2>/dev/null
jcan P "${CICS_SYS_PROCLIB}(CICS${APP_SHORT_NAME})" 2>/dev/null || true
sleep 10
drm "${APP_HLQ}.${APP_ZOS_VERSION}.*" 2>/dev/null
drm "${APP_HLQ}.CICS${APP_SHORT_NAME}.*"  2>/dev/null
drm "${APP_HLQ}.DBB.*"  2>/dev/null
mrm "${CICS_SYS_PROCLIB}(CICS${APP_SHORT_NAME})" 2>/dev/null || true
mrm "${CICS_SYS_PROCLIB}(CICS${APP_SHORT_NAME}J)" 2>/dev/null || true
sleep 5
rm -rf "$SCRIPTS_DIR/logs"
rm -rf "$SANDBOX_DIR/CICS${APP_SHORT_NAME}"
rm -rf "$SANDBOX_DIR/diagnostics"
set -e

tsocmd "ALLOC DA('${APP_HLQ}.${APP_ZOS_VERSION}.LOADLIB') NEW CATALOG DSNTYPE(LIBRARY) DSORG(PO) RECFM(U) BLKSIZE(32760) SPACE(100,20) CYL"

# =========================
# Stage 1: Create CICS instance with zconfig
# =========================
print_stage "STAGE 1: Create CICS instance with zconfig"

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
  -e debug_stc_user="${DEBUG_STC_USER}" \
  -e db2_hlq="${DB2_HLQ}" \
  -e cics_hlq="${CICS_HLQ}" \
  -e cics_uss_dir="${CICS_USS_DIR}" \
  -e tcpip_hlq="${DEBUG_TCPIP_HQL}" \
  -e cics_sec="${CICS_SEC}" \
  -e db2_ssid="${DB2_SSID}" \
  -e proclib="${CICS_SYS_PROCLIB}" \
  -e cics_ipic_port="${CICS_IPIC_PORT}" \
  -e cics_debug_port="${CICS_DEBUG_PORT}" \
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
# Stage 2: Create DEBUG Items
# =========================
print_stage "STAGE 2: Create DEBUG Items"
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
# Stage 3: Configure RACF profiles
# =========================
print_stage "STAGE 3: Configure RACF profiles"
print_info "Configuring RACF profiles..."
set +e
print_info "Defining RACF STARTED class..."
tsocmd "RDEFINE STARTED CICS${APP_SHORT_NAME}.* STDATA(USER(${CICS_USER}) TRUSTED(YES))" 2>/dev/null

print_info "Defining RACF ACICSPCT profiles and permissions..."
for p in OCR1 OCR2 OCR3 OCR4 OCR5; do
    tsocmd "RDEFINE ACICSPCT $p UACC(NONE)" 2>/dev/null
    tsocmd "PERMIT $p CLASS(ACICSPCT) ID(${CICS_USER}) ACCESS(READ)" 2>/dev/null
done

print_info "Defining RACF DCICSDCT profiles and permissions..."
tsocmd "RDEFINE DCICSDCT CESE UACC(NONE)" 2>/dev/null
tsocmd "PERMIT CESE CLASS(DCICSDCT) ID(${CICS_USER}) ACCESS(UPDATE)" 2>/dev/null

print_info "Refreshing RACF..."
tsocmd "SETROPTS RACLIST(STARTED ACICSPCT DCICSDCT) REFRESH" 2>/dev/null
chmod 777 "$SANDBOX_DIR"
chmod -R 777 "$SANDBOX_DIR/CICS${APP_SHORT_NAME}"
chown -R "$CICS_USER" "$SANDBOX_DIR/CICS${APP_SHORT_NAME}"
set -e

# =========================
# Stage 4: Start CICS region
# =========================
print_stage "STAGE 4: Start CICS region"
if [[ "$CICS_SYS_PROCLIB" != "${APP_HLQ}.PROCLIB" ]]; then
    # PROC was written directly into the system PROCLIB by zconfig — start it as a started task
    opercmd "S CICS${APP_SHORT_NAME}"
else
    # App-owned PROCLIB is not in the system PROCLIB concatenation, so 'S' won't find the PROC.
    # Build a JOB inline that sets JCLLIB to the app PROCLIB and EXECs the PROC, then submit it.
    SUBMIT_JCL="/tmp/CICS${APP_SHORT_NAME}J-$$.jcl"
    cat > "$SUBMIT_JCL" << EOF
//CICS${APP_SHORT_NAME} JOB (${ZOS_CURRENT_USER}),MSGCLASS=X,CLASS=A,NOTIFY=&SYSUID,
//  REGION=0M,USER=${ZOS_CURRENT_USER}
//PROCLIB  JCLLIB  ORDER=${CICS_SYS_PROCLIB}
//CICSSTEP EXEC PROC=CICS${APP_SHORT_NAME}
/*
EOF
    a2e -f ISO8859-1 -t IBM-1047 "$SUBMIT_JCL"
    print_info "Saving start JCL to ${CICS_SYS_PROCLIB}(CICS${APP_SHORT_NAME}J)..."
    dcp "$SUBMIT_JCL" "${CICS_SYS_PROCLIB}(CICS${APP_SHORT_NAME}J)"
    print_info "Submitting CICS start job via jsub..."
    jsub -f "$SUBMIT_JCL"
    rm -f "$SUBMIT_JCL"
fi
sleep 5
print_info "CICS Region Job Started"
sleep 10
print_info ""
print_info "To manage the region:"
if [[ "$CICS_SYS_PROCLIB" != "${APP_HLQ}.PROCLIB" ]]; then
    print_info "  Start:  opercmd 'S CICS${APP_SHORT_NAME}'"
    print_info "  Stop:   opercmd 'C CICS${APP_SHORT_NAME}'"
else
    print_info "  Start:  jsub '${CICS_SYS_PROCLIB}(CICS${APP_SHORT_NAME}J)'"
    print_info "  Stop:   jcan P 'CICS${APP_SHORT_NAME}'"
fi
print_info ""

print_success "CICS Bank of Z setup completed"

exit 0
