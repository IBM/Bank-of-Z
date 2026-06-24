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
export ZOAU_HOME=$(get_section_value 'zoau' 'zoau_home')

export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

# =========================
# Create DB2 tables
# =========================
rm -f "/tmp/IMS-Db2-*"
rm -f "/tmp/Db2-*"
run_job_and_wait "$SCRIPTS_DIR/../jcl/cics/Db2-drop.jcl" "8"
run_job_and_wait "$SCRIPTS_DIR/../jcl/cics/Db2-create.jcl"
# IMS DB2 setup
jsub -f "$SCRIPTS_DIR/../jcl/ims/Db2-drop.jcl"
jsub -f "$SCRIPTS_DIR/../jcl/ims/Db2-create.jcl"
exit $?
