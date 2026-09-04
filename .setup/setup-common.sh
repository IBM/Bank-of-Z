#!/usr/bin/env bash

#########################################################
# Common Setup Script for Bank of Z
# This script runs directly on z/OS USS (not remotely)
# 
# Used by:
#   - GRUB workflow (runs natively after sync)
#   - VSCode task workflow (triggered via Zowe CLI)
#
# Usage: bash setup-common.sh [workspace_path]
#########################################################

set -e  # Exit on error

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/config/setenv.sh"

#########################################################
# STAGE: Stop running tasks (if any)
#########################################################
stage_stop_tasks() {
    set +e
    print_stage "STAGE: Stop Bank of Z running tasks (if any)"
    # =========================
    # Stop IBM IMS regions
    # =========================
    # Delete stale stop members so jsub fails silently rather than executing
    # outdated JCL that may reference deleted datasets.
    mrm "${IMS_APP_HLQ}.JOBS(STOPMPP1)" 2>/dev/null || true
    mrm "${IMS_APP_HLQ}.JOBS(STOPMPP2)" 2>/dev/null || true
    mrm "${IMS_APP_HLQ}.IMSJAVA.JOBS(STOPJMP)" 2>/dev/null || true
    jsub "${IMS_APP_HLQ}.JOBS(STOPMPP1)"  2>/dev/null
    jsub "${IMS_APP_HLQ}.JOBS(STOPMPP2)"  2>/dev/null
    jsub "${IMS_APP_HLQ}.IMSJAVA.JOBS(STOPJMP)"  2>/dev/null
    sleep 5
    jcan P "${IMS_DATASTORE}JMP1" 2>/dev/null
    jcan P "${IMS_DATASTORE}MPP1" 2>/dev/null
    jcan P "${IMS_DATASTORE}MPP2" 2>/dev/null
    sleep 5
    opercmd "C ${IMS_DATASTORE}DRC" 2>/dev/null
    sleep 1
    opercmd "C ${IMS_DATASTORE}OM" 2>/dev/null
    sleep 1
    opercmd "C ${IMS_DATASTORE}RM" 2>/dev/null
    sleep 1
    opercmd "C ${IMS_DATASTORE}SCI" 2>/dev/null
    sleep 1
    # IMS Connect
    opercmd "C ${IMS_DATASTORE}HWS" 2>/dev/null
    sleep 1
    opercmd "C ${IMS_DATASTORE}ODB" 2>/dev/null
    sleep 1
    opercmd "C ${IMS_DATABASE_LOCK_MANAGER_SERVER_NAME}" 2>/dev/null
    
    # =========================
    # Stop IBM CICS regions
    # =========================
    jcan P "CICS${APP_SHORT_NAME}"  2>/dev/null
    opercmd "C CICS${APP_SHORT_NAME}"  2>/dev/null
    
    # =========================
    # Stop IBM zconn servers
    # =========================
    jcan P "BAQ${APP_SHORT_NAME}"  2>/dev/null
    jcan P "FE${APP_SHORT_NAME}"  2>/dev/null
    
    # =========================
    # Stop IMS1
    # =========================
    jcan P "IMS1*" 2>/dev/null
    
    # ===========================
    # Clean application datasets
    # ===========================
    sleep 5
    drm "${APP_HLQ}.${APP_ZOS_VERSION}.*" 2>/dev/null
    drm "${APP_HLQ}.*" 2>/dev/null
    dtouch "${APP_HLQ}.PROCLIB" 2> /dev/null
    rm -rf "${SANDBOX_DIR}/CICS${APP_SHORT_NAME}" 2>/dev/null
    rm -rf "${SANDBOX_DIR}/frontend" 2>/dev/null
    rm -rf "${SANDBOX_DIR}/jars" 2>/dev/null
    rm -rf "${SANDBOX_DIR}/zosconnect-server" 2>/dev/null
    rm -rf "${SANDBOX_DIR}/logs" 2>/dev/null
    set -e
}

