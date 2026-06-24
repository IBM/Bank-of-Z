#!/bin/bash

#########################################################
# Local Pipeline Orchestrator for Bank of Z
# This script runs on your LOCAL machine and uses Zowe CLI
# to coordinate pipeline execution on the remote z/OS USS system
#
# Used by: VSCode tasks workflow
#
# Purpose: Upload pipeline script and deploy configs, then execute remotely
#
# Usage: bash pipeline-local.sh
#########################################################

set -e  # Exit on error

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/config/setenv.sh"

# =========================
# Get pipeline parameters
# =========================
get_pipeline_parameters() {
    print_info "Getting pipeline parameters..."
    
    # Get current branch
    if git rev-parse --git-dir > /dev/null 2>&1; then
        GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
        print_info "Detected current branch: $GIT_BRANCH"
    else
        GIT_BRANCH="main"
        print_warning "Not in a git repository, using default branch: $GIT_BRANCH"
    fi
    
    # Get git repository
    if git rev-parse --git-dir > /dev/null 2>&1; then
        GIT_REPO=$(git remote get-url origin 2>/dev/null || echo "https://github.com/IBM/Bank-of-Z.git")
    else
        GIT_REPO="https://github.com/IBM/Bank-of-Z.git"
    fi
    
    # Get workspace from config
    BANK_OF_Z_WORK_DIR=$(get_section_value 'sandbox' 'path')
    BANK_DIR="$BANK_OF_Z_WORK_DIR/Bank-of-Z"
    
    print_success "Pipeline parameters loaded"
    echo "  Repository: $GIT_REPO"
    echo "  Branch: $GIT_BRANCH"
    echo "  Workspace: $BANK_OF_Z_WORK_DIR"
}

#########################################################
# STAGE: Execute Pipeline on Remote
#########################################################
stage_execute_pipeline() {
    print_stage "STAGE: Execute Pipeline on Remote"
    
    print_info "Executing pipeline-common.sh on remote z/OS USS..."
    print_info "This will:"
    print_info "  - Refresh git repository (pull latest)"
    print_info "  - Run DBB build"
    print_info "  - Deploy build"
    echo ""
    
    # Set environment variables for the remote execution
    local ENV_VARS="export GRUB='False'"
    ENV_VARS="$ENV_VARS && export GIT_REPOSITORY='$GIT_REPO'"
    ENV_VARS="$ENV_VARS && export GIT_BRANCH='$GIT_BRANCH'"
    ENV_VARS="$ENV_VARS && export BANK_OF_Z_WORK_DIR='$BANK_DIR'"
    
    # Execute the pipeline script on remote
    set -o pipefail
    
    if zowe rse-api-for-zowe-cli issue unix-shell "$ENV_VARS && bash $BANK_DIR/.setup/pipeline-remote.sh" --cwd "$BANK_OF_Z_WORK_DIR" 2>&1 | tee /tmp/pipeline.log; then
        # Check for errors in the log
        if grep -i "error\|failed\|RC=[^0]\|return code [^0]" /tmp/pipeline.log | grep -v -E "Failed to change files and directory owner with chown|BGZZB0021E" > /dev/null; then
            print_warning "Pipeline completed but some warnings were detected"
            print_info "Review /tmp/pipeline.log for details"
        else
            print_success "Remote pipeline completed successfully"
        fi
    else
        print_error "Failed to execute pipeline on remote system"
        print_info "Check /tmp/pipeline.log for details"
        exit 1
    fi
}

#########################################################
# Main execution
#########################################################
main() {
    echo ""
    echo -e "${GREEN}######################################################${NC}"
    echo -e "${GREEN}#  Bank of Z - Pipeline Orchestrator (Zowe CLI)      #${NC}"
    echo -e "${GREEN}######################################################${NC}"
    echo ""
    
    print_info "This script runs on your LOCAL machine"
    print_info "It uses Zowe CLI to coordinate pipeline execution on remote z/OS USS"
    echo ""
    
    # Check prerequisites
    check_zowe_cli
    
    # Get pipeline parameters
    get_pipeline_parameters
    
    # Execute stages
    stage_execute_pipeline
    
    # Summary
    print_stage "PIPELINE ORCHESTRATION COMPLETE"
    print_success "Remote pipeline execution completed successfully!"
    
    echo ""
    echo "Next steps:"
    echo "  1. Verify CICS region is updated"
    echo "  2. Test application changes via x3270:"
    echo "     - logon applid(CICSBOZ)"
    echo "     - Transaction: OMEN"
    echo "     - Customer: 1, Account: 1234"
    echo "  3. Review build logs if needed"
    echo ""
    print_info "Pipeline logs available at: /tmp/pipeline.log"
    echo ""
}

# Run main function
main "$@"

# Made with Bob