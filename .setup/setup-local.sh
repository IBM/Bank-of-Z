#!/bin/bash

#########################################################
# Local Orchestrator Script for Bank of Z Setup
# This script runs on your LOCAL machine and uses Zowe CLI
# to coordinate setup on the remote z/OS USS system
#
# Used by: VSCode tasks workflow
#
# Usage: bash setup-local.sh [workspace_path]
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
    
    print_success "Configuration loaded successfully"
    echo "  Workspace: $PIPELINE_WORKSPACE"
}

#########################################################
# STAGE 1: Initialize Remote Workspace
#########################################################
stage1_initialize_remote_workspace() {
    print_stage "STAGE 1: Initialize Remote Workspace"
    
    print_info "Target workspace: $PIPELINE_WORKSPACE"
    
    # Check if directory exists on remote system
    print_info "Checking if workspace directory exists on remote system..."
    
    if zowe rse-api-for-zowe-cli list uss "$PIPELINE_WORKSPACE" &> /dev/null; then
        print_warning "Workspace directory already exists: $PIPELINE_WORKSPACE"
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Deleting existing workspace directory..."
            zowe rse-api-for-zowe-cli delete uss "$PIPELINE_WORKSPACE"
            print_success "Existing workspace deleted"
        else
            print_info "Keeping existing workspace directory"
            return 0
        fi
    fi
    
    # Create workspace directory
    print_info "Creating workspace directory on remote: $PIPELINE_WORKSPACE"
    zowe rse-api-for-zowe-cli create uss-directory "$PIPELINE_WORKSPACE"
    
    print_success "Remote workspace directory initialized: $PIPELINE_WORKSPACE"
}

#########################################################
# STAGE 2: Clone Bank of Z on Remote
#########################################################
stage2_clone_bank_of_z() {
    print_stage "STAGE 2: Clone Bank of Z on Remote"
    
    local current_branch
    
    # Get current branch name
    if git rev-parse --git-dir > /dev/null 2>&1; then
        current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
        print_info "Detected current branch: $current_branch"
    else
        current_branch="main"
        print_warning "Not in a git repository, using default branch: $current_branch"
    fi
    
    # Check if git is available on remote
    print_info "Checking git availability on remote system..."
    if ! zowe rse-api-for-zowe-cli issue unix "which git" --cwd "$PIPELINE_WORKSPACE" &> /dev/null; then
        print_error "Git is not available on the remote z/OS system"
        print_info "Please ensure git is installed and in the PATH on z/OS USS"
        exit 1
    fi
    print_success "Git is available on remote system"
    
    # Check if Bank-of-Z already exists
    print_info "Checking if Bank-of-Z directory already exists..."
    if zowe rse-api-for-zowe-cli list uss "$PIPELINE_WORKSPACE/Bank-of-Z" &> /dev/null; then
        print_warning "Bank-of-Z directory already exists: $PIPELINE_WORKSPACE/Bank-of-Z"
        read -p "Do you want to delete and re-clone it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Removing existing Bank-of-Z directory..."
            zowe rse-api-for-zowe-cli issue unix "rm -rf Bank-of-Z" --cwd "$PIPELINE_WORKSPACE"
            print_success "Existing Bank-of-Z directory removed"
        else
            print_info "Keeping existing Bank-of-Z directory"
            print_warning "Will proceed with existing repository"
            return 0
        fi
    fi
    
    # Clone Bank of Z repository
    print_info "Cloning Bank of Z repository on remote (branch: $current_branch)..."
    print_info "This may take a few minutes..."
    
    if zowe rse-api-for-zowe-cli issue unix-shell "git clone https://github.com/IBM/Bank-of-Z.git -b $current_branch" --cwd "$PIPELINE_WORKSPACE" 2>&1 | tee /tmp/clone.log; then
        print_success "Bank of Z cloned successfully on remote system"
    else
        # Try with main branch if current branch fails
        print_warning "Failed to clone branch '$current_branch', trying 'main' branch..."
        if zowe rse-api-for-zowe-cli issue unix-shell "git clone https://github.com/IBM/Bank-of-Z.git" --cwd "$PIPELINE_WORKSPACE" 2>&1 | tee /tmp/clone.log; then
            print_success "Bank of Z cloned successfully (main branch)"
        else
            print_error "Failed to clone Bank of Z repository on remote system"
            print_info "Please check:"
            print_info "  - Network connectivity from z/OS to GitHub"
            print_info "  - Git configuration on z/OS"
            print_info "  - Branch exists: $current_branch"
            exit 1
        fi
    fi
    
    # Verify the clone
    print_info "Verifying cloned repository..."
    if zowe rse-api-for-zowe-cli list uss "$PIPELINE_WORKSPACE/Bank-of-Z" &> /dev/null; then
        print_success "Repository verification successful"
    else
        print_error "Repository verification failed"
        exit 1
    fi
}

