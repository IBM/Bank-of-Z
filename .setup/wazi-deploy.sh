#!/bin/env bash
set -eu
###############################################################################
# Script: Wazi Deploy Generate + Deploy
#
# Description:
# - Initializes execution environment
# - Loads Wazi Deploy configuration from env.sh
# - Creates timestamped output and evidence directories
# - Executes wazideploy-generate
# - Executes wazideploy-deploy
# - Streams logs in real time using tee
# - Preserves correct return codes despite pipe usage
# - Provides colored and structured logging (build.sh style)
#
# Requirements:
# - POSIX sh compatible (z/OS USS safe)
# - No bash-specific features
#
###############################################################################

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPTS_DIR/config.yaml"
chtag -t -c ISO8859-1 "$CONFIG_FILE"

LIB_DIR="$SCRIPTS_DIR/lib"
source "$LIB_DIR/utilities.sh"
source "$LIB_DIR/colors.sh"

# =========================
# Environment
# =========================
export APP_BASE_NAME=$(get_section_value 'app' 'base_name')
export APP_ZOS_VERSION=$(get_section_value 'app' 'zos_version')
export SANDBOX_DIR="${2:-$(get_section_value 'sandbox' 'path')}"
export PACKAGE_URL="${1:-$(ls "$SANDBOX_DIR/zDevOps/applications/${APP_BASE_NAME}/application/src/logs/${APP_BASE_NAME}"*.tar 2>/dev/null || true)}"
export INSTALL_APP="${3:-""}"
export PYENV_ACTIVATE_PATH="${PYENV_ACTIVATE_PATH:-$(get_section_value 'wazideploy' 'wazideploy_home')/bin/activate}"
export DEPLOYMENT_METHOD="${DEPLOYMENT_METHOD:-$(get_section_value 'wazideploy' 'deployment_method')}"
export DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-$(get_section_value 'wazideploy' 'deployment_envfile')}"
export ZDEPLOY_FOLDER="${ZDEPLOY_FOLDER:-$(get_section_value 'wazideploy' 'zdeploy_folder')}"
export TARGET_HLQ="${TARGET_HLQ:-"$APP_BASE_NAME.$APP_ZOS_VERSION"}"
export ZOAU_HOME="${ZOAU_HOME:-$(get_section_value 'zoau' 'zoau_home')}"

export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

# =========================
# Output directories
# =========================
timestamp=$(date +%F_%H-%M-%S)
outputDir="${SCRIPTS_DIR}/logs"
evidenceDir="${outputDir}/evidences"
LOG_TAR="${SCRIPTS_DIR}/wazi-deploy-log.tar"
EVIDENCE_FILE="${evidenceDir}/evidence.yaml"

mkdir -p "$outputDir" "$evidenceDir"

finalize_results() {
    RC=$?

    mkdir -p "$outputDir" "$evidenceDir"
    cd $SCRIPTS_DIR

    if ls logs/*.log >/dev/null 2>&1; then
        tar cf "$LOG_TAR" "logs" 2>/dev/null || true
    else
        echo "No Wazi Deploy logs found" > "$outputDir/wazi-deploy-console.log"
        tar cf "$LOG_TAR" "logs" 2>/dev/null || true
    fi

    print_result "${GREEN}[WAZIDEPLOY][LOG-PATH]${NC} $LOG_TAR"

    exit "$RC"
}

trap finalize_results EXIT

rm -rf "$outputDir"
mkdir -p "$outputDir" "$evidenceDir"

print_info "${CYAN}[WAZIDEPLOY] ${NC} Output directory  : $outputDir"
print_info "${CYAN}[WAZIDEPLOY] ${NC} Evidence directory: $evidenceDir"

if [[ -z "$PACKAGE_URL" || "$PACKAGE_URL" == "NONE" ]]; then
    print_info "${CYAN}[WAZIDEPLOY] ${NC} No package to deploy"
    exit 0
fi

if [[ "$PACKAGE_URL" != /* ]]; then
    PACKAGE_URL="${SANDBOX_DIR}/zDevOps/applications/${APP_BASE_NAME}/application/packages/${PACKAGE_URL}"
fi

source "${PYENV_ACTIVATE_PATH}"

###############################################################################
# GENERATE
###############################################################################

print_info "${CYAN}[WAZIDEPLOY] ${NC} Starting wazideploy-generate"

CMD="wazideploy-generate \
 --deploymentMethod $DEPLOYMENT_METHOD \
 --deploymentPlan $outputDir/deploymentPlan.yaml \
 --deploymentPlanReport $outputDir/deploymentPlanReport.html \
 --packageInputFile $PACKAGE_URL"

print_info "${CYAN}[WAZIDEPLOY] ${NC} Executing command:"
print_info "${CYAN}[WAZIDEPLOY] ${NC} \t$CMD"

tmp_rc="/tmp/cmd_rc_gen_$$"

(
  ${CMD}
  echo $? > "$tmp_rc"
) 2>&1 | tee "${outputDir}/wazideploy-generate.log" | while IFS= read -r line
do
    print_info "${CYAN}[WAZIDEPLOY] ${NC} [GENERATE] $line"
done

rc=$(cat "$tmp_rc")
rm -f "$tmp_rc"

if [ "$rc" -ne 0 ]; then
    print_error "${CYAN}[WAZIDEPLOY] ${NC} wazideploy-generate failed"
    exit "$rc"
fi

print_info "${CYAN}[WAZIDEPLOY] ${NC} wazideploy-generate completed successfully"

###############################################################################
# DEPLOY
###############################################################################

print_info "${CYAN}[WAZIDEPLOY] ${NC} Starting wazideploy-deploy"

if [ "$INSTALL_APP" = "true" ]; then
  TAGS="-pt deploy"
else
  TAGS=""
fi

CICS_CREDS=""
if [ -n "${CICS_CMCI_USER:-}" ]; then
  CICS_CREDS="$CICS_CREDS -e default_cics_user=$CICS_CMCI_USER"
fi
if [ -n "${CICS_CMCI_PASSWORD:-}" ]; then
  CICS_CREDS="$CICS_CREDS -e default_cics_password=$CICS_CMCI_PASSWORD"
fi

rm -rf "./work"
CMD="wazideploy-deploy \
 --workingFolder ./work \
 --deploymentPlan $outputDir/deploymentPlan.yaml \
 --envFile $DEPLOY_ENV_FILE \
 -e application=$APP_BASE_NAME \
 -e hlq=$TARGET_HLQ \
 -e deploy_cfg_home=$ZDEPLOY_FOLDER \
 $CICS_CREDS \
 --packageInputFile $PACKAGE_URL \
 --evidencesFileName $EVIDENCE_FILE $TAGS"

rm -f message.log

print_info "${CYAN}[WAZIDEPLOY] ${NC} Executing command:"
print_info "${CYAN}[WAZIDEPLOY] ${NC} \t$CMD"

tmp_rc="/tmp/cmd_rc_deploy_$$"

(
  ${CMD}
  echo $? > "$tmp_rc"
) 2>&1 | tee "${outputDir}/wazideploy-deploy.log" | while IFS= read -r line
do
    print_info "${CYAN}[WAZIDEPLOY] ${NC} [DEPLOY] $line"
done

rc=$(cat "$tmp_rc")
rm -f "$tmp_rc"

if [ "$rc" -ne 0 ]; then
    print_error "${CYAN}[WAZIDEPLOY] ${NC} Deployment process failed"
    exit "$rc"
fi

print_info "${CYAN}[WAZIDEPLOY] ${NC} Deployment process completed successfully"