#########################################################
# STAGE: Clone Required Accelerators
#########################################################
stage_clone_accelerators() {
    print_stage "STAGE: Clone Required Accelerators"
    
    print_info "Cloning DBB repository..."
    print_info "Repository: $DBB_REPO_URL"
    print_info "Target: $BANK_OF_Z_WORK_DIR/dbb"
    
    # Check if git is available
    print_info "Checking git availability..."
    if ! command -v git &> /dev/null; then
        print_error "Git is not available on this system"
        print_info "Please ensure git is installed and in the PATH"
        exit 1
    fi
    print_success "Git is available"
    
    # Check if dbb directory already exists
    if [ -d "$BANK_OF_Z_WORK_DIR/dbb" ]; then
        if [[ "$EXECUTION_MODE" == "grub" ]]; then
            rm -rf "$BANK_OF_Z_WORK_DIR/dbb"
            print_success "Existing dbb directory removed"
        else
            print_info "Keeping existing dbb directory"
            return 0
        fi
    fi
    
    # Clone repository
    print_info "Cloning repository (this may take a few minutes)..."
    cd "$BANK_OF_Z_WORK_DIR"
    if git clone "$DBB_REPO_URL"; then
        print_success "DBB repository cloned successfully"
    else
        print_error "Failed to clone DBB repository"
        print_info "Please check:"
        print_info "  - Network connectivity to GitHub"
        print_info "  - Git configuration"
        print_info "  - Repository URL: $DBB_REPO_URL"
        exit 1
    fi
    
    # Verify the clone
    if [ -d "$BANK_OF_Z_WORK_DIR/dbb" ]; then
        print_success "Repository verification successful"
    else
        print_error "Repository verification failed"
        exit 1
    fi
}

#########################################################
# STAGE: Copy Build Framework
#########################################################
stage_copy_framework() {
    print_stage "STAGE: Copy Build Framework"
    
    # Print datasets configuration info
    print_info "Datasets configuration from datasets.yaml:"
    echo ""
    python "$SCRIPTS_DIR/lib/render_template.py" --configFile $CONFIG_FILE \
        --templateFile "$SCRIPTS_DIR/build/datasets.yaml.j2"  --outputFile "$SCRIPTS_DIR/build/datasets.yaml"
    if [ -f "$ZBUILDER_SOURCE/datasets.yaml" ]; then
        grep -A 200 "^variables:" "$ZBUILDER_SOURCE/datasets.yaml" | grep -E "^[[:space:]]*#.*Example:" | head -20 || true
    else
        print_warning "datasets.yaml not found at: $ZBUILDER_SOURCE/datasets.yaml"
    fi
    echo ""
    
    # Copy zBuilder framework
    print_info "Copying zBuilder framework..."
    print_info "Source: $ZBUILDER_SOURCE"
    print_info "Target: $ZBUILDER_TARGET"
    
    # Check if source directory exists
    if [ ! -d "$ZBUILDER_SOURCE" ]; then
        print_error "zBuilder source directory not found: $ZBUILDER_SOURCE"
        print_info "Make sure the .setup directory is complete"
        exit 1
    fi
    
    # Check if target directory already exists
    if [ -d "$ZBUILDER_TARGET" ]; then
        if [[ "$EXECUTION_MODE" == "grub" ]]; then
            rm -rf "$ZBUILDER_TARGET"
            print_success "Existing zBuilder directory removed"
        else
            print_info "Keeping existing zBuilder directory, skipping copy"
            return 0
        fi
    fi
    
    # Create parent directory if needed
    PARENT_DIR=$(dirname "$ZBUILDER_TARGET")
    print_info "Ensuring parent directory exists: $PARENT_DIR"
    mkdir -p "$PARENT_DIR"
    
    # Copy directory recursively
    print_info "Copying zBuilder framework files..."
    if cp -r "$ZBUILDER_SOURCE" "$ZBUILDER_TARGET"; then
        print_success "zBuilder framework copied successfully"
    else
        print_error "Failed to copy zBuilder framework"
        exit 1
    fi
    
    print_success "zBuilder framework setup completed successfully"
}


