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
    # =========================
    # Stop IBM IMS regions
    # =========================
    jsub "${BOZ_IMS_HLQ}.JOBS(STOPMPP1)"  2>/dev/null
    jsub "${BOZ_IMS_HLQ}.JOBS(STOPMPP2)"  2>/dev/null
    jsub "${BOZ_IMS_HLQ}.IMSJAVA.JOBS(STOPJMP)"  2>/dev/null
    sleep 5
    jcan P "IMS2JMP1" 2>/dev/null
    jcan P "IMS2MPP1" 2>/dev/null
    jcan P "IMS2MPP2" 2>/dev/null
    
    # =========================
    # Stop IBM CICS regions
    # =========================
    jcan P "CICS${APP_SHORT_NAME}"  2>/dev/null
    opercmd "C CICS${APP_SHORT_NAME}"  2>/dev/null
    
    # =========================
    # Stop IBM zconn servers
    # =========================
    jcan P "BAQ${APP_NAME}"  2>/dev/null
    
    # =========================
    # Stop IMS1
    # =========================
    jcan P "IMS1*" 2>/dev/null
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
            print_warning "DBB directory already exists: $BANK_OF_Z_WORK_DIR/dbb"
            read -p "Do you want to delete and re-clone it? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_info "Removing existing dbb directory..."
                rm -rf "$BANK_OF_Z_WORK_DIR/dbb"
                print_success "Existing dbb directory removed"
            else
                print_info "Keeping existing dbb directory"
                return 0
            fi
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
            print_warning "zBuilder directory already exists: $ZBUILDER_TARGET"
            read -p "Do you want to delete and re-copy it? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_info "Removing existing zBuilder directory..."
                rm -rf "$ZBUILDER_TARGET"
                print_success "Existing zBuilder directory removed"
            else
                print_info "Keeping existing zBuilder directory, skipping copy"
                return 0
            fi
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
    chmod +x .setup/setup/setup-ims-tables.sh
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
    chmod +x .setup/setup/setup-ims-bankz-regions.sh
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
    chmod +x .setup/setup/populate-ims-tables.sh
    if .setup/setup/populate-ims-tables.sh; then
        print_success "Bank of Z application populate completed successfully"
    else
        print_error "Failed to populate Bank of Z database"
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
# STAGE: Setup CICS region
#########################################################
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
    .setup/setup/setup-cics-region.sh &
    PID=$!
    # Wait for cics setup to complete (ZOAU/ZOWE ISSUE)
    if wait "$PID"; then
        print_success "CICS region setup completed successfully"
    else
        print_error "Failed to setup CICS region"
        exit 1
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
    chmod +x .setup/setup/setup-ims-region.sh
    .setup/setup/setup-ims-region.sh&
    PID=$!
    # Wait for cics setup to complete (ZOAU/ZOWE ISSUE)
    if wait "$PID"; then
        print_success "IMS region setup completed successfully"
    else
        print_error "Failed to setup IMS region"
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
    echo "  validate-prereqs  Validate prerequisites (zConfig, DBB, wazi-deploy)"
    echo "  environment       Initialize workspace and infrastructure prerequisites"
    echo "  install-bank-of-z Build and deploy the Bank of Z baseline"
    echo ""
    echo "Examples:"
    echo "  bash setup-common.sh validate-prereqs"
    echo "  bash setup-common.sh environment"
    echo "  bash setup-common.sh install-bank-of-z"
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
    
    stage_setup_database
    
    stage_setup_cics_region
    
    stage_setup_ims_region
    
    stage_setup_ims_database
    
    stage_setup_ims_bankz_regions
    
    stage_setup_zosconnect_server
    
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
        install-bank-of-z)
            chmod +x ${SCRIPTS_DIR}/pipeline-common.sh
            bash ${SCRIPTS_DIR}/pipeline-common.sh build-and-deploy full &
            PID=$!
            # Wait for deployment to complete (ZOAU/ZOWE ISSUE)
            if wait "$PID"; then
                print_success "Remote pipeline completed successfully"
            else
                print_error "Failed to execute pipeline on remote system"
                exit 1
            fi
            stage_populate_database
            stage_populate_ims_database
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
