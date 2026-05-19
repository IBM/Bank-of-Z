#!/bin/env bash
set -e
# =============================================================================
# Script  : setup-db2-tables.sh
# Summary : DB2 table creation
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# - Drops existing tables
# - Creates tables
# - Binds packages
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
# Create DB2 tables
# =========================
run_job_and_wait "$SCRIPTS_DIR/../jcl/Db2-drop.jcl" "8"&
# Wait for deployment to complete (ZOAU ISSUE)
wait $PID
run_job_and_wait "$SCRIPTS_DIR/../jcl/Db2-create.jcl"&
# Wait for deployment to complete (ZOAU ISSUE)
wait $PID
run_job_and_wait "$SCRIPTS_DIR/../jcl/Db2-bind.jcl"&
# Wait for deployment to complete (ZOAU ISSUE)
wait $PID
run_job_and_wait "$SCRIPTS_DIR/../jcl/Db2-insert.jcl"&
# Wait for deployment to complete (ZOAU ISSUE)
wait $PID