#########################################################
# STAGE 3: Execute Common Setup Script on Remote
#########################################################
stage3_execute_common_setup() {
    print_stage "STAGE 3: Execute Common Setup Script on Remote"
    
    print_info "Executing setup-common.sh on remote z/OS USS..."
    print_info "This will:"
    print_info "  - Initialize workspace"
    print_info "  - Clone DBB accelerators"
    print_info "  - Deploy zBuilder framework"
    print_info "  - Install Bank of Z application"
    echo ""
    
    # Execute the common setup script on remote
    print_info "Running: bash .setup/setup-common.sh"
    
    set -o pipefail
    if zowe rse-api-for-zowe-cli issue unix-shell "bash .setup/setup-common.sh $PIPELINE_WORKSPACE" --cwd "$PIPELINE_WORKSPACE/Bank-of-Z" 2>&1 | tee /tmp/remote-setup.log; then
        # Check for errors in the log
        if grep -i "error\|failed" /tmp/remote-setup.log | grep -v "Failed to change files and directory owner with chown" > /dev/null; then
            print_warning "Setup completed but some warnings were detected"
            print_info "Review /tmp/remote-setup.log for details"
        else
            print_success "Remote setup completed successfully"
        fi
    else
        print_error "Failed to execute setup on remote system"
        print_info "Check /tmp/remote-setup.log for details"
        exit 1
    fi
}

#########################################################
# Main execution
#########################################################
main() {
    echo ""
    echo -e "${GREEN}######################################################${NC}"
    echo -e "${GREEN}#  Bank of Z - Local Orchestrator (Zowe CLI)         #${NC}"
    echo -e "${GREEN}######################################################${NC}"
    echo ""
    
    print_info "This script runs on your LOCAL machine"
    print_info "It uses Zowe CLI to coordinate setup on remote z/OS USS"
    echo ""
    
    # Check prerequisites
    check_zowe_cli
    
    # Load configuration
    load_config "$1"
    
    # Execute stages
    stage1_initialize_remote_workspace
    stage2_clone_bank_of_z
    stage3_execute_common_setup
    
    # Summary
    print_stage "ORCHESTRATION COMPLETE"
    print_success "Remote environment setup completed successfully!"
    
    # Save environment info locally
    cat > "$SCRIPTS_DIR/.env" << EOF
PIPELINE_WORKSPACE=$PIPELINE_WORKSPACE
SETUP_DATE=$(date)
SETUP_USER=$USER
SETUP_MODE=local-orchestrator
EOF
    chmod +x "$SCRIPTS_DIR/.env"
    
    echo ""
    echo "Next steps:"
    echo "  1. Review the setup on remote USS: $PIPELINE_WORKSPACE"
    echo "  2. Check the Bank of Z installation"
    echo "  3. Connect to CICS using x3270:"
    echo "     - Enter 'logon applid(CICSBOZ)'"
    echo "     - Enter 'OMEN' as transaction name"
    echo "     - Enter 1 then 1234 as customer"
    echo "  4. Run pipeline builds from VSCode tasks"
    echo ""
    print_info "Local environment details saved to: $SCRIPTS_DIR/.env"
    print_info "Remote setup logs available at: /tmp/remote-setup.log"
    echo ""
}

# Run main function
main "$@"

# Made with Bob