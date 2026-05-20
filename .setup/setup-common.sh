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
# STAGE: Initialize Working Directory
#########################################################
stage_initialize_workspace() {
    print_stage "STAGE: Initialize Working Directory"
    
    print_info "Target workspace: $PIPELINE_WORKSPACE"
    
    # Check if directory exists
    if [ -d "$PIPELINE_WORKSPACE" ]; then
        print_warning "Workspace directory already exists: $PIPELINE_WORKSPACE"
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Deleting existing workspace directory..."
            rm -rf "$PIPELINE_WORKSPACE"
            print_success "Existing workspace deleted"
        else
            print_info "Keeping existing workspace directory"
            return 0
        fi
    fi
    
    # Create workspace directory
    print_info "Creating workspace directory: $PIPELINE_WORKSPACE"
    mkdir -p "$PIPELINE_WORKSPACE"
    
    # Purge DBB metadata cache
    if [ -d "$HOME/.dbb" ]; then
        rm -rf "$HOME/.dbb"
        print_success "DBB metadata cache purged"
    fi
    
    print_success "Workspace directory initialized: $PIPELINE_WORKSPACE"
}

#########################################################
# STAGE: Clone Required Accelerators
#########################################################
stage_clone_accelerators() {
    print_stage "STAGE: Clone Required Accelerators"
    
    print_info "Cloning DBB repository..."
    print_info "Repository: $DBB_REPO_URL"
    print_info "Target: $PIPELINE_WORKSPACE/dbb"
    
    # Check if git is available
    print_info "Checking git availability..."
    if ! command -v git &> /dev/null; then
        print_error "Git is not available on this system"
        print_info "Please ensure git is installed and in the PATH"
        exit 1
    fi
    print_success "Git is available"
    
    # Check if dbb directory already exists
    if [ -d "$PIPELINE_WORKSPACE/dbb" ]; then
        if [[ "$EXECUTION_MODE" == "grub" ]]; then
            rm -rf "$PIPELINE_WORKSPACE/dbb"
            print_success "Existing dbb directory removed"
        else
            print_warning "DBB directory already exists: $PIPELINE_WORKSPACE/dbb"
            read -p "Do you want to delete and re-clone it? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_info "Removing existing dbb directory..."
                rm -rf "$PIPELINE_WORKSPACE/dbb"
                print_success "Existing dbb directory removed"
            else
                print_info "Keeping existing dbb directory"
                return 0
            fi
        fi
    fi
    
    # Clone repository
    print_info "Cloning repository (this may take a few minutes)..."
    cd "$PIPELINE_WORKSPACE"
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
    if [ -d "$PIPELINE_WORKSPACE/dbb" ]; then
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
# STAGE: Setup Bank of Z
#########################################################
stage_setup_bank_of_z() {
    print_stage "STAGE: Setup Bank of Z"
    
    local BANK_DIR
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
        BANK_DIR="$PIPELINE_WORKSPACE/Bank-of-Z"
        print_info "Using cloned repository at: $BANK_DIR"
        
        if [ ! -d "$BANK_DIR" ]; then
            print_error "Bank-of-Z not found at: $BANK_DIR"
            print_info "Expected location: $BANK_DIR"
            print_info "This should have been cloned by the orchestrator script"
            exit 1
        fi
        print_success "Found Bank-of-Z at workspace location (VSCode workflow detected)"
    fi
    
    # Verify installation script exists
    if [ ! -f "$BANK_DIR/.setup/setup/setup-application.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/setup/setup-application.sh"
        exit 1
    fi
    
    # Run installation script
    print_info "Running Bank of Z installation script..."
    print_info "Executing: bash $BANK_DIR/.setup/setup/setup-application.sh"
    cd "$BANK_DIR"
    
    set -o pipefail
    if bash .setup/setup/setup-application.sh; then
        print_success "Bank of Z installation completed successfully"
    else
        print_error "Failed to install Bank of Z"
        print_info "Check /tmp/build.log for details"
        exit 1
    fi
}

#########################################################
# Main execution
#########################################################
main() {
    echo ""
    
    print_info "This script runs directly on z/OS USS"
    print_info "Execution mode: Native USS commands"
    echo ""
    
    # Set PIPELINE_WORKSPACE from parameter if provided
    if [[ -n "$1" ]]; then
        export PIPELINE_WORKSPACE="$1"
        print_info "Using workspace from parameter: $PIPELINE_WORKSPACE"
    fi
    
    # Detect Execution Mode
    detect_execution_mode
    
    # Execute stages
    if [[ "$EXECUTION_MODE" != "grub" ]]; then
        stage_initialize_workspace
    fi
    stage_clone_accelerators
    stage_copy_framework
    stage_setup_bank_of_z
    
    # Summary
    print_stage "SETUP COMPLETE"
    print_success "Environment setup completed successfully!"
    
}

# Run main function
main "$@"

# Made with Bob