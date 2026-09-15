#!/usr/bin/env bash

#########################################################
# runtime-manage.sh — Bank of Z runtime lifecycle manager
# This script runs directly on z/OS USS (not remotely)
#
# Manages the lifecycle (stop / start / restart) of the
# Bank of Z runtime servers WITHOUT touching any datasets
# or application data.
#
# Used when the z/OS infrastructure is restarted and the
# Bank of Z tasks need to be brought back up manually.
#
# Usage:
#   bash runtime-manage.sh <action> <scope>
#
# Actions:
#   stop      Stop servers (no data deletion)
#   start     Start servers
#   restart   Stop then start servers
#
# Scopes (required — no default):
#   all        IMS + CICS + z/OS Connect + Frontend
#   ims        IMS control tasks + IRLM + app regions
#   cics       CICS region
#   frontend   z/OS Connect + Frontend Liberty
#
# Examples:
#   bash runtime-manage.sh stop all
#   bash runtime-manage.sh start ims
#   bash runtime-manage.sh restart cics
#   bash runtime-manage.sh restart frontend
#
# Environment variables:
#   IMS_DISABLED   Set to true to skip all IMS tasks (default: false)
#########################################################

set -e

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/config/setenv.sh"

# =========================
# Environment
# =========================
export PATH="${ZOAU_HOME:-}/bin:$PATH"
export LIBPATH="${ZOAU_HOME:-}/lib:${LIBPATH:-}"

#########################################################
# Usage
#########################################################
print_usage() {
    echo "Usage: bash runtime-manage.sh <action> <scope>"
    echo ""
    echo "Actions:"
    echo "  stop      Stop servers (no data deletion)"
    echo "  start     Start servers"
    echo "  restart   Stop then start servers"
    echo ""
    echo "Scopes (required):"
    echo "  all        IMS + CICS + z/OS Connect + Frontend"
    echo "  ims        IMS control tasks + IRLM + app regions"
    echo "  cics       CICS region"
    echo "  frontend   z/OS Connect + Frontend Liberty"
    echo ""
    echo "Examples:"
    echo "  bash runtime-manage.sh stop all"
    echo "  bash runtime-manage.sh start ims"
    echo "  bash runtime-manage.sh restart cics"
    echo ""
    echo "Environment variables:"
    echo "  IMS_DISABLED   Set to true to skip all IMS tasks (default: false)"
}

#########################################################
# Stop z/OS Connect and Frontend Liberty servers
#########################################################
stop_frontend() {
    print_stage "STAGE: Stop z/OS Connect and Frontend Liberty servers"
    set +e

    print_info "Cancelling BAQ${APP_SHORT_NAME} (z/OS Connect)..."
    jcan P "BAQ${APP_SHORT_NAME}" 2>/dev/null || true
    opercmd "C BAQ${APP_SHORT_NAME}" 2>/dev/null || true

    print_info "Cancelling FE${APP_SHORT_NAME} (Frontend Liberty)..."
    jcan P "FE${APP_SHORT_NAME}" 2>/dev/null || true
    opercmd "C FE${APP_SHORT_NAME}" 2>/dev/null || true
    sleep 2

    print_success "z/OS Connect and Frontend Liberty servers stopped"
    set -e
}

#########################################################
# Stop CICS region
#########################################################
stop_cics() {
    print_stage "STAGE: Stop CICS region"
    set +e

    # Check whether the CICS region is currently active
    if opercmd "D A,CICS${APP_SHORT_NAME}" 2>/dev/null | grep -q "CICS${APP_SHORT_NAME}"; then
        print_info "CICS${APP_SHORT_NAME} is active — issuing graceful shutdown..."
        opercmd "F CICS${APP_SHORT_NAME},CEMT PERFORM SHUTDOWN" 2>/dev/null || true
        sleep 10

        # Cancel only if still active after graceful shutdown attempt
        if opercmd "D A,CICS${APP_SHORT_NAME}" 2>/dev/null | grep -q "CICS${APP_SHORT_NAME}"; then
            print_info "CICS${APP_SHORT_NAME} still active — issuing cancel..."
            opercmd "C CICS${APP_SHORT_NAME}" 2>/dev/null || true
            sleep 2
        fi
    else
        print_info "CICS${APP_SHORT_NAME} is not active — skipping"
    fi

    print_success "CICS region stopped"
    set -e
}

