#!/bin/env bash
set -e
# =============================================================================
# Script  : setup-ims-tables.sh
# Summary : IMS table creation
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
# Delele IMS tables
# =========================
set +e
drm "BANKZ.IMS2.ACCOUNT.DB" 2>/dev/null
drm "BANKZ.IMS2.ACCTYPE.DB" 2>/dev/null
drm "BANKZ.IMS2.CUSTACCS.DB" 2>/dev/null
drm "BANKZ.IMS2.CUSTOMER.DB" 2>/dev/null
drm "BANKZ.IMS2.CUSTTYPE.DB" 2>/dev/null
drm "BANKZ.IMS2.HISTORY.DB" 2>/dev/null
drm "BANKZ.IMS2.TSTAT.DB" 2>/dev/null
drm "BANKZ.IMS2.TSTATTYP.DB" 2>/dev/null
drm "BANKZ.IMS2.TTYPE.DB" 2>/dev/null
set -e

# =========================
# IMS dynalloc
# =========================
rm -f "/tmp/IMS-table-*"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DYNALLOC" --templateFile "$SCRIPTS_DIR/../jcl/ims/Ims-dynalloc.j2"  --outputFile "/tmp/IMS-table-$$.jcl"
run_job_and_wait "/tmp/IMS-table-$$.jcl" 
exit $?