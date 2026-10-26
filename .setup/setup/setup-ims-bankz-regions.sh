#!/bin/env bash
set -e
# =============================================================================
# Script  :setup-ims-bankz-regions.sh
# Summary :setup-ims-bankz-regions.sh
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
    printf "${CYAN}[IMS-REGIONS]${NC} %s\n" "${line}" 2>/dev/null || true
done) 2>&1
trap 'exec >&- 2>&-; wait' EXIT

# =========================
# Environment
# =========================
export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

rm -f /tmp/IMS-* 2>/dev/null || true
rm -f /tmp/Ims-* 2>/dev/null || true

# =========================
# Stop IBM BOZ regions
# =========================
set +e
jsub "${IMS_APP_HLQ}.JOBS(STOPMPP1)"  2>/dev/null
jsub "${IMS_APP_HLQ}.JOBS(STOPMPP2)"  2>/dev/null
jsub "${IMS_APP_HLQ}.IMSJAVA.JOBS(STOPJMP)"  2>/dev/null
sleep 5
jcan P "${IMS_DATASTORE}JMP1" 2>/dev/null
jcan P "${IMS_DATASTORE}MPP1" 2>/dev/null
jcan P "${IMS_DATASTORE}MPP2" 2>/dev/null
sleep 5
set -e

# JMP
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --templateFile "$SCRIPTS_DIR/../jcl/ims/templates/jmp/dfsjvmpr.props.j2"\
    --outputFile "$IMS_JAVA_CONF_PATH"

python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=IMSJOB" --templateFile "$SCRIPTS_DIR/../jcl/ims/templates/jmp/CREWORKDS.j2"\
    --outputFile "/tmp/IMS-bankz-reg-works-$$.jcl"
run_job_and_wait "/tmp/IMS-bankz-reg-works-$$.jcl" "4"

python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "region_num=3" --templateFile "$SCRIPTS_DIR/../jcl/ims/templates/jmp/DFSJMP.j2"  --outputFile "/tmp/IMS-bankz-reg-jmp-$$.txt"
cp "/tmp/IMS-bankz-reg-jmp-$$.txt" "//'${IMS_APP_HLQ}.PROCLIB(DFSJMP)'"

python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "region_num=3" --templateFile "$SCRIPTS_DIR/../jcl/ims/templates/jmp/SIMLINK.j2"\
    --outputFile "/tmp/IMS-bankz-reg-simlink-$$.txt"
cp "/tmp/IMS-bankz-reg-simlink-$$.txt" "//'${IMS_APP_HLQ}.IMSJAVA.JOBS(SIMLINK)'"


MEMBER_EXISTS=False
set +e
if head "//'${IMS_APP_HLQ}.IMSJAVA.JOBS(${IMS_DFS_IMS_SSID}JMP1)'" > /dev/null 2>&1; then
MEMBER_EXISTS=True
fi
set -e
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=IMDOJMP" --extraVar "member_exists=${MEMBER_EXISTS}"  --extraVar "region_num=3" --templateFile "$SCRIPTS_DIR/../jcl/ims/templates/jmp/IMDOJMP.j2"  --outputFile "/tmp/IMS-bankz-reg-dojmp-$$.txt"
run_job_and_wait "/tmp/IMS-bankz-reg-dojmp-$$.txt" "4"
cp "//'${IMS_APP_HLQ}.IMSJAVA.JOBS(${IMS_DATASTORE}JMP1)'" "//'${IMS_APP_HLQ}.IMSJAVA.JOBS(STARTJMP)'"

python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
     --extraVar "jobname=DFSJVMEV" --extraVar "member_exists=${MEMBER_EXISTS}"  --extraVar "region_num=3" --templateFile "$SCRIPTS_DIR/../jcl/ims/templates/jmp/CREDFSJVMEV.j2"  --outputFile "/tmp/IMS-bankz-reg-jvmev-$$.txt"
run_job_and_wait "/tmp/IMS-bankz-reg-jvmev-$$.txt" "4"
cp "//'${IMS_APP_HLQ}.PROCLIB(DFSJVMEV)'" "//'${IMS_APP_HLQ}.IMSJAVA.JOBS(DFSJVMEV)'"

python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=DFSJVMAP"  --extraVar "member_exists=${MEMBER_EXISTS}"  --extraVar "region_num=3" --templateFile "$SCRIPTS_DIR/../jcl/ims/templates/jmp/CREDFSJVMAP.j2"  --outputFile "/tmp/IMS-bankz-reg-jvmap-$$.txt"
run_job_and_wait "/tmp/IMS-bankz-reg-jvmap-$$.txt" "4"
cp "//'${IMS_APP_HLQ}.PROCLIB(DFSJVMAP)'" "//'${IMS_APP_HLQ}.IMSJAVA.JOBS(DFSJVMAP)'"

