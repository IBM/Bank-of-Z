#!/usr/bin/env bash

#########################################################
# Common Setup Script for Bank of Z
# This script runs directly on z/OS USS (not remotely)
# 
# Used by:
#   - GRUB workflow (runs natively after sync)
#   - VSCode task workflow (triggered via Zowe CLI)
#
# Usage: bash pipeline-common.sh [workspace_path]
#########################################################

set -e  # Exit on error

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/config/setenv.sh"

#########################################################
# STAGE: Static scan Bank of Z
#########################################################
stage_static_scan_bank_of_z() {
    print_stage "STAGE: Static scan Bank of Z"
    
    # Verify installation script exists
    if [ ! -f "$BANK_DIR/.setup/tasks/task-zcodescan-static-scan.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/tasks/task-zcodescan-static-scan.sh"
        exit 1
    fi
    
    # Run zcode scan task
    print_info "Running Bank of Z static scan script..."
    print_info "Executing: bash $BANK_DIR/.setup/tasks/task-zcodescan-static-scan.sh"
    cd "$BANK_DIR"
    
    set -o pipefail
    if ${BANK_DIR}/.setup/tasks/task-zcodescan-static-scan.sh; then
        print_success "Bank of Z application static scan completed successfully"
    else
        print_error "Failed to static scan Bank of Z"
        exit 1
    fi
}

#########################################################
# STAGE: Build Bank of Z
#########################################################
stage_build_bank_of_z() {
    print_stage "STAGE: Build Bank of Z"
    
    # Verify installation script exists
    if [ ! -f "$BANK_DIR/.setup/tasks/task-dbb-build.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/tasks/task-dbb-build.sh"
        exit 1
    fi
    
    # Run installation script
    print_info "Running Bank of Z build script..."
    print_info "Executing: bash $BANK_DIR/.setup/tasks/task-dbb-build.sh $1"
    cd "$BANK_DIR"
    
    set -o pipefail
    if bash ${BANK_DIR}/.setup/tasks/task-dbb-build.sh $1; then
        print_success "Bank of Z application build completed successfully"
    else
        print_error "Failed to build Bank of Z"
        exit 1
    fi
}

#########################################################
# STAGE: Deploy Bank of Z
#########################################################
stage_deploy_bank_of_z() {
    print_stage "STAGE: Deploy Bank of Z"
    
    # Verify installation script exists
    if [ ! -f "$BANK_DIR/.setup/tasks/task-wazi-deploy.sh" ]; then
        print_error "Installation script not found: $BANK_DIR/.setup/tasks/task-wazi-deploy.sh"
        exit 1
    fi
    
    # Run installation script
    print_info "Running Bank of Z deploy script..."
    print_info "Executing: bash $BANK_DIR/.setup/tasks/task-wazi-deploy.sh"
    cd "$BANK_DIR"
    
    set -o pipefail
    ${BANK_DIR}/.setup/tasks/task-wazi-deploy.sh&
    PID=$!
    # Wait for deployment to complete (ZOAU/ZOWE ISSUE)
    if wait "$PID"; then
        print_success "Bank of Z application deploy completed successfully"
    else
        print_error "Failed to deploy Bank of Z"
        exit 1
    fi
}


#########################################################
# Main execution helpers
#########################################################
print_phase_next_step() {
    local completed_phase="$1"

    echo ""
    case "$completed_phase" in
        validation)
            print_info "Next step: run this script in pipeline mode to initialize the workspace and infrastructure prerequisites."
            ;;
        pipeline)
            print_info "Next step: run this script in build-baseline mode to build and deploy the Bank of Z baseline."
            ;;
        build-baseline)
            print_info "Next step: baseline deployment is complete. Proceed with application verification or follow-on customization."
            ;;
    esac
}

print_usage() {
    echo "Usage: bash pipeline-common.sh <phase>"
    echo ""
    echo "Phases:"
    echo "  validate-prereqs  Validate prerequisites (zConfig, DBB, wazi-deploy)"
    echo "  build             Build the Bank of Z baseline"
    echo "  deploy            Deploy the Bank of Z baseline"
    echo "  build-and-deploy  Build and deploy the Bank of Z updates"
    echo ""
    echo "Examples:"
    echo "  bash pipeline-common.sh validate-prereqs"
    echo "  bash pipeline-common.sh build"
    echo "  bash pipeline-common.sh deploy"
    echo "  bash pipeline-common.sh build-and-deploy"
}

print_phase_next_step() {
    local completed_phase="$1"

    echo ""
    case "$completed_phase" in
        validation)
            print_info "Next step: Execute ZCodeScan for Bank of Z."
            ;;
        static-scan)
            print_info "Next step: build Bank of Z."
            ;;
        build)
            print_info "Next step: deploy Bank of Z."
            ;;
    esac
}

#########################################################
# Main execution
#########################################################
main_validation() {
    echo ""
    SYS=$(uname -Ia)
    print_info "Running on: $SYS"
    echo ""

    # Summary
    print_stage "VALIDATION COMPLETE"
    print_success "Environment validation completed successfully!"
    print_phase_next_step "validation"
}

main_static_scan() {
    echo ""
    SYS=$(uname -Ia)
    print_info "Running on: $SYS"
    echo ""

    stage_static_scan_bank_of_z

    # Summary
    print_stage "STATIC SCAN COMPLETE"
    print_success "STATIC SCAN  setup completed successfully!"
    print_phase_next_step "static-scan"
}

main_build() {
    echo ""
    SYS=$(uname -Ia)
    print_info "Running on: $SYS"
    echo ""

    stage_build_bank_of_z $*

    # Summary
    print_stage "BUILD COMPLETE"
    print_success "Build completed successfully!"
    print_phase_next_step "build"
}

main_deploy() {
    echo ""
    SYS=$(uname -Ia)
    print_info "Running on: $SYS"
    echo ""

    stage_deploy_bank_of_z

    # Summary
    print_stage "DEPLOY COMPLETE"
    print_success "DEPLOY setup completed successfully!"
}

#########################################################
# Main execution
#########################################################

main() {
    local phase="${1:-}"

    # Detect Execution Mode
    detect_bank_of_z_location

    case "$phase" in
        validate-prereqs)
            main_validation
            ;;
        scan)
            shift
            main_static_scan
            ;;
        build)
            shift  # Remove 'build' from parameters
            main_build "$@"
            ;;
        deploy)
            main_deploy
            ;;
        build-and-deploy)
            shift  # Remove 'build-and-deploy' from parameters
            main_build "$@"
            main_deploy
            ;;
        scan-build-and-deploy)
            shift  # Remove 'scan-build-and-deploy' from parameters
            main_static_scan
            main_build "$@"
            main_deploy
            ;;
        -h|--help|help|"")
            print_usage
            ;;
        *)
            print_error "Unknown phase: $phase"
            echo ""
            print_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
exit $?

# Made with Bob