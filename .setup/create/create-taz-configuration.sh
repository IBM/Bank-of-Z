#!/bin/env bash
set -eu
# =============================================================================
# Script  : create-taz-configuration.sh
# Summary : Configure TAZ in CICS region
#
# - Configures TAZ CSD dataset
# - Submits CICS TAZ configuration JCL
# - Generates CICS startup PROC in SYS1.PROCLIB from DFHSTART member
# - Defines CICS started task profile in RACF
# - Updates /etc/debug/dtcn.ports
# - Restarts CICS region and EQAPROF
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

# =========================
# Environment
# =========================
export CICS_PDS="${APP_BASE_NAME}.CICS${APP_BASE_NAME}"
export TAZ_CICS_PDS="${CICS_PDS}.TAZ"
export DFHSTART="${APP_BASE_NAME}.CICS${APP_BASE_NAME}.DFHSTART"
export PROCLIB="SYS1.PROCLIB(CICS${APP_BASE_NAME})"
export ZOAU_HOME=${ZOAU_HOME:-$(get_section_value 'zoau' 'zoau_home')}
export DBG_SEQAMOD=${DBG_SEQAMOD:-$(get_section_value 'taz' 'steplib')}

export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

TAZ_JCL_TMP="/tmp/Cics-taz-$$.jcl"
PROC_TMP="/tmp/cics-proc-$$.jcl"

# =========================
# Cleanup temp files on exit
# =========================
cleanup() {
    rm -f "$TAZ_JCL_TMP" "$PROC_TMP" "$PROC_TMP.iconv"
}

trap cleanup EXIT

# =========================
# Recreate TAZ CICS PDS
# =========================
print_info "${CYAN}[TAZ-INSTALL]${NC} Configuring TAZ CSD for ${CICS_PDS}..."

set +e
opercmd "C CICS$APP_BASE_NAME" 2>&1 > /dev/null
sleep 2
drm "${TAZ_CICS_PDS}" 2>&1 > /dev/null
set -e

dtouch "${TAZ_CICS_PDS}"

# =========================
# Copy TAZ CSD definitions
# =========================
dcp "${SCRIPTS_DIR}/../csd/TAZCSD.csd" "${TAZ_CICS_PDS}(TAZCSD)"

# =========================
# Create DFHPLTPI member
# =========================
tmp_ascii="/tmp/DFHPLTPI.ascii"
tmp_ebcdic="/tmp/DFHPLTPI.ebcdic"

cat > "$tmp_ascii" << 'EOF'
         TITLE 'DFHPLT - IBM z/OS Debugger CICS Sample PLT'
         DFHPLT TYPE=INITIAL
         DFHPLT TYPE=ENTRY,PROGRAM=DFHDELIM
         DFHPLT TYPE=ENTRY,PROGRAM=EZACIC20
         DFHPLT TYPE=ENTRY,PROGRAM=EQA0CPLT
         DFHPLT TYPE=FINAL
         END DFHPLT
EOF

iconv -f ISO8859-1 -t IBM-1047 "$tmp_ascii" > "$tmp_ebcdic"
dcp "$tmp_ebcdic" "${TAZ_CICS_PDS}(DFHPLTPI)"

# =========================
# Generate and submit TAZ configuration JCL
# =========================
sed "s/#CSDPRFX\./${CICS_PDS}/g" "${SCRIPTS_DIR}/../jcl/Cics-taz.jcl" > "$TAZ_JCL_TMP"
JOBID=$(jsub -f "$TAZ_JCL_TMP" 2>/dev/null)

# =========================
# Extract DFHSTART content
# =========================
print_info "${CYAN}[TAZ-INSTALL]${NC} Reading ${DFHSTART}..."

if ! dcat "${DFHSTART}" > "$PROC_TMP"; then
    print_error "${RED}[TAZ-INSTALL]${NC} Unable to read ${DFHSTART}"
    exit 8
fi

# =========================
# Extract DD statements from DFHSTART
# =========================
DD_SPECIFIC=$(
    grep -E "^//(DFHAUXT|DFHBUXT|DFHDMPA|DFHDMPB|DFHCSD|DFHGCD|DFHINTRA|DFHLCD|DFHLRQ|DFHTEMP)" \
        "$PROC_TMP" || true
)

SYSIN_PARMS=$(
    awk '/^\/\/SYSIN.*DD \*/{found=1; next} found && /^\/\*/{exit} found{print}' "$PROC_TMP"
)

EYUSMSS_PARMS=$(
    awk '/^\/\/EYUSMSS.*DD \*/{found=1; next} found && /^\/\*/{exit} found{print}' "$PROC_TMP"
)

