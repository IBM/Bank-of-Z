#!/bin/bash

#########################################################
# Remoyes Pipeline Orchestrator for Bank of Z
# This script runs on the remote z/OS USS system
# Usage: bash pipeline-remote.sh
#########################################################

set -e  # Exit on error

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/config/setenv.sh"


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
    
    if [[ "$EXECUTION_MODE" != "grub" ]]; then
        cd $SCRIPTS_DIR
        git reset --hard
        git pull
    fi
    
    # Execute the pipeline script on remote
    set -o pipefail
    
    chmod +x ${SCRIPTS_DIR}/pipeline-common.sh
    bash ${SCRIPTS_DIR}/pipeline-common.sh build-and-deploy&
    PID=$!
    # Wait for deployment to complete (ZOAU/ZOWE ISSUE)
    if wait "$PID"; then
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