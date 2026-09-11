#!/usr/bin/env bash

#########################################################
# servers-stop.sh — Stop Bank of Z runtime servers
#
# Stops the Bank of Z runtime servers WITHOUT touching
# any datasets or application data.
#
# Usage:
#   bash servers-stop.sh [scope]
#
# Scope (optional, default: --all):
#   --all           Frontend + CICS + IMS  (stop order)
#   --ims-only      IMS application regions + control tasks + IRLM
#   --cics-only     CICS region only
#   --frontend-only z/OS Connect + Frontend Liberty only
#
# Examples:
#   bash servers-stop.sh
#   bash servers-stop.sh --ims-only
#   bash servers-stop.sh --frontend-only
#
# Environment variables:
#   IMS_DISABLED    Set to true to skip all IMS tasks (default: false)
#########################################################

set -e

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

# =========================
# Environment
# =========================
export PATH="${ZOAU_HOME:-}/bin:$PATH"
export LIBPATH="${ZOAU_HOME:-}/lib:${LIBPATH:-}"

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

    print_info "Cancelling CICS${APP_SHORT_NAME} job (if submitted)..."
    jcan P "CICS${APP_SHORT_NAME}" 2>/dev/null || true

    print_info "Issuing C CICS${APP_SHORT_NAME}..."
    opercmd "C CICS${APP_SHORT_NAME}" 2>/dev/null || true
    sleep 2

    print_success "CICS region stopped"
    set -e
}

#########################################################
# Stop IMS application regions (MPP / JMP)
#########################################################
stop_ims_regions() {
    print_stage "STAGE: Stop IMS application regions (MPP / JMP)"
    set +e

    # Delete stale stop members so jsub fails silently rather than executing
    # outdated JCL that may reference deleted datasets.
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

    # Stop IMS Connect (HWS) and Open Database (ODB) first
    print_info "Stopping ${IMS_DATASTORE}HWS..."
    opercmd "C ${IMS_DATASTORE}HWS" 2>/dev/null || true
    sleep 1

    print_info "Stopping ${IMS_DATASTORE}ODB..."
    opercmd "C ${IMS_DATASTORE}ODB" 2>/dev/null || true
    sleep 1

    # Stop IMS DRC (dependent region controller)
    print_info "Stopping ${IMS_DATASTORE}DRC..."
    opercmd "C ${IMS_DATASTORE}DRC" 2>/dev/null || true
    sleep 1

    # Stop IMS CTL (also terminates DLI)
    print_info "Stopping ${IMS_DATASTORE}CTL..."
    opercmd "C ${IMS_DATASTORE}CTL" 2>/dev/null || true
    sleep 2

    # Stop IMS common services
    print_info "Stopping ${IMS_DATASTORE}OM..."
    opercmd "C ${IMS_DATASTORE}OM" 2>/dev/null || true
    sleep 1

    print_info "Stopping ${IMS_DATASTORE}RM..."
    opercmd "C ${IMS_DATASTORE}RM" 2>/dev/null || true
    sleep 1

    print_info "Stopping ${IMS_DATASTORE}SCI..."
    opercmd "C ${IMS_DATASTORE}SCI" 2>/dev/null || true
    sleep 1

    # IRLM must be stopped last (after all IMS address spaces)
    print_info "Stopping ${IMS_DATABASE_LOCK_MANAGER_SERVER_NAME} (IRLM)..."
    opercmd "C ${IMS_DATABASE_LOCK_MANAGER_SERVER_NAME}" 2>/dev/null || true
    sleep 2

    print_success "IMS control tasks and IRLM stopped"
    set -e
}

#########################################################
# Main
#########################################################
main() {
    local scope_flag="${1:---all}"
    local scope="${scope_flag#--}"   # strip leading --

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
        ims-only)
            stop_ims_regions
            stop_ims_control
            ;;
        cics-only)
            stop_cics
            ;;
        frontend-only)
            stop_frontend
            ;;
        *)
            print_error "Unknown scope: ${scope_flag}"
            echo "Usage: bash servers-stop.sh [--all|--ims-only|--cics-only|--frontend-only]"
            exit 1
            ;;
    esac

    print_success "servers-stop.sh complete (scope: ${scope})"
}

main "$@"
exit $?

# Made with Bob