# =========================
# Extract individual SYSIN parameters
# =========================
SEC_VAL="SEC=YES"
GRPLIST_VAL=$(echo "$SYSIN_PARMS"  | grep "^GRPLIST="   | head -1 || true)
APPLID_VAL=$(echo "$SYSIN_PARMS"   | grep "^APPLID="    | head -1 || true)
SYSIDNT_VAL=$(echo "$SYSIN_PARMS"  | grep "^SYSIDNT="   | head -1 || true)
JVMDIR_VAL=$(echo "$SYSIN_PARMS"   | grep "^JVMPROFILE" | head -1 || true)
USSHOME_VAL=$(echo "$SYSIN_PARMS"  | grep "^USSHOME="   | head -1 || true)
GMTEXT_VAL=$(echo "$SYSIN_PARMS"   | grep "^GMTEXT="    | head -1 || true)
CPSMCONN_VAL=$(echo "$SYSIN_PARMS" | grep "^CPSMCONN="  | head -1 || true)

# Add EQALIST to GRPLIST if not already present
GRPLIST_FINAL=$(echo "$GRPLIST_VAL" | sed 's/[[:space:]]*$//' | sed 's/)$//')
GRPLIST_FINAL="${GRPLIST_FINAL},EQALIST)"

# =========================
# Build CICS PROC member
# =========================
print_info "${CYAN}[TAZ-INSTALL]${NC} Generating ${PROCLIB}..."

