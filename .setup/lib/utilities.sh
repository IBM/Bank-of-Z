#!/bin/env bash

# ============================================================
# YAML configuration helper functions
# ============================================================

# Reads a value from a YAML file for a given section and key.
#
# Usage:
#   _get_section_value_ <section> <key>
#
# Example YAML:
#   sandbox:
#     path: /tmp/workspace
#
# Call:
#   _get_section_value_ sandbox path
#
# Result:
#   /tmp/workspace
#
# Notes:
#   - The CONFIG_FILE variable must contain the path
#     to the YAML configuration file.
#   - Only simple YAML structures are supported.
_get_section_value_() {
    section=$1
    key=$2

    awk -v section="$section" -v key="$key" '
        # Detect top-level YAML sections.
        # A section is expected to start without indentation.
        /^[^ #]/ {
            current_section = ($0 ~ "^" section ":") ? section : ""
        }

        # Search for indented keys inside the current section.
        current_section == section && /^[[:space:]]+/ {

            # Remove leading indentation.
            sub(/^[[:space:]]+/, "")

            # Check if the current line matches the requested key.
            if ($0 ~ "^" key ":") {

                # Extract everything after "key:"
                sub(/^[^:]+:[[:space:]]*/, "")

                # Remove inline comments.
                sub(/#.*$/, "")

                # Remove trailing spaces.
                sub(/[[:space:]]+$/, "")

                # Print the value and stop processing.
                print
                exit
            }
        }
    ' "$CONFIG_FILE"
}

# Public wrapper around _get_section_value_.
#
# This function additionally expands variable references
# found in the configuration value.
#
# Supported formats:
#   ${section.key} -> YAML reference
#   ${ENV_VAR}     -> shell environment variable
#
# Example:
#   base:
#     dir: /opt/app
#
#   logs:
#     path: ${base.dir}/logs
#
# Result:
#   /opt/app/logs
get_section_value() {
    section=$1
    key=$2

    expand_vars "$(_get_section_value_ "$1" "$2")"
}

# Expands variables found in configuration values.
#
# Supported substitutions:
#
# 1. YAML references:
#      ${section.key}
#
#    Example:
#      ${sandbox.path}
#
# 2. Environment variables:
#      ${HOME}
#
# The function resolves values recursively.
expand_vars() {
    value=$1

    # Resolve YAML references (${section.key})
    while [[ "$value" =~ \$\{([a-zA-Z_][a-zA-Z0-9_]*)\.([a-zA-Z_][a-zA-Z0-9_]*)\} ]]; do

        section="${BASH_REMATCH[1]}"
        key="${BASH_REMATCH[2]}"
        ref="${BASH_REMATCH[0]}"

        # Read referenced value from YAML config
        resolved="$(get_section_value "$section" "$key")"

        # Stop if reference cannot be resolved
        [[ -z "$resolved" ]] && break

        # Resolve nested variables recursively
        resolved="$(expand_vars "$resolved")"

        # Replace reference with resolved value
        value="${value//$ref/$resolved}"
    done

    # Resolve shell environment variables (${VAR})
    while [[ "$value" =~ \$\{([a-zA-Z_][a-zA-Z0-9_]*)\} ]]; do

        varname="${BASH_REMATCH[1]}"
        ref="${BASH_REMATCH[0]}"

        resolved="${!varname}"

        # Stop if variable does not exist
        [[ -z "${!varname+x}" ]] && break

        value="${value//$ref/$resolved}"
    done

    echo "$value"
}

# Resolves a path to its canonical absolute path.
#
# Example:
#   resolve_path ../data/file.txt
#
# Result:
#   /full/path/to/data/file.txt
#
# Notes:
#   - Symbolic links are resolved using pwd -P.
#   - Returns 1 if the directory does not exist.
resolve_path() {
    local path="$1"
    local dir file

    dir=$(dirname "$path")
    file=$(basename "$path")

    cd "$dir" 2>/dev/null || return 1

    printf "%s/%s\n" "$(pwd -P)" "$file"
}

# ============================================================
# JCL submission helper
# ============================================================

# Prepares and submits a JCL file.
#
# The function:
#   1. Creates a temporary JCL file
#   2. Replaces placeholder variables
#   3. Submits the JCL using jsub
#   4. Runs submission in background
#
# Supported placeholders:
#   #APP_BASE_NAME
#   #APP_SHORT_NAME
#   #APP_VERSION
#   #IPIC_PORT
#
# Usage:
#   submit_jcl myjob.jcl
submit_jcl() {

    local jcl_file="$1"

    # Temporary generated JCL file
    local tmp_jcl="/tmp/$(basename "$jcl_file").$$"

    # Replace placeholders with runtime values
    cat "$jcl_file" \
        | sed "s/#APP_BASE_NAME/${APP_BASE_NAME:-}/g" \
        | sed "s/#APP_SHORT_NAME/${APP_SHORT_NAME:-}/g" \
        | sed "s/#APP_VERSION/${APP_VERSION:-}/g" \
        | sed "s/#IPIC_PORT/${IPIC_PORT:-}/g" \
        > "$tmp_jcl"

    # Submit JCL asynchronously
    jsub -f "$tmp_jcl" &

    # Give the submission process time to start
    sleep 3

    # Optional cleanup
    # rm -f "$tmp_jcl"
}

# ============================================================
# Configuration loader
# ============================================================

# Loads application configuration.
#
# Behavior:
#   - Verifies that CONFIG_FILE exists
#   - Loads PIPELINE_WORKSPACE from:
#       1. Function argument if provided
#       2. YAML config otherwise
#
# YAML example:
#   sandbox:
#     path: /workspace
#
# Usage:
#   load_config
#
#   load_config /custom/workspace
load_config() {

    print_info "Loading configuration from $CONFIG_FILE..."

    # Validate configuration file existence
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi

    # Use explicit workspace if provided
    if [[ -n "$1" ]]; then
        PIPELINE_WORKSPACE="$1"
    else
        # Otherwise read from YAML configuration
        PIPELINE_WORKSPACE=$(get_section_value 'sandbox' 'path')
    fi

    print_success "Configuration loaded successfully"

    echo "  Workspace: $PIPELINE_WORKSPACE"
}