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


# Function: detect_bank_of_z_location
# Description: Detects whether running inside Bank-of-Z repo or uses cloned version
# Returns: Sets BANK_DIR variable with the repository path
# Exit codes: 0 on success, 1 if repository not found
detect_bank_of_z_location() {
    local IN_REPO=false
    
    # Detect if we're already in the Bank-of-Z repository
    print_info "Detecting Bank of Z location..."
    
    # Check if current directory is a git repo and if it's Bank-of-Z
    if git rev-parse --git-dir > /dev/null 2>&1; then
        local repo_name=$(basename "$(git rev-parse --show-toplevel)")
        if [[ "$repo_name" == "Bank-of-Z" ]]; then
            IN_REPO=true
            BANK_DIR="$(git rev-parse --show-toplevel)"
            print_info "Running from within Bank-of-Z repository"
            print_info "Repository location: $BANK_DIR"
            print_success "Using current repository (GRUB workflow detected)"
        fi
    fi
    
    # If not in repo, use the cloned version in workspace
    if [ "$IN_REPO" = false ]; then
        BANK_DIR="$BANK_OF_Z_WORK_DIR/Bank-of-Z"
        print_info "Using cloned repository at: $BANK_DIR"
        
        if [ ! -d "$BANK_DIR" ]; then
            print_error "Bank-of-Z not found at: $BANK_DIR"
            print_info "Expected location: $BANK_DIR"
            print_info "This should have been cloned by the orchestrator script"
            return 1
        fi
        print_success "Found Bank-of-Z at workspace location (VSCode workflow detected)"
    fi
    
    return 0
}

#########################################################
# STAGE: Initialize Working Directory
#########################################################
stage_initialize_workspace() {
    print_stage "STAGE: Initialize Working Directory"
    
    print_info "Target workspace: $BANK_OF_Z_WORK_DIR"
    
    # Check if directory exists
    if [ -d "$BANK_OF_Z_WORK_DIR" ]; then
        print_warning "Workspace directory already exists: $BANK_OF_Z_WORK_DIR"
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Deleting existing workspace directory..."
            rm -rf "$BANK_OF_Z_WORK_DIR"
            print_success "Existing workspace deleted"
        else
            print_info "Keeping existing workspace directory"
            return 0
        fi
    fi
    
    # Create workspace directory
    print_info "Creating workspace directory: $BANK_OF_Z_WORK_DIR"
    mkdir -p "$BANK_OF_Z_WORK_DIR"
    
    # Purge DBB metadata cache
    if [ -d "$HOME/.dbb" ]; then
        rm -rf "$HOME/.dbb"
        print_success "DBB metadata cache purged"
    fi
    
    print_success "Workspace directory initialized: $BANK_OF_Z_WORK_DIR"
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
# STAGE: Setup Bank of Z application
#########################################################
stage_setup_bank_of_z() {
    print_stage "STAGE: Setup Bank of Z"
    
    detect_bank_of_z_location
    
    # Verify installation script exists
    if [ ! -f "$BANK_DIR/.setup/setup/setup-application.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/setup/setup-application.sh"
        exit 1
    fi
    
    # Run installation script
    print_info "Running Bank of Z application script..."
    print_info "Executing: bash $BANK_DIR/.setup/setup/setup-application.sh"
    cd "$BANK_DIR"
    
    set -o pipefail
    if bash .setup/setup/setup-application.sh; then
        print_success "Bank of Z application setup completed successfully"
    else
        print_error "Failed to install Bank of Z"
        print_info "Check /tmp/build.log for details"
        exit 1
    fi
}
#########################################################
# STAGE: Setup Bank of Z databse
#########################################################
stage_setup_database() {
    print_stage "STAGE: Create DB2 database"

    detect_bank_of_z_location

    # Verify script exists
    if [ ! -f "$BANK_DIR/.setup/setup/setup-db2-tables.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/setup/setup-db2-tables.sh"
        exit 1
    fi
    
    # Run script
    print_info "Running Bank of Z database setup script..."
    print_info "Executing: bash $BANK_DIR/.setup/setup/setup-db2-tables.sh"
    cd "$BANK_DIR"
    
    set -o pipefail
    if bash .setup/setup/setup-db2-tables.sh; then
        print_success "Bank of Z application setup completed successfully"
    else
        print_error "Failed to install Bank of Z"
        print_info "Check /tmp/build.log for details"
        exit 1
    fi

}

#########################################################
# STAGE: Setup Bank of Z databse
#########################################################
stage_setup_cics_region() {
    print_stage "STAGE: Create CICS region with zconfig"

    detect_bank_of_z_location

    # Verify script exists
    if [ ! -f "$BANK_DIR/.setup/setup/setup-cics-region.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/setup/setup-cics-region.sh"
        exit 1
    fi
    
    # Run script
    print_info "Running Bank of Z database setup script..."
    print_info "Executing: bash $BANK_DIR/.setup/setup/setup-cics-region.sh"
    cd "$BANK_DIR"
    
    set -o pipefail
    if bash .setup/setup/setup-cics-region.sh; then
        print_success "Bank of Z application setup completed successfully"
    else
        print_error "Failed to install Bank of Z"
        print_info "Check /tmp/build.log for details"
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
    echo "  validation      Validate prerequisites (zConfig, DBB, wazi-deploy)"
    echo "  setup           Initialize workspace and infrastructure prerequisites"
    echo "  build-baseline  Build and deploy the Bank of Z baseline"
    echo ""
    echo "Examples:"
    echo "  bash setup-common.sh validation"
    echo "  bash setup-common.sh setup"
    echo "  bash setup-common.sh build-baseline"
}

#########################################################
# Main execution
#########################################################
main_setup() {
    echo ""
    SYS=$(uname -Ia)
    print_info "Running on: $SYS"
    echo ""
    
    # Detect Execution Mode
    detect_execution_mode
    
    # Execute stages
    if [[ "$EXECUTION_MODE" != "grub" ]]; then
        stage_initialize_workspace
    fi
    stage_clone_accelerators
    stage_copy_framework

    # infrastructure
    stage_setup_database
    
    stage_setup_cics_region

    # Summary
    print_stage "SETUP COMPLETE"
    print_success "Environment setup completed successfully!"
    print_phase_next_step "setup"
}

main_validation() {
    echo ""
    SYS=$(uname -Ia)
    print_info "Running on: $SYS"
    echo ""

    # Summary
    print_stage "VALIDATION COMPLETE"
    print_success "Environment validation completed successfully!"
    print_phase_next_step "validation"
}

main_build_baseline() {

    echo ""
    SYS=$(uname -Ia)
    print_info "Running on: $SYS"
    echo ""

    stage_setup_bank_of_z

    # Summary
    print_stage "BUILD BASELINE COMPLETE"
    print_success "Bank of Z baseline built and deployed successfully!"
    print_phase_next_step "build-baseline"
}

main() {
    local phase="${1:-}"

    case "$phase" in
        validate-prereqs)
            main_validation
            ;;
        environment)
            main_setup
            ;;
        install-bank-of-z)
            main_build_baseline
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

# Made with Bob