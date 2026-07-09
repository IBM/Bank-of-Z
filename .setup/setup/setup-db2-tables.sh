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

# =========================
# Environment
# =========================
export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

# =========================
# Create DB2 tables
# =========================
rm -f "/tmp/IMS-Db2-*"
rm -f "/tmp/IMS-Db2-*"
rm -f "/tmp/Db2-*"

# CICS
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DB2BIND" --templateFile "$SCRIPTS_DIR/../jcl/cics/Db2-drop.j2"  --outputFile "/tmp/CICS-Db2-drop-$$.jcl"
run_job_and_wait "/tmp/CICS-Db2-drop-$$.jcl" "8"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DB2BIND" --templateFile "$SCRIPTS_DIR/../jcl/cics/Db2-create.j2"  --outputFile "/tmp/CICS-Db2-create-$$.jcl"
run_job_and_wait "/tmp/CICS-Db2-create-$$.jcl"

# IMS
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DB2BIND" --templateFile "$SCRIPTS_DIR/../jcl/ims/Db2-drop.j2"  --outputFile "/tmp/IMS-Db2-drop-$$.jcl"
run_job_and_wait "/tmp/IMS-Db2-drop-$$.jcl" "8"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DB2BIND" --templateFile "$SCRIPTS_DIR/../jcl/ims/Db2-create.j2"  --outputFile "/tmp/IMS-Db2-create-$$.jcl"
run_job_and_wait  "/tmp/IMS-Db2-create-$$.jcl"

exit $?