#########################################################
# STAGE: Setup Bank of Z database
#########################################################
stage_setup_database() {
    print_stage "STAGE: Create DB2 database"

    if [ ! -f "$BANK_DIR/.setup/setup/setup-db2-tables.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/setup/setup-db2-tables.sh"
        exit 1
    fi
    
    # Run script
    print_info "Running Bank of Z database setup script..."
    print_info "Executing: bash $BANK_DIR/.setup/setup/setup-db2-tables.sh"
    cd "$BANK_DIR"
    
    set -o pipefail
    if .setup/setup/setup-db2-tables.sh; then
        print_success "Bank of Z application setup completed successfully"
    else
        print_error "Failed to install Bank of Z"
        exit 1
    fi

}

#########################################################
# STAGE: Create Bank of Z IMS database
#########################################################
stage_setup_ims_database() {
    print_stage "STAGE: Create Bank of Z IMS database"

    if [ ! -f "$BANK_DIR/.setup/setup/setup-ims-tables.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/setup/setup-ims-tables.sh"
        exit 1
    fi
    
    # Run script
    print_info "Running Bank of Z IMS database setup script..."
    print_info "Executing: bash $BANK_DIR/.setup/setup/setup-ims-tables.sh"
    cd "$BANK_DIR"
    
    set -o pipefail
    if .setup/setup/setup-ims-tables.sh; then
        print_success "Bank of Z application setup completed successfully"
    else
        print_error "Failed to install Bank of Z"
        exit 1
    fi

}

#########################################################
# STAGE: Setup and start Bank of Z IMS regions
#########################################################
stage_setup_ims_bankz_regions() {
    print_stage "STAGE: Setup and start Bank of Z IMS regions"

    if [ ! -f "$BANK_DIR/.setup/setup/setup-ims-bankz-regions.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/setup/setup-ims-bankz-regions.sh"
        exit 1
    fi
    
    # Run script
    print_info "Running Bank of Z Setup and start IMS regions script..."
    print_info "Executing: bash $BANK_DIR/.setup/setup/setup-ims-bankz-regions.sh"
    cd "$BANK_DIR"
    
    set -o pipefail
    if .setup/setup/setup-ims-bankz-regions.sh; then
        print_success "Bank of Z application setup completed successfully"
    else
        print_error "Failed to install Bank of Z"
        exit 1
    fi

}


#########################################################
# STAGE: Populate DB2 database
#########################################################
stage_populate_database() {
    print_stage "STAGE: Populate DB2 database"

    if [ ! -f "$BANK_DIR/.setup/setup/populate-db2-tables.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/setup/populate-db2-tables.sh"
        exit 1
    fi
    
    # Run script
    print_info "Running Bank of Z database populate script..."
    print_info "Executing: bash $BANK_DIR/.setup/setup/populate-db2-tables.sh"
    cd "$BANK_DIR"
    
    set -o pipefail
    if .setup/setup/populate-db2-tables.sh; then
        print_success "Bank of Z application populate completed successfully"
    else
        print_error "Failed to populate Bank of Z database"
        exit 1
    fi

}

#########################################################
# STAGE: Populate IMS database
#########################################################
stage_populate_ims_database() {
    print_stage "STAGE: Populate IMS database"

    if [ ! -f "$BANK_DIR/.setup/setup/populate-ims-tables.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/setup/populate-ims-tables.sh"
        exit 1
    fi
    
    # Run script
    print_info "Running Bank of Z database populate script..."
    print_info "Executing: bash $BANK_DIR/.setup/setup/populate-ims-tables.sh"
    cd "$BANK_DIR"
    
    set -o pipefail
    if .setup/setup/populate-ims-tables.sh; then
        print_success "Bank of Z application populate completed successfully"
    else
        print_error "Failed to populate Bank of Z database"
        exit 1
    fi

}


#########################################################
# STAGE: Setup RACF certificates and keyring
#########################################################
stage_setup_certificates() {
    print_stage "STAGE: Setup RACF certificates and keyring"

    if [ ! -f "$BANK_DIR/.setup/setup/clearcert.sh" ]; then
        print_error "Certificate script not found: $BANK_DIR/.setup/setup/clearcert.sh"
        exit 1
    fi

    if [ ! -f "$BANK_DIR/.setup/setup/addcert.sh" ]; then
        print_error "Certificate script not found: $BANK_DIR/.setup/setup/addcert.sh"
        exit 1
    fi

    cd "$BANK_DIR"
    set -o pipefail

    print_info "Executing: bash $BANK_DIR/.setup/setup/clearcert.sh"
    if bash .setup/setup/clearcert.sh; then
        print_success "RACF keyring teardown completed"
    else
        print_error "Failed to clear existing RACF certificates"
        exit 1
    fi

    print_info "Executing: bash $BANK_DIR/.setup/setup/addcert.sh"
    if bash .setup/setup/addcert.sh; then
        print_success "RACF keyring and certificates created successfully"
    else
        print_error "Failed to setup RACF certificates"
        exit 1
    fi
}

#########################################################
# STAGE: Setup zOS Connect server
#########################################################
stage_setup_zosconnect_server() {
    print_stage "STAGE: Setup zOS Connect server"

    if [ ! -f "$BANK_DIR/.setup/setup/setup-zosconnect-server.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/setup/setup-zosconnect-server.sh"
        exit 1
    fi
    
    # Run script
    print_info "Running Bank of Z zOS Connect server setup script..."
    print_info "Executing: bash $BANK_DIR/.setup/setup/setup-zosconnect-server.sh"
    cd "$BANK_DIR"
    
    set -o pipefail
    if bash .setup/setup/setup-zosconnect-server.sh; then
        print_success "Bank of Z application setup completed successfully"
    else
        print_error "Failed to install Bank of Z"
        exit 1
    fi

}
#########################################################
# STAGE: Setup Frontend Liberty server
#########################################################
stage_setup_frontend_server() {
    print_stage "STAGE: Setup Frontend Liberty server"

    if [ ! -f "$BANK_DIR/.setup/setup/setup-frontend-server.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/setup/setup-frontend-server.sh"
        exit 1
    fi
    
    # Run script
    print_info "Running Bank of Z Frontend Liberty server setup script..."
    print_info "Executing: bash $BANK_DIR/.setup/setup/setup-frontend-server.sh"
    cd "$BANK_DIR"
    
    set -o pipefail
    if bash .setup/setup/setup-frontend-server.sh; then
        print_success "Frontend Liberty server setup completed successfully"
    else
        print_error "Failed to setup Frontend Liberty server"
        exit 1
    fi

}



#########################################################
# STAGE: Setup Db2 subsystem
#########################################################
stage_setup_db2_subsystem() {
    print_stage "STAGE: Provision Db2 subsystem with zconfig"

    if [ ! -f "$BANK_DIR/.setup/setup/setup-db2-subsystem.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/setup/setup-db2-subsystem.sh"
        exit 1
    fi

    print_info "Running Db2 subsystem provisioning script..."
    print_info "Executing: bash $BANK_DIR/.setup/setup/setup-db2-subsystem.sh"
    cd "$BANK_DIR"

    set -o pipefail
    if .setup/setup/setup-db2-subsystem.sh; then
        print_success "Db2 subsystem provisioning completed successfully"
    else
        print_error "Failed to provision Db2 subsystem"
        exit 1
    fi
}

stage_deprovision_db2_subsystem() {
    print_stage "Deprovision Db2 subsystem with zconfig"

    if [ ! -f "$BANK_DIR/.setup/setup/deprovision-db2-subsystem.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/setup/deprovision-db2-subsystem.sh"
        exit 1
    fi

    # Stop Bank of Z consumers before removing the subsystem they use.
    stage_stop_tasks

    print_info "Running Db2 subsystem deprovisioning script..."
    print_info "Executing: bash $BANK_DIR/.setup/setup/deprovision-db2-subsystem.sh"
    cd "$BANK_DIR"

    set -o pipefail
    if .setup/setup/deprovision-db2-subsystem.sh; then
        print_success "Db2 subsystem deprovisioning completed successfully"
    else
        print_error "Failed to deprovision Db2 subsystem"
        exit 1
    fi
}

#########################################################
# STAGE: Setup CICS region
#########################################################
wait_for_cics_cmci() {
    local cics_job="CICS${APP_SHORT_NAME}"
    local elapsed=0
    local reply_id=""

    print_info "Waiting for CICS CMCI port ${CICS_CMCI_PORT}..."
    while (( elapsed < CICS_CMCI_START_TIMEOUT_SECONDS )); do
        if netstat -a 2>/dev/null | grep -qi ":${CICS_CMCI_PORT}.*listen"; then
            print_success "CICS CMCI is listening on port ${CICS_CMCI_PORT}"
            return 0
        fi

        if [[ -z "$reply_id" ]]; then
            reply_id=$(opercmd 'D R,L' 2>/dev/null |
                grep "DFHSI1580D ${cics_job} PLT program EZACIC20" |
                awk '$2 == "R" && $1 ~ /^[0-9]+$/ { print $1; exit }' || true)
            if [[ -n "$reply_id" ]]; then
                print_info "Replying GO to CICS startup prompt ${reply_id}"
                opercmd "R ${reply_id},GO" >/dev/null 2>&1 || {
                    print_error "Unable to reply GO to CICS startup prompt ${reply_id}"
                    return 1
                }
            fi
        fi

        sleep 5
        ((elapsed += 5))
    done

    print_error "CICS CMCI did not listen on port ${CICS_CMCI_PORT} within ${CICS_CMCI_START_TIMEOUT_SECONDS} seconds"
    return 1
}

stage_setup_cics_region() {
    print_stage "STAGE: Create CICS region with zconfig"

    # Verify script exists
    if [ ! -f "$BANK_DIR/.setup/setup/setup-cics-region.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/setup/setup-cics-region.sh"
        exit 1
    fi
    
    # Run script
    print_info "Running CICS region setup script..."
    print_info "Executing: bash $BANK_DIR/.setup/setup/setup-cics-region.sh"
    cd "$BANK_DIR"
    
    set -o pipefail
    if .setup/setup/setup-cics-region.sh; then
        print_success "CICS region setup completed successfully"
    else
        print_error "Failed to setup CICS region"
        exit 1
    fi

    if [[ "${CICS_AUTO_REPLY_GO,,}" == "true" ]]; then
        wait_for_cics_cmci || exit 1
    fi
}

#########################################################
# STAGE: Setup IMS region
#########################################################
stage_setup_ims_region() {
    print_stage "STAGE: Create IMS region with zconfig"

    # Verify script exists
    if [ ! -f "$BANK_DIR/.setup/setup/setup-ims-region.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/setup/setup-ims-region.sh"
        exit 1
    fi
    
    # Run script
    print_info "Running IMS region setup script..."
    print_info "Executing: bash $BANK_DIR/.setup/setup/setup-ims-region.sh"
    cd "$BANK_DIR"
    
    
    set -o pipefail
    if .setup/setup/setup-ims-region.sh; then
        print_success "IMS region setup completed successfully"
    else
        print_error "Failed to setup IMS region"
        exit 1
    fi
}

#########################################################
# STAGE: Setup DPS
#########################################################
stage_setup_debug_profile_service() {
    print_stage "STAGE: Configure Debug Profile Service"

    # Verify script exists
    if [ ! -f "$BANK_DIR/.setup/setup/setup-debug.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/setup/setup-debug.sh"
        exit 1
    fi
    
    # Run script
    print_info "Running Debug Profile Service setup script..."
    print_info "Executing: bash $BANK_DIR/.setup/setup/setup-debug.sh"
    cd "$BANK_DIR"
    
    
    set -o pipefail
    if .setup/setup/setup-debug.sh; then
        print_success "Debug Profile Service setup completed successfully"
    else
        print_error "Failed to setup Debug Profile Service"
        exit 1
    fi
}


#########################################################
# Main execution helpers
#########################################################
print_phase_next_step() {
    local completed_phase="$1"

    echo ""
    case "$completed_phase" in
        validation)
            print_info "Next step: run this script in setup mode to initialize the workspace and infrastructure prerequisites."
            ;;
        setup)
            print_info "Next step: run this script in build-baseline mode to build and deploy the Bank of Z baseline."
            ;;
        build-baseline)
            print_info "Next step: baseline deployment is complete. Proceed with application verification or follow-on customization."
            ;;
    esac
}

print_usage() {
    echo "Usage: bash setup-common.sh <phase>"
    echo ""
    echo "Phases:"
    echo "  validate-prereqs    Validate prerequisites (zconfig, DBB, wazi-deploy)"
    echo "  environment         Initialize workspace and infrastructure prerequisites"
    echo "  deprovision-db2     Remove the configured zconfig-managed Db2 subsystem"
    echo "  install-bank-of-z   Build and deploy the Bank of Z baseline"
    echo "  verify-installation Run post-install verification tests from tests/"
    echo ""
    echo "Examples:"
    echo "  bash setup-common.sh validate-prereqs"
    echo "  bash setup-common.sh environment"
    echo "  DB2_DEPROVISION_CONFIRM=<ssid> bash setup-common.sh deprovision-db2"
    echo "  bash setup-common.sh install-bank-of-z"
    echo "  bash setup-common.sh verify-installation"
    echo ""
    echo "verify-installation environment variables:"
    echo "  BASE_URL       z/OS Connect API base URL  (default: derived from config)"
    echo "  FRONTEND_URL   Frontend Liberty base URL  (default: derived from config)"
    echo "  IMS_DISABLED   Set to true to skip IMS-specific tests"
}

#########################################################
# Main execution
#########################################################
main_setup() {
    echo ""
    SYS=$(uname -Ia)
    print_info "Running on: $SYS"
    echo ""

    stage_clone_accelerators
    stage_copy_framework

    # infrastructure
    stage_stop_tasks

    if [[ "${DB2_PROVISION}" == "true" ]]; then
        if [[ "${DB2_REPROVISION,,}" == "true" ]]; then
            print_warning "DB2_REPROVISION=true: removing ${DB2_SSID} before provisioning it again"
            export DB2_DEPROVISION_CONFIRM="${DB2_SSID}"
            stage_deprovision_db2_subsystem
        fi
        stage_setup_db2_subsystem
    else
        print_info "Skipping Db2 provisioning (DB2_PROVISION=false) - using pre-existing subsystem ${DB2_SSID}"
    fi

    stage_setup_database

    stage_setup_cics_region
    if [[ "$IMS_DISABLED" != "true" ]]; then
        stage_setup_ims_region
        stage_setup_ims_database
        stage_setup_ims_bankz_regions
    fi

    stage_setup_debug_profile_service

    # Certificates
    if [[ "${ZOS_CREATE_CERTS,,}" == "true" ]]; then
        stage_setup_certificates
    fi

    stage_setup_zosconnect_server
    stage_setup_frontend_server

    # Summary
    print_stage "SETUP COMPLETE"
    print_success "Environment setup completed successfully!"
    print_phase_next_step "setup"
}

#########################################################
# STAGE: Validate Installation
#########################################################
stage_validate_install() {
    print_stage "STAGE: Validate Installation"

    if [ ! -f "$BANK_DIR/.setup/setup/validate-install.sh" ]; then
        print_error "Validation script not found: $BANK_DIR/.setup/setup/validate-install.sh"
        exit 1
    fi
    
    # Run validation script
    print_info "Running Bank of Z installation validation script..."
    print_info "Executing: bash $BANK_DIR/.setup/setup/validate-install.sh"
    cd "$BANK_DIR"
    
    set -o pipefail
    if bash .setup/setup/validate-install.sh; then
        print_success "Installation validation completed successfully"
    else
        print_error "Installation validation failed"
        exit 1
    fi
}

main_validation() {
    echo ""
    SYS=$(uname -Ia)
    print_info "Running on: $SYS"
    echo ""

    # Validate installation
    stage_validate_install

    # Summary
    print_stage "VALIDATION COMPLETE"
    print_success "Environment validation completed successfully!"
    print_phase_next_step "validation"
}

#########################################################
# STAGE: Post-install verification tests
#########################################################
stage_verify_installation() {
    print_stage "STAGE: Post-install Verification Tests"

    local task="${SCRIPTS_DIR}/tasks/task-install-verification.sh"

    if [ ! -f "$task" ]; then
        print_error "Verification task not found: $task"
        exit 1
    fi

    set -o pipefail
    if bash "$task"; then
        print_success "All verification tests passed"
    else
        print_error "One or more verification tests failed"
        exit 1
    fi
}

main_verify_installation() {
    echo ""
    SYS=$(uname -Ia)
    print_info "Running on: $SYS"
    echo ""

    stage_verify_installation

    print_stage "VERIFICATION COMPLETE"
    print_success "Installation verification completed successfully!"
}

main() {
    local phase="${1:-}"

    # Detect Execution Mode
    detect_bank_of_z_location

    case "$phase" in
        validate-prereqs)
            main_validation
            ;;
        environment)
            main_setup
            ;;
        deprovision-db2)
            stage_deprovision_db2_subsystem
            ;;
        install-bank-of-z)
            if ${SCRIPTS_DIR}/pipeline-common.sh build-and-deploy full; then
                print_success "Remote pipeline completed successfully"
            else
                print_error "Failed to execute pipeline on remote system"
                exit 1
            fi
            stage_populate_database
            if [[ "$IMS_DISABLED" != "true" ]]; then
                stage_populate_ims_database
            fi
            
            # Restart frontend and z/OS Connect servers (dropinsEnabled="false")
            opercmd "C FE${APP_SHORT_NAME}" 2>/dev/null || true
            opercmd "C BAQ${APP_SHORT_NAME}" 2>/dev/null || true
            sleep 5
            if [[ "$FRONTEND_SYS_PROCLIB" != "${APP_HLQ}.PROCLIB" ]]; then
                opercmd "S FE${APP_SHORT_NAME}" 2>/dev/null || true
            else
                jsub "${FRONTEND_SYS_PROCLIB}(FE${APP_SHORT_NAME}J)" 2>/dev/null || true
            fi
            if [[ "$ZOSCONNECT_SYS_PROCLIB" != "${APP_HLQ}.PROCLIB" ]]; then
                opercmd "S BAQ${APP_SHORT_NAME}" 2>/dev/null || true
            else
                jsub "${ZOSCONNECT_SYS_PROCLIB}(BAQ${APP_SHORT_NAME}J)"  2>/dev/null || true
            fi
            ;;
        verify-installation)
            main_verify_installation
            ;;
        -h|--help|help|"")
            print_usage
            ;;
        *)
            print_error "Unknown phase: $phase"
            echo ""
            print_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
exit $?

# Made with Bob
