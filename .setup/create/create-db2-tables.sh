#!/bin/env bash
set -eu
# =============================================================================
# Script  : create-db2-tables.sh
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
submit_jcl "$SCRIPTS_DIR/../jcl/Db2-drop.jcl"
sleep 3
submit_jcl "$SCRIPTS_DIR/../jcl/Db2-create.jcl"
sleep 3
submit_jcl "$SCRIPTS_DIR/../jcl/Db2-bind.jcl"
sleep 3
submit_jcl "$SCRIPTS_DIR/../jcl/Db2-insert.jcl"
sleep 3
