#!/bin/env bash
set -eu
# =============================================================================
# Script  : task-wazi-deploy.sh
# Summary : Wazi Deploy Generate + Deploy
#
# - Initializes execution environment
# - Loads Wazi Deploy configuration from setenv.sh
# - Creates timestamped output and evidence directories
# - Executes wazideploy-generate
# - Executes wazideploy-deploy
# - Streams logs in real time using tee
# - Preserves correct return codes despite pipe usage
# - Always produces log tar result, even on failure
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"
cd $SCRIPTS_DIR
# =========================
# Environment
# =========================
export PYENV_ACTIVATE_PATH="${PYENV_ACTIVATE_PATH:-$(get_section_value 'wazideploy' 'wazideploy_home')/bin/activate}"
export DEPLOYMENT_METHOD="${DEPLOYMENT_METHOD:-$(get_section_value 'wazideploy' 'deployment_method')}"
export DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-$(get_section_value 'wazideploy' 'deployment_envfile')}"
export ZDEPLOY_FOLDER="${ZDEPLOY_FOLDER:-$(get_section_value 'wazideploy' 'zdeploy_dir')}"
export TARGET_HLQ="${TARGET_HLQ:-"$APP_BASE_NAME.$APP_ZOS_VERSION"}"
export ZOAU_HOME="${ZOAU_HOME:-$(get_section_value 'zoau' 'zoau_home')}"
export DBB_LOG_FOLDER="${DBB_LOG_FOLDER:-$(get_section_value 'dbb' 'dbb_log_dir')}"
export DEPLOY_LOG_FOLDER="${DEPLOY_LOG_FOLDER:-$(get_section_value 'wazideploy' 'deploy_log_dir')}"
export TYPES_MAPPING_FILES="${TYPES_MAPPING_FILES:-$(get_section_value 'wazideploy' 'types_pattern_mapping')}"
export ZOS_CONNECT_SERVER_FOLDER="${ZOS_CONNECT_SERVER_FOLDER:-$(get_section_value 'zosconnect' 'server_dir')/servers/bankzServer}"
export PACKAGE_URL="$(ls "$DBB_LOG_FOLDER/${APP_BASE_NAME}"*.tar 2>/dev/null || true)"
export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"
export PYTHONUNBUFFERED=1 
# =========================
# Output directories
# =========================
timestamp=$(date +%F_%H-%M-%S)
outputDir="${DEPLOY_LOG_FOLDER}"
evidenceDir="${outputDir}/evidences"
LOG_TAR="${outputDir}/wazi-deploy-log.tar"
EVIDENCE_FILE="${evidenceDir}/evidence.yaml"

rm -rf "$outputDir" "$evidenceDir"
mkdir -p "$outputDir" "$evidenceDir"

# =========================
# Finalize: always publish log tar on exit
# =========================
finalize_results() {
    RC=$?

    mkdir -p "$outputDir" "$evidenceDir"
    cd "$outputDir"

    if ls wazideploy*.log >/dev/null 2>&1; then
        chtag -tc IBM-1047 wazideploy*.log
        # Convert BankZ logs if they exist
        [ -f "$outputDir/wazideploy-generate-bankz.console.log" ] && \
            a2e -f IBM-1047 -t ISO8859-1 "$outputDir/wazideploy-generate-bankz.console.log"
        [ -f "$outputDir/wazideploy-deploy-bankz.console.log" ] && \
            a2e -f IBM-1047 -t ISO8859-1 "$outputDir/wazideploy-deploy-bankz.console.log"
        tar cf "$LOG_TAR" "logs" 2>/dev/null || true
    else
        echo "No Wazi Deploy logs found" > "$outputDir/wazi-deploy-console.log"
        tar cf "$LOG_TAR" "logs" 2>/dev/null || true
    fi

    print_result "${GREEN}[WAZIDEPLOY][LOG-PATH]${NC} $LOG_TAR"


    if [ $RC -eq 0 ]; then
        print_success "${GREEN}[DBB-BUILD]${NC} Process completed"
    else
        print_error "${RED}[DBB-BUILD]${NC} Process failed"
    fi

    exit "$RC"
}

trap finalize_results EXIT

rm -rf "$outputDir"
mkdir -p "$outputDir" "$evidenceDir"

print_info "${CYAN}[WAZIDEPLOY]${NC} Output directory  : $outputDir"
print_info "${CYAN}[WAZIDEPLOY]${NC} Evidence directory: $evidenceDir"

# =========================
# Skip if no package
# =========================
if [[ -z "$PACKAGE_URL" || "$PACKAGE_URL" == "NONE" ]]; then
    print_info "${CYAN}[WAZIDEPLOY]${NC} No package to deploy"
    exit 0
fi