#########################################################
# Stop IMS application regions (MPP / JMP)
#########################################################
stop_ims_regions() {
    print_stage "STAGE: Stop IMS application regions (MPP / JMP)"
    set +e

    print_info "Removing stale STOPMPP1 / STOPMPP2 / STOPJMP members..."
    mrm "${IMS_APP_HLQ}.JOBS(STOPMPP1)"         2>/dev/null || true
    mrm "${IMS_APP_HLQ}.JOBS(STOPMPP2)"         2>/dev/null || true
    mrm "${IMS_APP_HLQ}.IMSJAVA.JOBS(STOPJMP)"  2>/dev/null || true

    print_info "Submitting STOPMPP1 / STOPMPP2 / STOPJMP JCL..."
    jsub "${IMS_APP_HLQ}.JOBS(STOPMPP1)"         2>/dev/null || true
    jsub "${IMS_APP_HLQ}.JOBS(STOPMPP2)"         2>/dev/null || true
    jsub "${IMS_APP_HLQ}.IMSJAVA.JOBS(STOPJMP)"  2>/dev/null || true
    sleep 5

    print_info "Cancelling ${IMS_DATASTORE}JMP1 / MPP1 / MPP2 (if still active)..."
    jcan P "${IMS_DATASTORE}JMP1" 2>/dev/null || true
    jcan P "${IMS_DATASTORE}MPP1" 2>/dev/null || true
    jcan P "${IMS_DATASTORE}MPP2" 2>/dev/null || true
    sleep 5

    print_success "IMS application regions stopped"
    set -e
}

#########################################################
# Stop IMS control tasks + IRLM
#########################################################
stop_ims_control() {
    print_stage "STAGE: Stop IMS control tasks + IRLM"
    set +e

    print_info "Stopping ${IMS_DATASTORE}HWS..."
    opercmd "C ${IMS_DATASTORE}HWS" 2>/dev/null || true
    sleep 1

    print_info "Stopping ${IMS_DATASTORE}ODB..."
    opercmd "C ${IMS_DATASTORE}ODB" 2>/dev/null || true
    sleep 1

    print_info "Stopping ${IMS_DATASTORE}DRC..."
    opercmd "C ${IMS_DATASTORE}DRC" 2>/dev/null || true
    sleep 1

    print_info "Stopping ${IMS_DATASTORE}CTL..."
    opercmd "C ${IMS_DATASTORE}CTL" 2>/dev/null || true
    sleep 2

    print_info "Stopping ${IMS_DATASTORE}OM..."
    opercmd "C ${IMS_DATASTORE}OM" 2>/dev/null || true
    sleep 1

    print_info "Stopping ${IMS_DATASTORE}RM..."
    opercmd "C ${IMS_DATASTORE}RM" 2>/dev/null || true
    sleep 1

    print_info "Stopping ${IMS_DATASTORE}SCI..."
    opercmd "C ${IMS_DATASTORE}SCI" 2>/dev/null || true
    sleep 1

    print_info "Stopping ${IMS_DATABASE_LOCK_MANAGER_SERVER_NAME} (IRLM)..."
    opercmd "C ${IMS_DATABASE_LOCK_MANAGER_SERVER_NAME}" 2>/dev/null || true
    sleep 2

    print_success "IMS control tasks and IRLM stopped"
    set -e
}

#########################################################
# Start IMS control tasks + IRLM (warm restart)
#########################################################
start_ims_control() {
    print_stage "STAGE: Start IMS control tasks + IRLM (warm restart)"
    set +e

    print_info "Starting ${IMS_DATABASE_LOCK_MANAGER_SERVER_NAME} (IRLM)..."
    opercmd "S ${IMS_DATABASE_LOCK_MANAGER_SERVER_NAME}" 2>/dev/null || true
    sleep 2

    print_info "Starting ${IMS_DATASTORE}SCI..."
    opercmd "S ${IMS_DATASTORE}SCI" 2>/dev/null || true
    sleep 2

    print_info "Starting ${IMS_DATASTORE}OM..."
    opercmd "S ${IMS_DATASTORE}OM" 2>/dev/null || true
    sleep 2

    print_info "Starting ${IMS_DATASTORE}RM..."
    opercmd "S ${IMS_DATASTORE}RM" 2>/dev/null || true
    sleep 2

    print_info "Submitting ${IMS_APP_HLQ}.PROCLIB(${IMS_DATASTORE}CTL) via jsub..."
    jsub "${IMS_APP_HLQ}.PROCLIB(${IMS_DATASTORE}CTL)" 2>/dev/null || true

    print_info "Waiting for IMS CTL and dependent regions to initialise (30s)..."
    sleep 30

    print_info "Starting ${IMS_DATASTORE}ODB..."
    opercmd "S ${IMS_DATASTORE}ODB" 2>/dev/null || true
    sleep 2

    print_info "Starting ${IMS_DATASTORE}HWS..."
    opercmd "S ${IMS_DATASTORE}HWS" 2>/dev/null || true
    sleep 2

    print_success "IMS control tasks and IRLM started"
    set -e
}

#########################################################
# Start IMS application regions (MPP / JMP)
#########################################################
start_ims_regions() {
    print_stage "STAGE: Start IMS application regions (MPP / JMP)"
    set +e

    print_info "Submitting ${IMS_DATASTORE}MPP2..."
    jsub "${IMS_APP_HLQ}.JOBS(${IMS_DATASTORE}MPP2)" 2>/dev/null || true
    sleep 5

    print_info "Submitting ${IMS_DATASTORE}MPP1..."
    jsub "${IMS_APP_HLQ}.JOBS(${IMS_DATASTORE}MPP1)" 2>/dev/null || true
    sleep 5

    print_info "Submitting STARTJMP (JMP region)..."
    jsub "${IMS_APP_HLQ}.IMSJAVA.JOBS(STARTJMP)" 2>/dev/null || true
    sleep 5

    print_success "IMS application regions started"
    set -e
}

