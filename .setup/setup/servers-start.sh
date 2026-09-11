#!/usr/bin/env bash

#########################################################
# servers-start.sh — Start Bank of Z runtime servers
#
# Starts the Bank of Z runtime servers. Intended for use
# after an infrastructure restart when tasks need to be
# brought back up without re-provisioning.
#
# Usage:
#   bash servers-start.sh [scope]
#
# Scope (optional, default: --all):
#   --all           IMS + CICS + Frontend  (start order)
#   --ims-only      IMS control tasks + IRLM + application regions
#   --cics-only     CICS region only
#   --frontend-only z/OS Connect + Frontend Liberty only
#
# Examples:
#   bash servers-start.sh
#   bash servers-start.sh --ims-only
#   bash servers-start.sh --frontend-only
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
# Start IMS control tasks + IRLM (warm restart)
#########################################################
start_ims_control() {
    print_stage "STAGE: Start IMS control tasks + IRLM (warm restart)"
    set +e

    # IRLM must be started before CTL
    print_info "Starting ${IMS_DATABASE_LOCK_MANAGER_SERVER_NAME} (IRLM)..."
    opercmd "S ${IMS_DATABASE_LOCK_MANAGER_SERVER_NAME}" 2>/dev/null || true
    sleep 2

    # Start IMS common services in order: SCI → OM → RM
    print_info "Starting ${IMS_DATASTORE}SCI..."
    opercmd "S ${IMS_DATASTORE}SCI" 2>/dev/null || true
    sleep 2

    print_info "Starting ${IMS_DATASTORE}OM..."
    opercmd "S ${IMS_DATASTORE}OM" 2>/dev/null || true
    sleep 2

    print_info "Starting ${IMS_DATASTORE}RM..."
    opercmd "S ${IMS_DATASTORE}RM" 2>/dev/null || true
    sleep 2

    # Start IMS CTL — implicitly starts IMS2DLI and IMS2DRC
    print_info "Submitting ${IMS_APP_HLQ}.PROCLIB(${IMS_DATASTORE}CTL) via jsub..."
    jsub "${IMS_APP_HLQ}.PROCLIB(${IMS_DATASTORE}CTL)" 2>/dev/null || true

    # Allow CTL and its dependent regions time to initialise
    print_info "Waiting for IMS CTL and dependent regions to initialise (30s)..."
    sleep 30

    # Post-start: Open Database (ODB) then IMS Connect (HWS)
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
# Main
#########################################################
main() {
    local scope_flag="${1:---all}"
    local scope="${scope_flag#--}"   # strip leading --

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
        ims-only)
            start_ims_control
            start_ims_regions
            ;;
        cics-only)
            start_cics
            ;;
        frontend-only)
            start_frontend
            ;;
        *)
            print_error "Unknown scope: ${scope_flag}"
            echo "Usage: bash servers-start.sh [--all|--ims-only|--cics-only|--frontend-only]"
            exit 1
            ;;
    esac

    print_success "servers-start.sh complete (scope: ${scope})"
}

main "$@"
exit $?

# Made with Bob