if [[ "$PACKAGE_URL" != /* ]]; then
    PACKAGE_URL="${SANDBOX_DIR}/zDevOps/applications/${APP_BASE_NAME}/application/packages/${PACKAGE_URL}"
fi

# Copy types_pattern_mapping.yml for BankZ artifact deployment
if [ -f "$TYPES_MAPPING_FILES" ]; then
    TARGET_TYPES_DIR="$ZDEPLOY_FOLDER/deployment-configuration/global"
    
    # Create target directory if it doesn't exist
    if [ ! -d "$TARGET_TYPES_DIR" ]; then
        print_info "${CYAN}[WAZIDEPLOY]${NC} Creating target directory: $TARGET_TYPES_DIR"
        mkdir -p "$TARGET_TYPES_DIR"
    fi
    
    # Copy the types mapping file
    if [ -d "$TARGET_TYPES_DIR" ]; then
        cp "$TYPES_MAPPING_FILES" "$TARGET_TYPES_DIR/types_pattern_mapping.yml"
        print_info "${CYAN}[WAZIDEPLOY]${NC} Copied types_pattern_mapping.yml to $TARGET_TYPES_DIR"
    else
        print_error "${CYAN}[WAZIDEPLOY]${NC} Failed to create target directory: $TARGET_TYPES_DIR"
        print_error "${CYAN}[WAZIDEPLOY]${NC} BankZ artifact deployment may fail"
    fi
else
    print_warning "${CYAN}[WAZIDEPLOY]${NC} types_pattern_mapping.yml not found at: $TYPES_MAPPING_FILES"
    print_warning "${CYAN}[WAZIDEPLOY]${NC} BankZ artifact deployment may use default mappings"
fi

source "${PYENV_ACTIVATE_PATH}"

# =========================
# BankZ Deployment
# =========================
print_info "${CYAN}[WAZIDEPLOY]${NC} ========================================="
print_info "${CYAN}[WAZIDEPLOY]${NC} BankZ Deployment"
print_info "${CYAN}[WAZIDEPLOY]${NC} ========================================="

print_info "${CYAN}[WAZIDEPLOY]${NC} Starting wazideploy-generate for BankZ"

CMD="wazideploy-generate \
 --deploymentMethod $DEPLOYMENT_METHOD \
 --deploymentPlan $outputDir/deploymentPlan-bankz.yaml \
 --deploymentPlanReport $outputDir/deploymentPlanReport-bankz.html \
 --packageInputFile $PACKAGE_URL"

print_info "${CYAN}[WAZIDEPLOY]${NC} Executing command:"
print_info "${CYAN}[WAZIDEPLOY]${NC} \t$CMD"

${CMD} 2>&1 | tee "${outputDir}/wazideploy-generate-bankz.console.log" | while IFS= read -r line
do
    print_info "${CYAN}[WAZIDEPLOY]${NC} [GENERATE-BANKZ $line"
done

print_info "${CYAN}[WAZIDEPLOY]${NC} Starting wazideploy-deploy for BankZ"

CICS_CREDS=""
if [ -n "${CICS_USER:-}" ]; then
    CICS_CREDS="$CICS_CREDS -e default_cics_user=$CICS_USER"
fi
if [ -n "${CICS_PASSWORD:-}" ]; then
    CICS_CREDS="$CICS_CREDS -e default_cics_password=$CICS_PASSWORD"
fi

rm -rf "${DEPLOY_LOG_FOLDER}/work-bankz"

CMD="wazideploy-deploy \
 --workingFolder ${DEPLOY_LOG_FOLDER}/work-bankz \
 --deploymentPlan $outputDir/deploymentPlan-bankz.yaml \
 --envFile $DEPLOY_ENV_FILE \
 -e script_dir=$SCRIPTS_DIR \
 -e application=$APP_BASE_NAME \
 -e hlq=$TARGET_HLQ \
 -e deploy_cfg_home=$ZDEPLOY_FOLDER \
 -e zos_connect_root=$ZOS_CONNECT_SERVER_FOLDER \
 $CICS_CREDS \
 --packageInputFile $PACKAGE_URL \
 --evidencesFileName ${evidenceDir}/evidence-bankz.yaml $@"

rm -f message.log

print_info "${CYAN}[WAZIDEPLOY]${NC} Executing command:"
print_info "${CYAN}[WAZIDEPLOY]${NC} \t$CMD"

${CMD} 2>&1 | tee "${outputDir}/wazideploy-deploy-bankz.console.log" | while IFS= read -r line
do
    print_info "${CYAN}[WAZIDEPLOY]${NC} [DEPLOY-BANKZ] $line"
done

RC=${PIPESTATUS[0]}

if [ $RC -ne 0 ]; then
    print_error "${CYAN}[WAZIDEPLOY]${NC} deployment failed with RC=$RC"
    exit $RC
fi

print_success "${CYAN}[WAZIDEPLOY]${NC} deployment completed successfully"
print_success "${CYAN}[WAZIDEPLOY]${NC} BankZ deployment completed successfully"

# =========================
# Cleanup
# =========================
print_info "${CYAN}[WAZIDEPLOY]${NC} Cleaning up package file"
mv -f "$PACKAGE_URL" "$PACKAGE_URL.deployed"

print_success "${CYAN}[WAZIDEPLOY]${NC} Wazi Deploy process completed successfully"
