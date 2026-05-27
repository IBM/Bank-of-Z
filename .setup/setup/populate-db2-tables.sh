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
run_job_and_wait "$SCRIPTS_DIR/../jcl/Db2-bind.jcl"
if [ $? -ne 0 ];then
  exit 1
fi
run_job_and_wait "$SCRIPTS_DIR/../jcl/Db2-insert.jcl"
exit $?