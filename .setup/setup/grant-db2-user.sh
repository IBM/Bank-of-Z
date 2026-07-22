#!/bin/env bash
set -e
# =============================================================================
# Script  : grant-db2-user.sh
# Summary : Grants DB2 access rights for a given user
#
# Usage   : grant-db2-user.sh <MYUSER>
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# - Generates the grant JCL from the CICS template
# - Submits the job and waits for it to complete
# - Prints success or error depending on the job's return code
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

exec > >(while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf "${CYAN}[DB2-GRANT]${NC} %s\n" "${line}"
done) 2>&1

# =========================
# Parameter validation
# =========================
MYUSER="$1"

if [[ -z "$MYUSER" ]]; then
    print_error "Usage: $0 <MYUSER> - the MYUSER parameter is required."
    exit 1
fi

rm -f /tmp/Db2-* 2>/dev/null || true

# =========================
# RACF
# =========================
set +e
tsocmd "RDEFINE DSNR (${DB2_SSID}.BATCH) UACC(NONE)"
tsocmd "PERMIT ${DB2_SSID}.BATCH CLASS(DSNR) ID($MYUSER) ACCESS(READ)"
tsocmd "PERMIT ${DB2_SSID}.BATCH CLASS(DSNR) ID($ZOS_ADMIN_USER) ACCESS(READ)"
tsocmd "SETROPTS RACLIST(DSNR) REFRESH"
set -e

# =========================
# Generate and submit the grant JCL
# =========================
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile "$CONFIG_FILE" \
    --extraVar "db2_user=$MYUSER" --templateFile "$SCRIPTS_DIR/../jcl/cics/Db2-grant-user.j2" --outputFile "/tmp/CICS-Db2-grant-$$.jcl"

run_job_and_wait "/tmp/CICS-Db2-grant-$$.jcl"
RC=$?

rm -f /tmp/Db2-*

# =========================
# Result
# =========================
if [[ $RC -eq 0 ]]; then
    print_success "DB2 grant completed successfully for user $MYUSER."
else
    print_error "DB2 grant failed for user $MYUSER (return code: $RC)."
fi

exit $RC