cat > "$PROC_TMP" << EOF
//CICS${APP_BASE_NAME} PROC
//CICS${APP_BASE_NAME} EXEC PGM=DFHSIP,REGION=0M,PARM=SI
//STEPLIB  DD DSN=DB2V13.SDSNLOAD,DISP=SHR
//         DD DSN=DB2V13.SDSNEXIT,DISP=SHR
//         DD DSN=CICSTS63.CICS.SDFHAUTH,DISP=SHR
//         DD DSN=CICSTS63.SDFHLIC,DISP=SHR
//         DD DSN=CICSTS63.CPSM.SEYUAUTH,DISP=SHR
//         DD DSN=CEE.SCEERUN2,DISP=SHR
//         DD DSN=CEE.SCEERUN,DISP=SHR
//DFHRPL   DD DSN=CICSTS63.CICS.SDFHLOAD,DISP=SHR
//         DD DSN=CICSTS63.CPSM.SEYULOAD,DISP=SHR
//         DD DSN=TCPIP.SEZATCP,DISP=SHR
//         DD DSN=FEL.SFELLOAD,DISP=SHR
//         DD DSN=CEE.SCEECICS,DISP=SHR
//         DD DSN=CEE.SCEERUN2,DISP=SHR
//         DD DSN=CEE.SCEERUN,DISP=SHR
//         DD DSN=${DBG_SEQAMOD},DISP=SHR
//         DD DSN=SYS1.MIGLIB,DISP=SHR
//         DD DSN=SYS1.SIEAMIGE,DISP=SHR
//         DD DSN=${APP_BASE_NAME}.V0R1M0.LOAD,DISP=SHR
${DD_SPECIFIC}
//EQADPFMB DD DSN=${APP_BASE_NAME}.CICS${APP_BASE_NAME}.EQADPFMB,DISP=SHR
//DFHTABLE DD DSN=${APP_BASE_NAME}.CICS${APP_BASE_NAME}.TAZ,DISP=SHR
//EYUSMSS  DD *
${EYUSMSS_PARMS}
/*
//CEEMSG   DD SYSOUT=*
//CEEOUT   DD SYSOUT=*
//DFHCXRF  DD SYSOUT=*
//LOGUSR   DD SYSOUT=*
//MSGUSR   DD SYSOUT=*
//SYSABEND DD SYSOUT=*
//SYSOUT   DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSUDUMP DD SYSOUT=*
//SYSIN    DD *
AICONS=AUTO
${APPLID_VAL}
AUXTR=OFF
AUXTRSW=NEXT
${CPSMCONN_VAL}
DB2CONN=YES
DUMP=YES
DUMPDS=AUTO
DUMPSW=NEXT
${GMTEXT_VAL}
${GRPLIST_FINAL}
${JVMDIR_VAL}
${SEC_VAL}
SECURETCPIP=NO
START=INITIAL
${SYSIDNT_VAL}
${USSHOME_VAL}
IRCSTRT=YES
ISC=YES
XTRAN=NO
XCMD=NO
XDCT=NO
XFCT=NO
XHFS=NO
XJCT=NO
XPPT=NO
XPCT=NO
XPSB=NO
XPTKT=NO
XRES=NO
DEBUGTOOL=NO
INITPARM=(EQA0CPLT='DTR,NLE,NWP')
PLTPI=PI
TCPIP=YES
/*
EOF

# =========================
# Convert PROC to EBCDIC and copy to SYS1.PROCLIB
# =========================
if ! iconv -f ISO8859-1 -t IBM-1047 "$PROC_TMP" > "$PROC_TMP.iconv"; then
    print_error "${RED}[TAZ-INSTALL]${NC} iconv to EBCDIC failed"
    exit 1
fi

chtag -r "$PROC_TMP.iconv"

if ! cp "$PROC_TMP.iconv" "//'${PROCLIB}'"; then
    print_error "${RED}[TAZ-INSTALL]${NC} Unable to write to ${PROCLIB}"
    exit 8
fi

print_info "${CYAN}[TAZ-INSTALL]${NC} ${PROCLIB} generated successfully"

# =========================
# Configure RACF STARTED profile and DB2 access
# =========================
print_info "${CYAN}[TAZ-INSTALL]${NC} Defining RACF STARTED profile for CICS${APP_BASE_NAME}..."

set +e
TMP_LOG="/tmp/racf_$$.log"
: > "$TMP_LOG"

{
    tsocmd "RDELETE STARTED CICS${APP_BASE_NAME}.*"
    tsocmd "RDEFINE STARTED CICS${APP_BASE_NAME}.* STDATA(USER(CICSUSER) GROUP(SYS1) TRUSTED(NO))"
    tsocmd "SETROPTS RACLIST(STARTED) REFRESH"

    tsocmd "RDEFINE FACILITY DFHDB2.AUTHTYPE.DBD1 UACC(NONE)"
    tsocmd "RALTER  FACILITY DFHDB2.AUTHTYPE.DBD1 UACC(NONE)"
    tsocmd "PERMIT DFHDB2.AUTHTYPE.DBD1 CLASS(FACILITY) ID(IBMUSER) ACCESS(READ)"
    tsocmd "PERMIT DFHDB2.AUTHTYPE.DBD1 CLASS(FACILITY) ID(CICSUSER) ACCESS(READ)"

    tsocmd "RDEFINE FACILITY DFHDB2.AUTHTYPE.${APP_BASE_NAME} UACC(NONE)"
    tsocmd "RALTER  FACILITY DFHDB2.AUTHTYPE.${APP_BASE_NAME} UACC(NONE)"
    tsocmd "PERMIT DFHDB2.AUTHTYPE.${APP_BASE_NAME} CLASS(FACILITY) ID(IBMUSER) ACCESS(READ)"
    tsocmd "PERMIT DFHDB2.AUTHTYPE.${APP_BASE_NAME} CLASS(FACILITY) ID(CICSUSER) ACCESS(READ)"

    tsocmd "SETROPTS RACLIST(FACILITY) REFRESH"

    #tsocmd "PERMIT FEKAPPL CLASS(APPL) ID(STCDBG) ACCESS(READ)"
    #tsocmd "RALTER APPL FEKAPPL UACC(NONE)"
    #tsocmd "SETROPTS RACLIST(APPL) REFRESH"
} > "$TMP_LOG" 2>&1
set -e

while IFS= read -r line; do
    print_info "${CYAN}[TAZ-INSTALL]${NC} $line"
done < "$TMP_LOG"

rm -f "$TMP_LOG"

print_info "${CYAN}[TAZ-INSTALL]${NC} RACF STARTED profile and DB2 access configured"

# =========================
# Update /etc/debug/dtcn.ports
# =========================
DTCN_PORTS="/etc/debug/dtcn.ports"
DTCN_ENTRY="  CICS${APP_BASE_NAME}:-1"

print_info "${CYAN}[TAZ-INSTALL]${NC} Checking ${DTCN_PORTS} for CICS${APP_BASE_NAME}..."

touch "${DTCN_PORTS}"

TMP_DTCN="/tmp/dtcn.ports.$$"
iconv -f IBM-1047 -t ISO8859-1 "${DTCN_PORTS}" > "${TMP_DTCN}.ascii" 2>/dev/null || cp "${DTCN_PORTS}" "${TMP_DTCN}.ascii"

if grep -Eq "^[[:space:]]*CICS${APP_BASE_NAME}:-1([[:space:]]*)$" "${TMP_DTCN}.ascii"; then
    print_info "${CYAN}[TAZ-INSTALL]${NC} CICS${APP_BASE_NAME} already present in ${DTCN_PORTS}"
else
    print_info "${CYAN}[TAZ-INSTALL]${NC} Adding CICS${APP_BASE_NAME}:-1 to ${DTCN_PORTS}"
    printf "\n%s\n" "${DTCN_ENTRY}" >> "${TMP_DTCN}.ascii"
fi

iconv -f ISO8859-1 -t IBM-1047 "${TMP_DTCN}.ascii" > "${DTCN_PORTS}"
chtag -t -c IBM-1047 "${DTCN_PORTS}"
rm -f "${TMP_DTCN}.ascii"

# =========================
# Restart CICS region
# =========================
opercmd "S CICS$APP_BASE_NAME" 2>&1 | while IFS= read -r line; do
    print_info "${CYAN}[TAZ-INSTALL]${NC} $line"
done
print_info "${CYAN}[TAZ-INSTALL]${NC} CICS region CICS${APP_BASE_NAME} started"

# =========================
# Restart EQAPROF
# =========================
opercmd "C EQAPROF" 2>&1 | while IFS= read -r line; do
    print_info "${CYAN}[TAZ-INSTALL]${NC} $line"
done
sleep 5
opercmd "S EQAPROF" 2>&1 | while IFS= read -r line; do
    print_info "${CYAN}[TAZ-INSTALL]${NC} $line"
done
print_info "${CYAN}[TAZ-INSTALL]${NC} TAZ profile EQAPROF restarted"
