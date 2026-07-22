#!/bin/env bash
set -e
# =============================================================================
# Script  : setup-db2-tables.sh
# Summary : DB2 table creation
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# - Drops existing tables
# - Creates tables
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

exec > >(while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf "${CYAN}[SETUP-DB2-TABLES]${NC} %s\n" "${line}"
done) 2>&1

# =========================
# Environment
# =========================
export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

# =========================
# Create DB2 tables
# =========================
rm -f /tmp/IMS-Db2-* 2>/dev/null || true
rm -f /tmp/CICS-Db2-* 2>/dev/null || true
rm -f /tmp/Db2-* 2>/dev/null || true


# CICS
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DB2GRANT" --templateFile "$SCRIPTS_DIR/../jcl/cics/Db2-grant.j2"  --outputFile "/tmp/CICS-Db2-grant-$$.jcl"
run_job_and_wait "/tmp/CICS-Db2-grant-$$.jcl" "8"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DB2DROP" --templateFile "$SCRIPTS_DIR/../jcl/cics/Db2-drop.j2"  --outputFile "/tmp/CICS-Db2-drop-$$.jcl"
run_job_and_wait "/tmp/CICS-Db2-drop-$$.jcl" "8"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DB2CRE" --templateFile "$SCRIPTS_DIR/../jcl/cics/Db2-create.j2"  --outputFile "/tmp/CICS-Db2-create-$$.jcl"
run_job_and_wait "/tmp/CICS-Db2-create-$$.jcl"

# IMS
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DB2DROP" --templateFile "$SCRIPTS_DIR/../jcl/ims/Db2-drop.j2"  --outputFile "/tmp/IMS-Db2-drop-$$.jcl"
run_job_and_wait "/tmp/IMS-Db2-drop-$$.jcl" "8"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DB2CRE" --templateFile "$SCRIPTS_DIR/../jcl/ims/Db2-create.j2"  --outputFile "/tmp/IMS-Db2-create-$$.jcl"
run_job_and_wait  "/tmp/IMS-Db2-create-$$.jcl"

rm -f /tmp/IMS-Db2-*  2>/dev/null || true
rm -f /tmp/CICS-Db2-*  2>/dev/null || true
rm -f /tmp/Db2-*  2>/dev/null || true

exit 0
