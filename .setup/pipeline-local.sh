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
    PIPELINE_WORKSPACE=$(get_section_value 'sandbox' 'path')
    BANK_DIR="$PIPELINE_WORKSPACE/Bank-of-Z"
    
    print_success "Pipeline parameters loaded"
    echo "  Repository: $GIT_REPO"
    echo "  Branch: $GIT_BRANCH"
    echo "  Workspace: $PIPELINE_WORKSPACE"
}

#########################################################
# STAGE 1: Upload Pipeline Script
#########################################################
stage1_upload_pipeline_script() {
    print_stage "STAGE 1: Upload Pipeline Script"
    
    local PIPELINE_SCRIPT_SOURCE="$SCRIPTS_DIR/pipeline-common.sh"
    local PIPELINE_SCRIPT_TARGET="$BANK_DIR/.setup/pipeline-common.sh"
    local SCRIPT_PARENT_DIR=$(dirname "$PIPELINE_SCRIPT_TARGET")
    
    # Ensure parent directory exists
    print_info "Ensuring parent directory exists: $SCRIPT_PARENT_DIR"
    zowe rse-api-for-zowe-cli create uss-directory "$SCRIPT_PARENT_DIR" &> /dev/null || true
    
    # Delete existing file if it exists
    print_info "Removing existing pipeline script if present..."
    zowe rse-api-for-zowe-cli delete uss-file "$PIPELINE_SCRIPT_TARGET" &> /dev/null || true
    
    # Upload the script
    print_info "Uploading pipeline script to USS..."
    if zowe rse-api-for-zowe-cli upload file-to-uss "$PIPELINE_SCRIPT_SOURCE" "$PIPELINE_SCRIPT_TARGET" --encoding IBM-1047; then
        # Make script executable
        print_info "Making script executable..."
        zowe rse-api-for-zowe-cli issue unix "chmod +x pipeline-common.sh" --cwd "$SCRIPT_PARENT_DIR"
        print_success "Pipeline script uploaded successfully"
    else
        print_error "Failed to upload pipeline script"
        exit 1
    fi
}

#########################################################
# STAGE 2: Upload Deploy Scripts
#########################################################
stage2_upload_deploy_scripts() {
    print_stage "STAGE 2: Upload Deploy Scripts"
    
    local DEPLOY_SOURCE="$SCRIPTS_DIR/deploy"
    local DEPLOY_TARGET="$BANK_DIR/.setup/deploy"
    
    if [ ! -d "$DEPLOY_SOURCE" ]; then
        print_warning "Deploy directory not found: $DEPLOY_SOURCE"
        print_info "Skipping deploy scripts upload"
        return 0
    fi
    
    print_info "Uploading deploy scripts to USS..."
    if zowe rse-api-for-zowe-cli upload dir-to-uss "$DEPLOY_SOURCE" "$DEPLOY_TARGET" --encoding UTF-8; then
        print_success "Deploy scripts uploaded successfully"
    else
        print_error "Failed to upload deploy scripts"
        exit 1
    fi
}

#########################################################
# STAGE 3: Execute Pipeline on Remote
#########################################################
stage3_execute_pipeline() {
    print_stage "STAGE 3: Execute Pipeline on Remote"
    
    print_info "Executing pipeline-common.sh on remote z/OS USS..."
    print_info "This will:"
    print_info "  - Refresh git repository (pull latest)"
    print_info "  - Run DBB build"
    print_info "  - Deploy to CICS"
    echo ""
    
    # Set environment variables for the remote execution
    local ENV_VARS="export GRUB='False'"
    ENV_VARS="$ENV_VARS && export GIT_REPOSITORY='$GIT_REPO'"
    ENV_VARS="$ENV_VARS && export GIT_BRANCH='$GIT_BRANCH'"
    ENV_VARS="$ENV_VARS && export PIPELINE_WORKSPACE='$BANK_DIR'"
    
    # Execute the pipeline script on remote
    set -o pipefail
    
    if zowe rse-api-for-zowe-cli issue unix-shell "$ENV_VARS && bash .setup/pipeline-common.sh" --cwd "$BANK_DIR" 2>&1 | tee /tmp/pipeline.log; then
        # Check for errors in the log
        if grep -i "error\|failed\|RC=[^0]\|return code [^0]" /tmp/pipeline.log | grep -v "Failed to change files and directory owner with chown" > /dev/null; then
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
    stage1_upload_pipeline_script
    stage2_upload_deploy_scripts
    stage3_execute_pipeline
    
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