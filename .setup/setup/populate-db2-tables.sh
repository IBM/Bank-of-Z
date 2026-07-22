#!/bin/env bash
set -e
# =============================================================================
# Script  : populate-db2-tables.sh
# Summary : DB2 table populate
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# - Binds packages and Grant
# - Inserts initial data
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

exec > >(while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf "${CYAN}[POPULATE-DB2-TABLES]${NC} %s\n" "${line}"
done) 2>&1

# =========================
# Environment
# =========================
export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

# =========================
# Populate DB2 tables
# =========================
rm -f /tmp/IMS-Db2-* 2>/dev/null || true
rm -f /tmp/CICS-Db2-* 2>/dev/null || true
rm -f /tmp/Db2-* 2>/dev/null || true

# CICS
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DB2BIND" --templateFile "$SCRIPTS_DIR/../jcl/cics/Db2-bind.j2"  --outputFile "/tmp/CICS-Db2-bind-$$.jcl"
run_job_and_wait "/tmp/CICS-Db2-bind-$$.jcl"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DB2BINST" --templateFile "$SCRIPTS_DIR/../jcl/cics/Db2-insert.j2"  --outputFile "/tmp/CICS-Db2-insert-$$.jcl"
run_job_and_wait "/tmp/CICS-Db2-insert-$$.jcl"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DB2BIND" --templateFile "$SCRIPTS_DIR/../jcl/cics/Db2-grant.j2"  --outputFile "/tmp/CICS-Db2-grant-$$.jcl"
run_job_and_wait "/tmp/CICS-Db2-grant-$$.jcl" "8"

# IMS
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DB2BIND" --templateFile "$SCRIPTS_DIR/../jcl/ims/Db2-bind.j2"  --outputFile "/tmp/IMS-Db2-bind-$$.jcl"
run_job_and_wait "/tmp/IMS-Db2-bind-$$.jcl"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DB2BINST" --templateFile "$SCRIPTS_DIR/../jcl/ims/Db2-insert.j2"  --outputFile "/tmp/IMS-Db2-insert-$$.jcl"
run_job_and_wait "/tmp/IMS-Db2-insert-$$.jcl"

rm -f /tmp/IMS-Db2-* 2>/dev/null || true
rm -f /tmp/CICS-Db2-* 2>/dev/null || true
rm -f /tmp/Db2-* 2>/dev/null || true

exit $?