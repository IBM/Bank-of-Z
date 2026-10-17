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

# setup-local.sh reads the YAML configuration before it can issue remote
# commands. Check its Mac-side dependencies first so the failure is clear.
if ! command -v zowe >/dev/null 2>&1; then
    echo "[ERROR] Zowe CLI is required to run setup-local.sh."
    exit 1
fi
if ! python3 -c 'import yaml, jinja2' >/dev/null 2>&1; then
    echo "[ERROR] Python packages PyYAML and Jinja2 are required to run setup-local.sh."
    echo "[INFO] Install them with: python3 -m pip install --user PyYAML Jinja2"
    exit 1
fi

source "$SCRIPTS_DIR/config/setenv.sh"

#########################################################
# STAGE: Initialize Remote Workspace
#########################################################
stage_initialize_remote_workspace() {
    print_stage "STAGE: Initialize Remote Workspace"
    
    print_info "Target workspace: $BANK_OF_Z_WORK_DIR"
    
    # Check if directory exists on remote system
    print_info "Checking if workspace directory exists on remote system..."
    
    if zowe rse-api-for-zowe-cli list uss "$BANK_OF_Z_WORK_DIR" &> /dev/null; then
        print_warning "Workspace directory already exists: $BANK_OF_Z_WORK_DIR"
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Deleting existing workspace directory..."
            zowe rse-api-for-zowe-cli delete uss "$BANK_OF_Z_WORK_DIR"
            print_success "Existing workspace deleted"
        else
            print_info "Keeping existing workspace directory"
            return 0
        fi
    fi
    
    # Create workspace directory
    print_info "Creating workspace directory on remote: $BANK_OF_Z_WORK_DIR"
    zowe rse-api-for-zowe-cli create uss-directory "$BANK_OF_Z_WORK_DIR"
    
    print_success "Remote workspace directory initialized: $BANK_OF_Z_WORK_DIR"
}

#########################################################
# STAGE: Clone Bank of Z on Remote
#########################################################
stage_clone_bank_of_z() {
    print_stage "STAGE: Clone Bank of Z on Remote"
    
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
    if ! zowe rse-api-for-zowe-cli issue unix "which git" --cwd "$BANK_OF_Z_WORK_DIR" &> /dev/null; then
        print_error "Git is not available on the remote z/OS system"
        print_info "Please ensure git is installed and in the PATH on z/OS USS"
        exit 1
    fi
    print_success "Git is available on remote system"
    
    # Check if Bank-of-Z already exists
    print_info "Checking if Bank-of-Z directory already exists..."
    if zowe rse-api-for-zowe-cli list uss "$BANK_OF_Z_WORK_DIR/Bank-of-Z" &> /dev/null; then
        print_warning "Bank-of-Z directory already exists: $BANK_OF_Z_WORK_DIR/Bank-of-Z"
        read -p "Do you want to delete and re-clone it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Removing existing Bank-of-Z directory..."
            zowe rse-api-for-zowe-cli issue unix "rm -rf Bank-of-Z" --cwd "$BANK_OF_Z_WORK_DIR"
            print_success "Existing Bank-of-Z directory removed"
        else
            print_info "Keeping existing Bank-of-Z directory"
            print_warning "Will proceed with existing repository"
            return 0
        fi
    fi
    
    # Clone from the remote that contains the current branch. This supports
    # feature branches hosted in a fork when origin points at IBM/Bank-of-Z.
    current_remote=$(git config --get "branch.${current_branch}.remote" 2>/dev/null || true)
    if [[ -z "$current_remote" ]]; then
        for remote_name in $(git remote); do
            remote_url=$(git config --get "remote.${remote_name}.url")
            if git ls-remote --exit-code --heads "$remote_url" "refs/heads/${current_branch}" >/dev/null 2>&1; then
                current_remote="$remote_name"
                break
            fi
        done
    fi
    current_remote="${current_remote:-origin}"
    current_repo=$(git config --get "remote.${current_remote}.url" | sed -E 's#git@([^:]+):#https://\1/#')
    if [[ -z "$current_repo" ]]; then
        print_error "Unable to determine the Git remote for branch '$current_branch'"
        exit 1
    fi
    print_info "Cloning $current_repo on remote (branch: $current_branch)..."
    print_info "This may take a few minutes..."
    
    if zowe rse-api-for-zowe-cli issue unix-shell "git clone $current_repo -b $current_branch" --cwd "$BANK_OF_Z_WORK_DIR" 2>&1 | tee /tmp/clone.log; then
        print_success "Bank of Z cloned successfully on remote system"
    else
        # Try with main branch if current branch fails
        print_warning "Failed to clone branch '$current_branch', trying 'main' branch..."
        if zowe rse-api-for-zowe-cli issue unix-shell "git clone $current_repo" --cwd "$BANK_OF_Z_WORK_DIR" 2>&1 | tee /tmp/clone.log; then
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
    if zowe rse-api-for-zowe-cli list uss "$BANK_OF_Z_WORK_DIR/Bank-of-Z" &> /dev/null; then
        print_success "Repository verification successful"
    else
        print_error "Repository verification failed"
        exit 1
    fi
}

#########################################################
# STAGE: Execute Common Setup Script on Remote
#########################################################
stage_execute_common_setup() {
    print_stage "STAGE: Execute Common Setup Script on Remote"
    
    # Define BANK_DIR
    BANK_DIR="$PIPELINE_WORKSPACE/Bank-of-Z"
    
    print_info "Executing setup-common.sh on remote z/OS USS..."
    print_info "This will:"
    print_info "  - Initialize workspace"
    print_info "  - Clone DBB accelerators"
    print_info "  - Deploy zBuilder framework"
    print_info "  - Install Bank of Z application"
    echo ""
    
    # Execute the remote setup script on remote
    print_info "Running: bash $BANK_DIR/.setup/setup-remote.sh $PIPELINE_WORKSPACE"
    
    set -o pipefail
    if zowe rse-api-for-zowe-cli issue unix-shell "export BANK_OF_Z_WORK_DIR=$BANK_OF_Z_WORK_DIR && bash  $BANK_OF_Z_WORK_DIR/Bank-of-Z/.setup/setup-remote.sh" --cwd "$BANK_OF_Z_WORK_DIR" 2>&1 | tee /tmp/remote-setup.log; then
        # Check for errors in the log
        if grep -q "install-bank-of-z completed successfully" /tmp/remote-setup.log > /dev/null; then
            print_success "Remote setup completed successfully"
        else
            print_error "Setup completed but some warnings were detected"
            print_info "Review /tmp/remote-setup.log for details"
            exit 1
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
    load_config
    
    # Execute stages
    stage_initialize_remote_workspace
    stage_clone_bank_of_z
    stage_execute_common_setup
    
    # Summary
    print_stage "ORCHESTRATION COMPLETE"
}

# Run main function
main "$@"

# Made with Bob
