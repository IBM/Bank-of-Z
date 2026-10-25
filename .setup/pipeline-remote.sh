#!/bin/bash

#########################################################
# Remote Pipeline Orchestrator for Bank of Z
# This script runs on the remote z/OS USS system
# Usage: bash pipeline-remote.sh
#########################################################

set -e  # Exit on error

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/config/setenv.sh"
chmod +x $(find . -name "*.sh" -type f) 2>/dev/null || true

#########################################################
# STAGE: Execute Pipeline on Remote
#########################################################
stage_execute_pipeline() {
    print_stage "STAGE: Execute Pipeline on Remote"
    
    print_info "Executing pipeline-common.sh on remote z/OS USS..."
    print_info "This will:"
    if [[ "$EXECUTION_MODE" != "grub" ]]; then
        print_info "  - Refresh git repository (pull latest)"
    fi
    print_info "  - Run static scan"
    print_info "  - Run DBB build"
    print_info "  - Deploy build"
    echo ""
    
    # Execute the pipeline script on remote
    set -o pipefail
    if [[ "$EXECUTION_MODE" != "grub" ]]; then
        ${SCRIPTS_DIR}/pipeline-common.sh scan-build-and-deploy "$@" &
        PID=$!
        # Wait for deployment to complete (ZOAU/ZOWE ISSUE)
        wait "$PID"
        RC=$?
    else
        ${SCRIPTS_DIR}/pipeline-common.sh scan-build-and-deploy "$@"
        RC=$?
    fi
    if [[ $RC -eq 0 ]]; then
        print_success "Remote pipeline completed successfully"
    else
        print_error "Failed to execute pipeline on remote system"
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
    
    # Load configuration
    load_config
    
    # Detect Execution Mode
    detect_bank_of_z_location
    
    # Execute stages
    stage_execute_pipeline "$@"
    
    # Summary
    print_stage "PIPELINE ORCHESTRATION COMPLETE"
    print_success "Remote pipeline execution completed successfully!"
    
    echo ""
    ipaddr=$(get_ipaddr)
    print_info "The Bank of Z interface is available at:"
    print_info "- https://${ipaddr}:${FRONTEND_HTTPS_PORT}/"
    print_info "(Please allow about 20s for the interface to become available)"
    echo ""
}

# Run main function
main "$@"

# Made with Bob
