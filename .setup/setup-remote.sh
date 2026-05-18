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
    
    set -o pipefail
    if bash ${SCRIPTS_DIR}/setup-common.sh $PIPELINE_WORKSPACE 2>&1 | tee /tmp/remote-setup.log; then
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
    echo -e "${GREEN}#  Bank of Z - Remote Orchestrator (Zowe CLI)         #${NC}"
    echo -e "${GREEN}######################################################${NC}"
    echo ""
    
    print_info "This script runs on the remote machine"
    echo ""
    
    # Execute stages
    stage_execute_common_setup
    
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
