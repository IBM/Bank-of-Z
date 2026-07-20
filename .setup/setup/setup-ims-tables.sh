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
export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

exec > >(while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf "${CYAN}[SETUP-IMS-TABLES]${NC} %s\n" "${line}"
done) 2>&1

# =========================
# Delele IMS tables
# =========================
set +e
drm "${APP_HLQ}.${IMS_DATASTORE}.ACCOUNT.DB" 2>/dev/null
drm "${APP_HLQ}.${IMS_DATASTORE}.ACCTYPE.DB" 2>/dev/null
drm "${APP_HLQ}.${IMS_DATASTORE}.CUSTACCS.DB" 2>/dev/null
drm "${APP_HLQ}.${IMS_DATASTORE}.CUSTOMER.DB" 2>/dev/${IMS_DATASTORE}
drm "${APP_HLQ}.${IMS_DATASTORE}.CUSTTYPE.DB" 2>/dev/null
drm "${APP_HLQ}.${IMS_DATASTORE}.HISTORY.DB" 2>/dev/null
drm "${APP_HLQ}.${IMS_DATASTORE}.TSTAT.DB" 2>/dev/null
drm "${APP_HLQ}.${IMS_DATASTORE}.TSTATTYP.DB" 2>/dev/null
drm "${APP_HLQ}.${IMS_DATASTORE}.TTYPE.DB" 2>/dev/null
set -e

# =========================
# IMS dynalloc
# =========================
rm -f "/tmp/IMS-table-*"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DYNALLOC" --templateFile "$SCRIPTS_DIR/../jcl/ims/Ims-dynalloc.j2"  --outputFile "/tmp/IMS-table-$$.jcl"
run_job_and_wait "/tmp/IMS-table-$$.jcl" 
exit $?