#!/usr/bin/env bash

#########################################################
# Common Pipeline Script for Bank of Z
# This script runs directly on z/OS USS (not remotely)
# 
# Used by:
#   - GRUB workflow (runs natively after sync)
#   - VSCode task workflow (triggered via Zowe CLI)
#
# Purpose: Rebuild and redeploy Bank of Z application
#
# Usage: bash pipeline-common.sh
#########################################################

set -e  # Exit on error

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LIB_DIR="$SCRIPTS_DIR/lib"
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/prerequisites.sh"

# =========================
# Detect execution context
# =========================
detect_execution_mode() {
    # Check if running from within Bank-of-Z repository
    if git rev-parse --git-dir > /dev/null 2>&1; then
        local repo_name=$(basename "$(git rev-parse --show-toplevel)")
        if [[ "$repo_name" == "Bank-of-Z" ]]; then
            EXECUTION_MODE="grub"
            WORKSPACE_DIR="$(git rev-parse --show-toplevel)"
            print_info "Execution mode: GRUB (running from repository)"
        else
            EXECUTION_MODE="unknown"
            print_warning "Running from git repository but not Bank-of-Z"
        fi
    else
        # Not in a git repo, assume VSCode workflow with cloned repo
        EXECUTION_MODE="vscode"
        # Workspace should be set by orchestrator or use current directory
        WORKSPACE_DIR="${PIPELINE_WORKSPACE:-$(pwd)}"
        print_info "Execution mode: VSCode (orchestrated)"
    fi
    
    print_info "Workspace directory: $WORKSPACE_DIR"
}

# =========================
# Get pipeline parameters
# =========================
get_pipeline_parameters() {
    print_stage "Pipeline Parameters"
    
    # Get temporary HLQ
    TMPHLQ=$(printf '%s' "${PIPELINE_TMPHLQ:-$(basename "$HOME")}" | tr '[:lower:]' '[:upper:]')
    
    # Get git information
    if [ "$EXECUTION_MODE" = "grub" ]; then
        # Try to get remote URL, fallback to defaults if remote doesn't exist
        if git remote get-url origin > /dev/null 2>&1; then
            gitRepository=$(git remote get-url origin | sed 's#.*/##' | sed 's/\.git$//')
        else
            gitRepository="${GIT_REPOSITORY:-Bank-of-Z}"
        fi
        branchName=$(git branch --show-current)
    else
        # For VSCode workflow, use environment variables or defaults
        gitRepository="${GIT_REPOSITORY:-Bank-of-Z}"
        branchName="${GIT_BRANCH:-main}"
    fi
    
    echo "  Git Repository: $gitRepository"
    echo "  Branch: $branchName"
    echo "  Temporary HLQ: $TMPHLQ"
    echo "  Workspace: $WORKSPACE_DIR"
    echo ""
}

# =======================================
# Stage 1: Refresh git (VSCode only)
# =======================================
stage1_refresh_git() {
    print_stage "STAGE 1: Refresh Git Repository"
    
    if [ "$EXECUTION_MODE" = "grub" ]; then
        print_info "GRUB mode: Skipping git refresh (already synced)"
        return 0
    fi
    
    print_info "VSCode mode: Refreshing git repository..."
    cd "$WORKSPACE_DIR"
    
    if git rev-parse --git-dir > /dev/null 2>&1; then
        print_info "Resetting and pulling latest changes..."
        git reset --hard
        # Only pull if remote exists
        if git remote get-url origin > /dev/null 2>&1; then
            git pull
            print_success "Git repository refreshed"
        else
            print_warning "No remote configured, skipping pull"
            print_success "Git repository reset"
        fi
    else
        print_warning "Not a git repository, skipping refresh"
    fi
}

# =======================================
# Stage 2: DBB Build
# =======================================
stage2_dbb_build() {
    print_stage "STAGE 2: DBB Build"
    
    cd "$SCRIPTS_DIR"
    
    if [ ! -f "tasks/task-dbb-build.sh" ]; then
        print_error "DBB build task not found: tasks/task-dbb-build.sh"
        exit 1
    fi
    
    print_info "Executing DBB build task..."
    bash tasks/task-dbb-build.sh
    
    print_success "DBB build completed"
}

# =======================================
# Stage 3: Deploy Build
# =======================================
stage3_deploy_build() {
    print_stage "STAGE 3: Deploy Build"
    
    cd "$SCRIPTS_DIR"
    
    if [ ! -f "tasks/task-wazi-deploy.sh" ]; then
        print_error "Wazi deploy task not found: tasks/task-wazi-deploy.sh"
        exit 1
    fi
    
    print_info "Executing Wazi deploy task..."
    
    # Run deploy in background to handle ZOAU/ZOWE issues
    bash tasks/task-wazi-deploy.sh &
    PID=$!
    
    # Wait for deployment to complete
    wait $PID
    RC=$?
    
    if [ $RC -eq 0 ]; then
        print_success "Deployment completed successfully"
    else
        print_error "Deployment failed with RC=$RC"
        exit $RC
    fi
}

#########################################################
# Main execution
#########################################################
main() {
    echo ""
    echo -e "${GREEN}######################################################${NC}"
    echo -e "${GREEN}#  Bank of Z - Pipeline Simulation (z/OS USS)        #${NC}"
    echo -e "${GREEN}######################################################${NC}"
    echo ""
    
    # Detect execution mode
    detect_execution_mode
    
    # Get pipeline parameters
    get_pipeline_parameters
    
    # Execute stages
    stage1_refresh_git
    stage2_dbb_build
    stage3_deploy_build
    
    # Summary
    print_stage "PIPELINE COMPLETE"
    print_success "Pipeline simulation completed successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Verify CICS region is updated"
    echo "  2. Test application changes via x3270"
    echo "  3. Review build logs if needed"
    echo ""
}

# Run main function
main "$@"

# Made with Bob