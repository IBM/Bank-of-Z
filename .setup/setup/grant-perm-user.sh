#!/bin/env bash
set -e
# =============================================================================
# Script  : grant-perm-user.sh
# Summary : Grants DB2 and RACF keyring access rights for a given user.
#
# Usage   : grant-perm-user.sh <MYUSER>
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# Requires RACF SPECIAL authority - run as IBMUSER or equivalent admin.
#
# Grants:
#   1. DB2 DSNR class access (so the user can connect to DB2)
#   2. RDATALIB access to the RACF keyring (so Liberty can read the TLS cert)
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

exec > >(while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf "${CYAN}[GRANT-USER]${NC} %s\n" "${line}" 2>/dev/null || true
done) 2>&1

# =========================
# Parameter validation
# =========================
MYUSER="$1"

if [[ -z "$MYUSER" ]]; then
    print_error "Usage: $0 <MYUSER> - the MYUSER parameter is required."
    exit 1
fi

# =========================
# Finalize:
# =========================
finalize_results() {
    RC=$?

    rm -f /tmp/Db2-* 2> /dev/null || true
    rm -f "$SCRIPTS_DIR/../config/.env" 2> /dev/null || true

    # =========================
    # Result
    # =========================
    if [[ $RC -eq 0 ]]; then
        print_success "All grants completed successfully for user $MYUSER."
    else
        print_error "Grant failed for user $MYUSER (return code: $RC)."
    fi

    exit $RC
}

trap finalize_results EXIT

rm -f /tmp/Db2-* 2>/dev/null || true

# =========================
# DB2 RACF access (DSNR class)
# =========================
print_info "Granting DB2 DSNR access for $MYUSER..."
tsocmd "RDEFINE DSNR (${DB2_SSID}.BATCH) UACC(NONE)"
tsocmd "PERMIT ${DB2_SSID}.BATCH CLASS(DSNR) ID($MYUSER) ACCESS(READ)"
tsocmd "PERMIT ${DB2_SSID}.BATCH CLASS(DSNR) ID($ZOS_ADMIN_USER) ACCESS(READ)"
tsocmd "PERMIT ${DB2_SSID}.* CLASS(DSNR) ID($MYUSER) ACCESS(READ)"
tsocmd "PERMIT ${DB2_SSID}.* CLASS(DSNR) ID($ZOS_ADMIN_USER) ACCESS(READ)"
tsocmd "SETROPTS RACLIST(DSNR) REFRESH"

# =========================
# RACF keyring access (RDATALIB class)
# Requires RACF SPECIAL authority - run once per image by an admin.
# SETROPTS failures are suppressed - the class may already be active.
# =========================
print_info "Granting RACF keyring access for $MYUSER..."
RDATALIB_PROFILE="${ZOS_ADMIN_USER}.${ZOS_KEYRING}.LST"
tsocmd "SETROPTS GENERIC(RDATALIB)" >/dev/null 2>&1 || true
tsocmd "SETROPTS CLASSACT(RDATALIB) RACLIST(RDATALIB)" >/dev/null 2>&1 || true
tsocmd "RDEFINE RDATALIB $RDATALIB_PROFILE UACC(NONE)" >/dev/null 2>&1 || true
tsocmd "PERMIT $RDATALIB_PROFILE CLASS(RDATALIB) ID($MYUSER) ACCESS(CONTROL)"
tsocmd "SETROPTS RACLIST(RDATALIB) REFRESH" >/dev/null 2>&1 || true
print_success "RDATALIB access granted for $MYUSER on keyring $RDATALIB_PROFILE"

# =========================
# Generate and submit the DB2 grant JCL
# =========================
print_info "Submitting DB2 table grant JCL for $MYUSER..."
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile "$CONFIG_FILE" \
    --extraVar "db2_user=$MYUSER" --templateFile "$SCRIPTS_DIR/../jcl/cics/Db2-grant-user.j2" --outputFile "/tmp/CICS-Db2-grant-$$.jcl"

run_job_and_wait "/tmp/CICS-Db2-grant-$$.jcl"
