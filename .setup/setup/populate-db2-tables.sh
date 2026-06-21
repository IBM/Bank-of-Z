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

# =========================
# Environment
# =========================
export ZOAU_HOME=${ZOAU_HOME:-$(get_section_value 'zoau' 'zoau_home')}

export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

# =========================
# Populate DB2 tables
# =========================
rm -f "/tmp/IMS-Db2-*"
rm -f "/tmp/Db2-*"
run_job_and_wait "$SCRIPTS_DIR/../jcl/cics/Db2-bind.jcl"
run_job_and_wait "$SCRIPTS_DIR/../jcl/cics/Db2-insert.jcl"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DB2BIND" --templateFile "$SCRIPTS_DIR/../jcl/ims/Db2-bind.j2"  --outputFile "/tmp/IMS-Db2-bind-$$.jcl"
run_job_and_wait "/tmp/IMS-Db2-bind-$$.jcl"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DB2BINST" --templateFile "$SCRIPTS_DIR/../jcl/ims/Db2-insert.j2"  --outputFile "/tmp/IMS-Db2-insert-$$.jcl"
run_job_and_wait "/tmp/IMS-Db2-insert-$$.jcl"

exit $?