#########################################################
# Start CICS region
#########################################################
start_cics() {
    print_stage "STAGE: Start CICS region"
    set +e

    if [[ "$CICS_SYS_PROCLIB" != "${APP_HLQ}.PROCLIB" ]]; then
        print_info "Starting CICS${APP_SHORT_NAME} via opercmd (system PROCLIB)..."
        opercmd "S CICS${APP_SHORT_NAME}" 2>/dev/null || true
    else
        print_info "Starting CICS${APP_SHORT_NAME} via jsub (application PROCLIB)..."
        jsub "${APP_HLQ}.PROCLIB(CICS${APP_SHORT_NAME}J)" 2>/dev/null || true
    fi
    sleep 3

    print_success "CICS region start command issued"
    set -e
}

#########################################################
# Start z/OS Connect and Frontend Liberty servers
#########################################################
start_frontend() {
    print_stage "STAGE: Start z/OS Connect and Frontend Liberty servers"
    set +e

    if [[ "$ZOSCONNECT_SYS_PROCLIB" != "${APP_HLQ}.PROCLIB" ]]; then
        print_info "Starting BAQ${APP_SHORT_NAME} (z/OS Connect) via opercmd..."
        opercmd "S BAQ${APP_SHORT_NAME}" 2>/dev/null || true
    else
        print_info "Starting BAQ${APP_SHORT_NAME} (z/OS Connect) via jsub..."
        jsub "${ZOSCONNECT_SYS_PROCLIB}(BAQ${APP_SHORT_NAME}J)" 2>/dev/null || true
    fi

    if [[ "$FRONTEND_SYS_PROCLIB" != "${APP_HLQ}.PROCLIB" ]]; then
        print_info "Starting FE${APP_SHORT_NAME} (Frontend Liberty) via opercmd..."
        opercmd "S FE${APP_SHORT_NAME}" 2>/dev/null || true
    else
        print_info "Starting FE${APP_SHORT_NAME} (Frontend Liberty) via jsub..."
        jsub "${FRONTEND_SYS_PROCLIB}(FE${APP_SHORT_NAME}J)" 2>/dev/null || true
    fi
    sleep 3

    print_success "z/OS Connect and Frontend Liberty servers start commands issued"
    set -e
}

#########################################################
# Dispatch stop by scope
#########################################################
do_stop() {
    local scope="$1"
    case "$scope" in
        all)
            # Stop order: Frontend → CICS → IMS
            stop_frontend
            stop_cics
            if [[ "${IMS_DISABLED:-false}" != "true" ]]; then
                stop_ims_regions
                stop_ims_control
            else
                print_info "IMS_DISABLED=true — skipping IMS stop"
            fi
            ;;
        ims)
            stop_ims_regions
            stop_ims_control
            ;;
        cics)
            stop_cics
            ;;
        frontend)
            stop_frontend
            ;;
    esac
}

#########################################################
# Dispatch start by scope
#########################################################
do_start() {
    local scope="$1"
    case "$scope" in
        all)
            # Start order: IMS → CICS → Frontend
            if [[ "${IMS_DISABLED:-false}" != "true" ]]; then
                start_ims_control
                start_ims_regions
            else
                print_info "IMS_DISABLED=true — skipping IMS start"
            fi
            start_cics
            start_frontend
            ;;
        ims)
            start_ims_control
            start_ims_regions
            ;;
        cics)
            start_cics
            ;;
        frontend)
            start_frontend
            ;;
    esac
}

#########################################################
# Main
#########################################################
main() {
    local action="${1:-}"
    local scope="${2:-}"

    case "$action" in
        -h|--help|help)
            print_usage
            exit 0
            ;;
        stop|start|restart)
            ;;
        "")
            print_error "Action is required."
            echo ""
            print_usage
            exit 1
            ;;
        *)
            print_error "Unknown action: $action"
            echo ""
            print_usage
            exit 1
            ;;
    esac

    case "$scope" in
        all|ims|cics|frontend)
            ;;
        "")
            print_error "Scope is required."
            echo ""
            print_usage
            exit 1
            ;;
        *)
            print_error "Unknown scope: $scope"
            echo ""
            print_usage
            exit 1
            ;;
    esac

    # Detect repo location (sets BANK_DIR, EXECUTION_MODE)
    detect_bank_of_z_location

    case "$action" in
        stop)
            print_stage "ACTION: Stop Bank of Z servers (scope: ${scope})"
            do_stop "$scope"
            print_stage "STOP COMPLETE"
            print_success "All requested servers have been stopped."
            ;;
        start)
            print_stage "ACTION: Start Bank of Z servers (scope: ${scope})"
            do_start "$scope"
            print_stage "START COMPLETE"
            print_success "All requested servers have been started."
            ;;
        restart)
            print_stage "ACTION: Restart Bank of Z servers (scope: ${scope})"
            do_stop "$scope"
            do_start "$scope"
            print_stage "RESTART COMPLETE"
            print_success "All requested servers have been restarted."
            ;;
    esac
}

main "$@"
exit $?

# Made with Bob
