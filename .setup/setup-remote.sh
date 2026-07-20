#!/bin/bash

#########################################################
# Remote Setup Script for Bank of Z
# This script runs on the REMOTE z/OS USS machine
# and orchestrates the common setup phases.
#
# Used by: setup-local.sh (invoked via Zowe CLI)
#          GRUB workflow (run natively on USS)
#
# Usage: bash setup-remote.sh [workspace_path]
#########################################################

set -e  # Exit on error

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/config/setenv.sh" "$@"
chmod +x $(find . -name "*.sh" -type f) 2>/dev/null || true

#########################################################
# STAGE: Execute Common Setup Phases
#########################################################
stage_execute_common_setup() {
    print_stage "STAGE: Execute Common Setup Phases"
    
    print_info "Executing setup-common.sh phases..."
    print_info "This will:"
    print_info "  - Initialize workspace"
    print_info "  - Clone DBB accelerators"
    print_info "  - Deploy zBuilder framework"
    print_info "  - Install Bank of Z application"
    echo ""
    
    # Execute each phase of setup-common.sh
    print_info "Running: setup-common.sh"

    if [[ "$EXECUTION_MODE" != "grub" ]]; then
        ${SCRIPTS_DIR}/setup-common.sh validate-prereqs "$BANK_OF_Z_WORK_DIR" &
        PID=$!
        # Wait for deployment to complete (ZOAU/ZOWE ISSUE)
        wait "$PID"
        RC=$?
    else
        ${SCRIPTS_DIR}/setup-common.sh validate-prereqs "$BANK_OF_Z_WORK_DIR"
        RC=$?
    fi
    if [[ $RC -eq 0 ]]; then
        print_success "validate-prereqs completed successfully"
    else
        print_error "Failed to execute validate-prereqs"
        exit 1
    fi
    
    if [[ "$EXECUTION_MODE" != "grub" ]]; then
        ${SCRIPTS_DIR}/setup-common.sh environment "$BANK_OF_Z_WORK_DIR" &
        PID=$!
        # Wait for deployment to complete (ZOAU/ZOWE ISSUE)
        wait "$PID"
        RC=$?
    else
       ${SCRIPTS_DIR}/setup-common.sh environment "$BANK_OF_Z_WORK_DIR"
        RC=$?
    fi
    if [[ $RC -eq 0 ]]; then
        print_success "environment completed successfully"
    else
        print_error "Failed to execute environment"
        exit 1
    fi
    
    if [[ "$EXECUTION_MODE" != "grub" ]]; then
        ${SCRIPTS_DIR}/setup-common.sh install-bank-of-z "$BANK_OF_Z_WORK_DIR" &
        PID=$!
        # Wait for deployment to complete (ZOAU/ZOWE ISSUE)
        wait "$PID"
        RC=$?
    else
        ${SCRIPTS_DIR}/setup-common.sh install-bank-of-z "$BANK_OF_Z_WORK_DIR"
        RC=$?
    fi
    
    if [[ $RC -eq 0 ]]; then
        print_success "install-bank-of-z completed successfully"
    else
        print_error "Failed to execute install-bank-of-z"
        exit 1
    fi

}

#########################################################
# Main execution
#########################################################
main() {
    echo ""
    echo -e "${GREEN}######################################################${NC}"
    echo -e "${GREEN}#  Bank of Z - Remote Setup Script (z/OS USS)        #${NC}"
    echo -e "${GREEN}######################################################${NC}"
    echo ""
    
    print_info "This script runs on the remote machine"
    echo ""
    
    # Load configuration
    load_config
    
    # Detect Execution Mode
    detect_bank_of_z_location
    
    # Execute stages
    stage_execute_common_setup
    
    # Summary
    print_stage "ORCHESTRATION COMPLETE"
    print_success "Remote environment setup completed successfully!"
    
    # Purge all ended jobs
    opercmd '$POJQ,JM=*' 2>&1 > /dev/null || true
    
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