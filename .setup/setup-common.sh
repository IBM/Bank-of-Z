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

# =========================
# Load configuration
# =========================
load_config() {
    print_info "Loading configuration from $CONFIG_FILE..."
    
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Parse configuration values
    if [[ -n "$1" ]]; then
        PIPELINE_WORKSPACE="$1"
    else
        PIPELINE_WORKSPACE=$(get_section_value 'sandbox' 'path')
    fi
    DBB_REPO_URL=$(get_section_value 'repositories' 'url')
    ZBUILDER_SOURCE="$SCRIPTS_DIR/$(get_section_value 'zbuilder' 'source_dir')"
    ZBUILDER_TARGET=$(get_section_value 'zbuilder' 'target_dir')
    
    print_success "Configuration loaded successfully"
    echo "  Workspace: $PIPELINE_WORKSPACE"
}

#########################################################
# STAGE 1: Initialize Working Directory
#########################################################
stage1_initialize_workspace() {
    print_stage "STAGE 1: Initialize Working Directory"
    
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
# STAGE 2: Clone Required Accelerators
#########################################################
stage2_clone_accelerators() {
    print_stage "STAGE 2: Clone Required Accelerators"
    
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
# STAGE 3: Copy Build Framework
#########################################################
stage3_copy_framework() {
    print_stage "STAGE 3: Copy Build Framework"
    
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
# STAGE 4: Setup Bank of Z
#########################################################
stage4_setup_bank_of_z() {
    print_stage "STAGE 4: Setup Bank of Z"
    
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
    if [ ! -f "$BANK_DIR/.setup/create/create-application.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/create/create-application.sh"
        exit 1
    fi
    
    # Run installation script
    print_info "Running Bank of Z installation script..."
    print_info "Executing: bash $BANK_DIR/.setup/create/create-application.sh"
    cd "$BANK_DIR"
    
    set -o pipefail
    if bash .setup/create/create-application.sh 2>&1 | tee /tmp/build.log; then
        # Check for errors in the log
        if grep -i "error\|failed\|RC=[^0]\|return code [^0]" /tmp/build.log | grep -v "Failed to change files and directory owner with chown" > /dev/null; then
            print_error "Installation completed with errors (see /tmp/build.log)"
            print_warning "Review the log file for details"
            exit 1
        fi
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
    echo -e "${GREEN}######################################################${NC}"
    echo -e "${GREEN}#  Bank of Z - Common Setup Script (z/OS USS)        #${NC}"
    echo -e "${GREEN}######################################################${NC}"
    echo ""
    
    print_info "This script runs directly on z/OS USS"
    print_info "Execution mode: Native USS commands"
    echo ""
    
    # Load configuration
    load_config "$1"
    
    # Execute stages
    stage1_initialize_workspace
    stage2_clone_accelerators
    stage3_copy_framework
    stage4_setup_bank_of_z
    
    # Summary
    print_stage "SETUP COMPLETE"
    print_success "Environment setup completed successfully!"
    
    # Save environment info
    cat > "$SCRIPTS_DIR/.env" << EOF
PIPELINE_WORKSPACE=$PIPELINE_WORKSPACE
SETUP_DATE=$(date)
SETUP_USER=$USER
SETUP_MODE=common
EOF
    chmod +x "$SCRIPTS_DIR/.env"
    
    echo ""
    echo "Next steps:"
    echo "  1. Review the setup in: $PIPELINE_WORKSPACE"
    echo "  2. Check the Bank of Z installation"
    echo "  3. Connect to CICS using x3270:"
    echo "     - Enter 'logon applid(CICSBOZ)'"
    echo "     - Enter 'OMEN' as transaction name"
    echo "     - Enter 1 then 1234 as customer"
    echo "  4. Run pipeline builds from: $BANK_DIR"
    echo ""
    print_info "Environment details saved to: $SCRIPTS_DIR/.env"
    echo ""
}

# Run main function
main "$@"

# Made with Bob