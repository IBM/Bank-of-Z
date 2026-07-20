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

exec > >(while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf "${CYAN}[WAZIDEPLOY]${NC} %s\n" "${line}"
done) 2>&1

cd $SCRIPTS_DIR
# =========================
# Environment
# =========================

export TARGET_HLQ="${TARGET_HLQ:-"$APP_HLQ.$APP_ZOS_VERSION"}"
export PACKAGE_URL="$(ls "$DBB_LOG_FOLDER/BANKZ-"*.tar 2>/dev/null || true)"
export PATH="$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"
export DEPLOY_TEMPLATES_PATH="$SCRIPTS_DIR/../deploy"
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

    print_result "[LOG-PATH] $LOG_TAR"


    if [ $RC -eq 0 ]; then
        print_success "Process completed"
    else
        print_error "Process failed"
    fi

    exit "$RC"
}

trap finalize_results EXIT

rm -rf "$outputDir"
mkdir -p "$outputDir" "$evidenceDir"

print_info "Output directory  : $outputDir"
print_info "Evidence directory: $evidenceDir"

# =========================
# Skip if no package
# =========================
if [[ -z "$PACKAGE_URL" || "$PACKAGE_URL" == "NONE" ]]; then
    print_info "No package to deploy"
    exit 0
fi

if [[ "$PACKAGE_URL" != /* ]]; then
    PACKAGE_URL="${SANDBOX_DIR}/zDevOps/applications/${APP_BASE_NAME}/application/packages/${PACKAGE_URL}"
fi

# Copy types_pattern_mapping.yml for BankZ artifact deployment
if [ -f "$DEPLOY_TYPES_MAPPING_FILES" ]; then
    TARGET_TYPES_DIR="$DEPLOY_ZDEPLOY_FOLDER/deployment-configuration/global"
    
    # Create target directory if it doesn't exist
    if [ ! -d "$TARGET_TYPES_DIR" ]; then
        print_info "Creating target directory: $TARGET_TYPES_DIR"
        mkdir -p "$TARGET_TYPES_DIR"
    fi
    
    # Copy the types mapping file
    if [ -d "$TARGET_TYPES_DIR" ]; then
        cp "$DEPLOY_TYPES_MAPPING_FILES" "$TARGET_TYPES_DIR/types_pattern_mapping.yml"
        print_info "Copied types_pattern_mapping.yml to $TARGET_TYPES_DIR"
    else
        print_error "Failed to create target directory: $TARGET_TYPES_DIR"
        print_error "BankZ artifact deployment may fail"
    fi
else
    print_warning "The file types_pattern_mapping.yml not found at: $DEPLOY_TYPES_MAPPING_FILES"
    print_warning "BankZ artifact deployment may use default mappings"
fi

source "${DEPLOY_PYENV_ACTIVATE_PATH}"

# =========================
# BankZ Deployment
# =========================
print_info "========================================="
print_info "BankZ Deployment"
print_info "========================================="

print_info "Starting wazideploy-generate for BankZ"

CMD="wazideploy-generate \
 --deploymentPlanName $APP_BASE_NAME \
 --deploymentPlanVersion $APP_FULL_VERSION \
 --deploymentMethod $DEPLOY_DEPLOYMENT_METHOD \
 --deploymentPlan $outputDir/deploymentPlan-bankz.yaml \
 --deploymentPlanReport $outputDir/deploymentPlanReport-bankz.html \
 --packageInputFile $PACKAGE_URL"

print_info "Executing command:"
print_info "\t$CMD"

${CMD}  --deploymentPlanDescription "$APP_DESCRIPTION" 2>&1 | tee "${outputDir}/wazideploy-generate-bankz.console.log" | while IFS= read -r line
do
    print_info "[GENERATE-${APP_BASE_NAME} $line"
done

RC=${PIPESTATUS[0]}
rm -f message.log

if [ $RC -ne 0 ]; then
    print_error "generate failed with RC=$RC"
    exit $RC
fi

print_info "Starting wazideploy-deploy for BankZ"

CICS_CREDS=""
if [ -n "${CICS_USER:-}" ]; then
    CICS_CREDS="$CICS_CREDS -e default_cics_user=$CICS_USER"
fi
if [ -n "${CICS_PASSWORD:-}" ]; then
    CICS_CREDS="$CICS_CREDS -e default_cics_password=$CICS_PASSWORD"
fi

# Resolve environment varaiables in config file.
export TMPL_CONFIG_FILE="/tmp/config.yaml"
cp  "$CONFIG_FILE" "$TMPL_CONFIG_FILE.j2"
python "$SCRIPTS_DIR/../lib/render_template.py" --configFile $CONFIG_FILE \
    --templateFile "$TMPL_CONFIG_FILE.j2"  --outputFile "$TMPL_CONFIG_FILE"

rm -rf "${DEPLOY_LOG_FOLDER}/work-bankz"

CMD="wazideploy-deploy \
 --workingFolder ${DEPLOY_LOG_FOLDER}/work-bankz \
 --deploymentPlan $outputDir/deploymentPlan-bankz.yaml \
 --envFile $DEPLOY_ENV_FILE \
 -e script_dir=$SCRIPTS_DIR \
 -e @$TMPL_CONFIG_FILE \
 -e application=$APP_BASE_NAME \
 -e hlq=$TARGET_HLQ \
 -e deploy_cfg_home=$DEPLOY_ZDEPLOY_FOLDER \
 -e zos_connect_root=$ZOSCONNECT_SERVER_FOLDER \
 -e sandbox_path=$SANDBOX_DIR \
 $CICS_CREDS \
 --packageInputFile $PACKAGE_URL \
 --evidencesFileName ${evidenceDir}/evidence-bankz.yaml $@"

if [[ "$IMS_DISABLED" == "true" ]]; then
 CMD="$CMD -pst ims"
fi

rm -f message.log

print_info "Executing command:"
print_info "\t$CMD"

${CMD} 2>&1 | tee "${outputDir}/wazideploy-deploy-bankz.console.log" | while IFS= read -r line
do
    print_info "[DEPLOY-${APP_BASE_NAME}] $line"
done

RC=${PIPESTATUS[0]}

if [ $RC -ne 0 ]; then
    print_error "Deployment failed with RC=$RC"
    exit $RC
fi

print_success "Deployment completed successfully"
print_success "BankZ deployment completed successfully"

# =========================
# Cleanup
# =========================
print_info "Cleaning up package file"
rm -f $TMPL_CONFIG_FILE
mv -f "$PACKAGE_URL" "$PACKAGE_URL.deployed"

print_success "Wazi Deploy process completed successfully"
