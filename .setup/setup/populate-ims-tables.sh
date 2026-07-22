#!/bin/env bash
set -e
# =============================================================================
# Script  : populate-ims-tables.sh
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
    printf "${CYAN}[POPULATE-IMS-TABLES]${NC} %s\n" "${line}"
done) 2>&1

# =========================
# Environment
# =========================
export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

# =========================
# Populate IMS tables
# =========================
for file in ${SANDBOX_DIR}/${REPO_NAME}/src/base/ims/LoadData/*.data; do
    name=$(basename $file .data)
    set +e
    drm ${IMS_APP_HLQ}.${name}.INPUT 2>/dev/null
    set -e
    dtouch -tbasic -s24000 -rfb -l200 ${IMS_APP_HLQ}.${name}.INPUT
    cp "$file" "//'${IMS_APP_HLQ}.${name}.INPUT'"
done

# LOAD
rm -f "/tmp/IMS-load-*"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=LOADACCT" --templateFile "$SCRIPTS_DIR/../jcl/ims/Ims-load-acct.j2"  --outputFile "/tmp/Ims-load-acct-$$.jcl"
run_job_and_wait "/tmp/Ims-load-acct-$$.jcl"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=LOADCUST" --templateFile "$SCRIPTS_DIR/../jcl/ims/Ims-load-cust.j2"  --outputFile "/tmp/Ims-load-cust-$$.jcl"
run_job_and_wait "/tmp/Ims-load-cust-$$.jcl"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=LOADCUSA" --templateFile "$SCRIPTS_DIR/../jcl/ims/Ims-load-cusa.j2"  --outputFile "/tmp/Ims-load-cusa-$$.jcl"
run_job_and_wait "/tmp/Ims-load-cusa-$$.jcl"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=LOADHIST" --templateFile "$SCRIPTS_DIR/../jcl/ims/Ims-load-hist.j2"  --outputFile "/tmp/Ims-load-hist-$$.jcl"
run_job_and_wait "/tmp/Ims-load-hist-$$.jcl"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=LOADTSTA" --templateFile "$SCRIPTS_DIR/../jcl/ims/Ims-load-tsta.j2"  --outputFile "/tmp/Ims-load-tsta-$$.jcl"
run_job_and_wait "/tmp/Ims-load-tsta-$$.jcl"


# RECON
rm -f "/tmp/IMS-recon-*"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=IMSDREC" --templateFile "$SCRIPTS_DIR/../jcl/ims/Ims-deloldrecon.j2"  --outputFile "/tmp/Ims-recon-del-$$.jcl"
run_job_and_wait "/tmp/Ims-recon-del-$$.jcl" "12"

python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=IMSRECON" --templateFile "$SCRIPTS_DIR/../jcl/ims/Ims-recon.j2"  --outputFile "/tmp/Ims-recon-cre-$$.jcl"
run_job_and_wait "/tmp/Ims-recon-cre-$$.jcl"

exit $?