python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=CHEKSPOC" --extraVar "member_exists=${MEMBER_EXISTS}"  --extraVar "region_num=3" --templateFile "$SCRIPTS_DIR/../jcl/ims/templates/jmp/VERIFYSPOC.j2"  --outputFile "/tmp/IMS-bankz-reg-verif-$$.txt"
run_job_and_wait "/tmp/IMS-bankz-reg-verif-$$.txt" "4"

python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "region_num=3" --templateFile "$SCRIPTS_DIR/../jcl/ims/templates/jmp/STOPJMP.j2"\
    --outputFile "/tmp/IMS-bankz-reg-stopjmp-$$.txt"
cp "/tmp/IMS-bankz-reg-stopjmp-$$.txt" "//'${IMS_APP_HLQ}.IMSJAVA.JOBS(STOPJMP)'"

python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "member_exists=${MEMBER_EXISTS}"  --extraVar "region_num=3" --templateFile "$SCRIPTS_DIR/../jcl/ims/templates/jmp/STARTJMP.j2"  --outputFile "/tmp/IMS-bankz-reg-stajmp-$$.txt"
run_job_and_wait "/tmp/IMS-bankz-reg-stajmp-$$.txt" "4"


# MPP
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=IMSLOAD" --extraVar "region_num=1" --templateFile "$SCRIPTS_DIR/../jcl/ims/templates/mpp/CRE_MPP_EXEC.j2"\
    --outputFile "/tmp/IMS-bankz-reg-mpr1-$$.jcl"
run_job_and_wait "/tmp/IMS-bankz-reg-mpr1-$$.jcl"

python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "jobname=IMSLOAD" --extraVar "region_num=2" --templateFile "$SCRIPTS_DIR/../jcl/ims/templates/mpp/CRE_MPP_EXEC.j2"\
    --outputFile "/tmp/IMS-bankz-reg-mpr2-$$.jcl"
run_job_and_wait "/tmp/IMS-bankz-reg-mpr2-$$.jcl"


python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "region_num=1" --templateFile "$SCRIPTS_DIR/../jcl/ims/templates/mpp/DFSMPR1.j2"  --outputFile "/tmp/IMS-bankz-reg-mpr1-$$.txt"
cp "/tmp/IMS-bankz-reg-mpr1-$$.txt" "//'${IMS_APP_HLQ}.PROCLIB(DFSMPR1)'"

python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --extraVar "region_num=1" --templateFile "$SCRIPTS_DIR/../jcl/ims/templates/mpp/DFSMPR2.j2"  --outputFile "/tmp/IMS-bankz-reg-mpr2-$$.txt"
cp "/tmp/IMS-bankz-reg-mpr2-$$.txt" "//'${IMS_APP_HLQ}.PROCLIB(DFSMPR2)'"

python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
     --extraVar "region_num=1" --templateFile "$SCRIPTS_DIR/../jcl/ims/templates/mpp/STOPMPP.j2"  --outputFile "/tmp/IMS-bankz-reg-stop1-$$.txt"
cp "/tmp/IMS-bankz-reg-stop1-$$.txt" "//'${IMS_APP_HLQ}.JOBS(STOPMPP1)'"

python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
     --extraVar "region_num=2" --templateFile "$SCRIPTS_DIR/../jcl/ims/templates/mpp/STOPMPP.j2"  --outputFile "/tmp/IMS-bankz-reg-stop2-$$.txt"
cp "/tmp/IMS-bankz-reg-stop2-$$.txt" "//'${IMS_APP_HLQ}.JOBS(STOPMPP2)'"

echo "IEFBR14" > "/tmp/IMS-bankz-dfsintdc.txt"
cp "/tmp/IMS-bankz-dfsintdc.txt" "//'${IMS_APP_HLQ}.PROCLIB(DFSINTDC)'"

# =========================
# Start IBM BOZ regions
# =========================
jsub "${IMS_APP_HLQ}.JOBS(${IMS_DATASTORE}MPP2)"  2>/dev/null
sleep 5
jsub "${IMS_APP_HLQ}.JOBS(${IMS_DATASTORE}MPP1)"  2>/dev/null
sleep 5
jsub "${IMS_APP_HLQ}.IMSJAVA.JOBS(STARTJMP)"  2>/dev/null
sleep 5

rm -f /tmp/IMS-* 2>/dev/null || true
rm -f /tmp/Ims-* 2>/dev/null || true

exit 0
