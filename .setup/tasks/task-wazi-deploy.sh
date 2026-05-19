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
export PACKAGE_URL="$(ls "$DBB_LOG_FOLDER/${APP_BASE_NAME}"*.tar 2>/dev/null || true)"
export INSTALL_APP="${1:-""}"
export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"
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
        a2e -f IBM-1047 -t ISO8859-1 "$outputDir/wazideploy-generate.console.log"
        a2e -f IBM-1047 -t ISO8859-1 "$outputDir/wazideploy-deploy.console.log"
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

if [ -f "$TYPES_MAPPING_FILES" ]; then
    cp "$TYPES_MAPPING_FILES" "$ZDEPLOY_FOLDER/deployment-configuration/global/types_pattern_mapping.yml"
fi

source "${PYENV_ACTIVATE_PATH}"

# =========================
# Generate deployment plan
# =========================
print_info "${CYAN}[WAZIDEPLOY]${NC} Starting wazideploy-generate"

CMD="wazideploy-generate \
 --deploymentMethod $DEPLOYMENT_METHOD \
 --deploymentPlan $outputDir/deploymentPlan.yaml \
 --deploymentPlanReport $outputDir/deploymentPlanReport.html \
 --packageInputFile $PACKAGE_URL"

print_info "${CYAN}[WAZIDEPLOY]${NC} Executing command:"
print_info "${CYAN}[WAZIDEPLOY]${NC} \t$CMD"

${CMD} 2>&1 | tee "${outputDir}/wazideploy-generate.console.log" | while IFS= read -r line
do
    print_info "${CYAN}[WAZIDEPLOY]${NC} [GENERATE] $line"
done

# =========================
# Deploy
# =========================
print_info "${CYAN}[WAZIDEPLOY]${NC} Starting wazideploy-deploy"

if [ "$INSTALL_APP" = "true" ]; then
    TAGS="-pt deploy"
else
    TAGS=""
fi

CICS_CREDS=""
if [ -n "${CICS_USER:-}" ]; then
    CICS_CREDS="$CICS_CREDS -e default_cics_user=$CICS_USER"
fi
if [ -n "${CICS_PASSWORD:-}" ]; then
    CICS_CREDS="$CICS_CREDS -e default_cics_password=$CICS_PASSWORD"
fi

rm -rf "${DEPLOY_LOG_FOLDER}/work"

CMD="wazideploy-deploy \
 --workingFolder ${DEPLOY_LOG_FOLDER}/work \
 --deploymentPlan $outputDir/deploymentPlan.yaml \
 --envFile $DEPLOY_ENV_FILE \
 -e application=$APP_BASE_NAME \
 -e hlq=$TARGET_HLQ \
 -e deploy_cfg_home=$ZDEPLOY_FOLDER \
 $CICS_CREDS \
 --packageInputFile $PACKAGE_URL \
 --evidencesFileName $EVIDENCE_FILE $TAGS"

rm -f message.log

print_info "${CYAN}[WAZIDEPLOY]${NC} Executing command:"
print_info "${CYAN}[WAZIDEPLOY]${NC} \t$CMD"

${CMD} | tee "${outputDir}/wazideploy-deploy.console.log" | while IFS= read -r line
do
    print_info "${CYAN}[WAZIDEPLOY]${NC} [DEPLOY] $line"
done

rc=$(cat "$tmp_rc")
rm -f "$tmp_rc"

if [ "$rc" -ne 0 ]; then
    print_error "${RED}[WAZIDEPLOY]${NC} wazideploy-deploy failed"
    exit "$rc"
fi

print_info "${CYAN}[WAZIDEPLOY]${NC} Deployment process completed successfully"

# =========================
# Deploy z/OS Connect artifacts
# =========================
print_info "${CYAN}[WAZIDEPLOY]${NC} Deploying z/OS Connect artifacts"

# Find the extraction directory from wazi-deploy work folder
EXTRACT_DIR="$SCRIPTS_DIR/work"

# Check if z/OS Connect artifacts exist in the extracted package
if [ -d "$EXTRACT_DIR" ]; then
    # Check for WAR files or z/OS Connect config
    if [ -d "$EXTRACT_DIR/war" ] || [ -d "$EXTRACT_DIR/zosconnect-config" ]; then
        ZOSCONNECT_DEPLOY_SCRIPT="$SCRIPTS_DIR/../deploy/zosconnect-deploy.sh"
        
        if [ -f "$ZOSCONNECT_DEPLOY_SCRIPT" ]; then
            print_info "${CYAN}[WAZIDEPLOY]${NC} Found z/OS Connect artifacts in package"
            print_info "${CYAN}[WAZIDEPLOY]${NC} Calling z/OS Connect deployment script"
            
            # Get z/OS Connect server directory from config.yaml
            ZOSCONNECT_SERVER_DIR=$(get_section_value 'zosconnect' 'server_dir')
            
            bash "$ZOSCONNECT_DEPLOY_SCRIPT" "$EXTRACT_DIR" "$ZOSCONNECT_SERVER_DIR"
            
            if [ $? -eq 0 ]; then
                print_success "${CYAN}[WAZIDEPLOY]${NC} z/OS Connect deployment completed"
            else
                print_error "${CYAN}[WAZIDEPLOY]${NC} z/OS Connect deployment failed"
                exit 1
            fi
        else
            print_warning "${CYAN}[WAZIDEPLOY]${NC} z/OS Connect deployment script not found at: $ZOSCONNECT_DEPLOY_SCRIPT"
        fi
    else
        print_info "${CYAN}[WAZIDEPLOY]${NC} No z/OS Connect artifacts found in package - skipping deployment"
        print_info "${CYAN}[WAZIDEPLOY]${NC} (Checked for: $EXTRACT_DIR/war and $EXTRACT_DIR/zosconnect-config)"
    fi
else
    print_warning "${CYAN}[WAZIDEPLOY]${NC} Extraction directory not found at: $EXTRACT_DIR"
fi

# =========================
# Cleanup
# =========================
print_info "${CYAN}[WAZIDEPLOY]${NC} Cleaning up package file"
rm -f "$PACKAGE_URL"

print_success "${CYAN}[WAZIDEPLOY]${NC} Wazi Deploy process completed successfully"
