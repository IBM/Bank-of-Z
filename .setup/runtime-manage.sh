#!/usr/bin/env bash

#########################################################
# Runtime Management Script for Bank of Z
# This script runs directly on z/OS USS (not remotely)
#
# Manages the lifecycle (stop / start / restart) of the
# Bank of Z runtime servers WITHOUT touching any datasets
# or application data.
#
# Used when the z/OS infrastructure is restarted and the
# Bank of Z tasks need to be brought back up manually.
#
# Delegates to:
#   .setup/setup/servers-stop.sh
#   .setup/setup/servers-start.sh
#
# Usage:
#   bash runtime-manage.sh <action> [scope]
#
# Actions:
#   stop      Stop all servers (no data deletion)
#   start     Start all servers
#   restart   Stop then start all servers
#
# Scope (optional, default: --all):
#   --all           IMS + CICS + z/OS Connect + Frontend
#   --ims-only      IMS control tasks + IRLM + app regions only
#   --cics-only     CICS region only
#   --frontend-only z/OS Connect + Frontend Liberty only
#
# Examples:
#   bash runtime-manage.sh stop
#   bash runtime-manage.sh start --ims-only
#   bash runtime-manage.sh restart
#########################################################

set -e

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/config/setenv.sh"

#########################################################
# Usage
#########################################################
print_usage() {
    echo "Usage: bash runtime-manage.sh <action> [scope]"
    echo ""
    echo "Actions:"
    echo "  stop      Stop all servers (no data deletion)"
    echo "  start     Start all servers"
    echo "  restart   Stop then start all servers"
    echo ""
    echo "Scope (optional, default: --all):"
    echo "  --all           IMS + CICS + z/OS Connect + Frontend  (default)"
    echo "  --ims-only      IMS control tasks + IRLM + app regions only"
    echo "  --cics-only     CICS region only"
    echo "  --frontend-only z/OS Connect + Frontend Liberty only"
    echo ""
    echo "Examples:"
    echo "  bash runtime-manage.sh stop"
    echo "  bash runtime-manage.sh start --ims-only"
    echo "  bash runtime-manage.sh restart"
    echo ""
    echo "Environment variables:"
    echo "  IMS_DISABLED   Set to true to skip all IMS tasks (default: false)"
}

#########################################################
# Main
#########################################################
main() {
    local action="${1:-}"
    local scope_flag="${2:---all}"

    # Validate scope
    case "${scope_flag#--}" in
        all|ims-only|cics-only|frontend-only) ;;
        *)
            print_error "Unknown scope: ${scope_flag}"
            echo ""
            print_usage
            exit 1
            ;;
    esac

    # Detect repo location (sets BANK_DIR, EXECUTION_MODE)
    detect_bank_of_z_location

    local stop_script="$BANK_DIR/.setup/setup/servers-stop.sh"
    local start_script="$BANK_DIR/.setup/setup/servers-start.sh"

    case "$action" in
        stop)
            print_stage "ACTION: Stop Bank of Z servers (scope: ${scope_flag#--})"
            if [ ! -f "$stop_script" ]; then
                print_error "Stop script not found: $stop_script"
                exit 1
            fi
            print_info "Executing: bash $stop_script $scope_flag"
            bash "$stop_script" "$scope_flag"
            print_stage "STOP COMPLETE"
            print_success "All requested servers have been stopped."
            ;;
        start)
            print_stage "ACTION: Start Bank of Z servers (scope: ${scope_flag#--})"
            if [ ! -f "$start_script" ]; then
                print_error "Start script not found: $start_script"
                exit 1
            fi
            print_info "Executing: bash $start_script $scope_flag"
            bash "$start_script" "$scope_flag"
            print_stage "START COMPLETE"
            print_success "All requested servers have been started."
            ;;
        restart)
            print_stage "ACTION: Restart Bank of Z servers (scope: ${scope_flag#--})"
            if [ ! -f "$stop_script" ]; then
                print_error "Stop script not found: $stop_script"
                exit 1
            fi
            if [ ! -f "$start_script" ]; then
                print_error "Start script not found: $start_script"
                exit 1
            fi
            print_info "Executing: bash $stop_script $scope_flag"
            bash "$stop_script" "$scope_flag"
            print_info "Executing: bash $start_script $scope_flag"
            bash "$start_script" "$scope_flag"
            print_stage "RESTART COMPLETE"
            print_success "All requested servers have been restarted."
            ;;
        -h|--help|help|"")
            print_usage
            ;;
        *)
            print_error "Unknown action: $action"
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
