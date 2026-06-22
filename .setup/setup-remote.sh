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
rm -f  "$SCRIPTS_DIR/config/.env"
source "$SCRIPTS_DIR/config/setenv.sh" "$@"


#########################################################
# STAGE: Execute Common Setup Script on Remote
#########################################################
stage_execute_common_setup() {
    print_stage "STAGE: Execute Common Setup Script on Remote"
    
    print_info "Executing setup-common.sh on remote z/OS USS..."
    print_info "This will:"
    print_info "  - Initialize workspace"
    print_info "  - Clone DBB accelerators"
    print_info "  - Deploy zBuilder framework"
    print_info "  - Install Bank of Z application"
    echo ""
    
    # Execute the common setup script on remote
    print_info "Running: bash .setup/setup-common.sh"
    
    ${SCRIPTS_DIR}/setup-common.sh validate-prereqs "$BANK_OF_Z_WORK_DIR" &
    PID=$!
    # Wait for deployment to complete (ZOAU/ZOWE ISSUE)
    if wait "$PID"; then
        print_success "Remote validate-prereqs completed successfully"
    else
        print_error "Failed to execute validate-prereqs on remote system"
        exit 1
    fi
    
    ${SCRIPTS_DIR}/setup-common.sh environment "$BANK_OF_Z_WORK_DIR" &
    PID=$!
    # Wait for deployment to complete (ZOAU/ZOWE ISSUE)
    if wait "$PID"; then
        print_success "Remote environment completed successfully"
    else
        print_error "Failed to execute environment on remote system"
        exit 1
    fi
    
    ${SCRIPTS_DIR}/setup-common.sh install-bank-of-z "$BANK_OF_Z_WORK_DIR" &
    PID=$!
    # Wait for deployment to complete (ZOAU/ZOWE ISSUE)
    if wait "$PID"; then
        print_success "Remote install-bank-of-z completed successfully"
    else
        print_error "Failed to execute install-bank-of-z on remote system"
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
    
    print_info "This script runs on the remote machine"
    echo ""
    
    # Load configuration
    load_config
    
    # Execute stages
    stage_execute_common_setup
    
    # Summary
    print_stage "ORCHESTRATION COMPLETE"
    print_success "Remote environment setup completed successfully!"
    
    echo ""
    echo "Next steps:"
    echo "  1. Review the setup on remote USS: $BANK_OF_Z_WORK_DIR"
    echo "  2. Check the Bank of Z installation"
    echo "  3. Connect to CICS using x3270:"
    echo "     - Enter 'logon applid(CICSBOZ)'"
    echo "     - Enter 'OMEN' as transaction name"
    echo "     - Enter 1 then 1234 as customer"
    echo "  4. Run pipeline builds from VSCode tasks"
    echo ""
    print_info "Remote setup logs available at: /tmp/remote-setup.log"
    echo ""
}

# Run main function
main "$@"

# Made with Bob