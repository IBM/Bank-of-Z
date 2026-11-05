#!/bin/env bash

# Print a state only after opercmd and the response parser both succeed.
read_db2_master_status() {
    local response
    if ! response=$(opercmd "D A,${DB2_SSID}MSTR" 2>&1); then
        print_error "Unable to query Db2 master address space" >&2
        return 1
    fi
    local state
    state=$(printf '%s\n' "$response" | "$PYTHON_HOME/bin/python3" \
        "$SCRIPTS_DIR/../lib/db2_provisioning.py" status "$DB2_SSID") || return 1
    case "$state" in
        active|inactive) printf '%s\n' "$state" ;;
        *) print_error "Unrecognized Db2 activity response; stopping" >&2; return 1 ;;
    esac
}

# Listing failures must not be mistaken for a subsystem missing from state.
read_db2_managed_state() {
    local listing state
    if ! listing=$(zconfig ls); then
        print_error "Unable to read zconfig-managed Db2 state" >&2
        return 1
    fi
    state=$(printf '%s\n' "$listing" | "$PYTHON_HOME/bin/python3" \
        "$SCRIPTS_DIR/../lib/db2_provisioning.py" managed-state "$DB2_SSID") || return 1
    case "$state" in
        present|absent) printf '%s\n' "$state" ;;
        *) print_error "Unrecognized zconfig state response; stopping" >&2; return 1 ;;
    esac
}

# Db2 removal never controls another component's lifecycle. Require the Bank's
# configured consumers to be stopped through their existing lifecycle commands.
verify_db2_consumers_stopped() {
    local task response state
    local task_pattern='^[A-Z$#@][A-Z0-9$#@]{0,7}$'
    local tasks=("CICS${APP_SHORT_NAME}")
    if [[ "${IMS_DISABLED:-false}" != "true" ]]; then
        tasks+=("${IMS_DATASTORE}CTL" "${IMS_DATASTORE}JMP1" "${IMS_DATASTORE}MPP1" "${IMS_DATASTORE}MPP2")
    fi
    for task in "${tasks[@]}"; do
        if [[ ! "$task" =~ $task_pattern ]]; then
            print_error "Invalid Bank consumer task name; refusing Db2 removal" >&2
            return 1
        fi
        if ! response=$(opercmd "D A,${task}"); then
            print_error "Unable to query Bank consumer ${task}; refusing Db2 removal" >&2
            return 1
        fi
        state=$(printf '%s\n' "$response" | "$PYTHON_HOME/bin/python3" \
            "$SCRIPTS_DIR/../lib/db2_provisioning.py" task-status "$task") || return 1
        if [[ "$state" != inactive ]]; then
            print_error "Bank consumer ${task} is active or its status is unknown; refusing Db2 removal" >&2
            print_info "Stop the Bank consumers using their existing lifecycle commands, then retry." >&2
            return 1
        fi
    done
}
