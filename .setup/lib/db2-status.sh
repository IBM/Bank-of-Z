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
