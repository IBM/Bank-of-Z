#!/bin/bash

#########################################################
# Configuration Library
# Provides functions for reading configuration from
# settings.json and config.yaml files
#########################################################

# Function to extract value from settings.json
# Usage: get_setting_value <key> [settings_file]
get_setting_value() {
    local key=$1
    local settings_file=${2:-".vscode/settings.json"}
    
    if [ -f "$settings_file" ]; then
        # Extract value using grep and sed (handles both quoted strings and unquoted values)
        local value=$(grep "\"$key\"" "$settings_file" | sed -E 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"?([^",}]+)"?.*/\1/' | tr -d ' ')
        echo "$value"
    fi
}

# Function to parse YAML config - reads a key within a specific section
# Usage: get_section_value <section> <key>
get_section_value() {
    local section=$1
    local key=$2

    awk -v section="$section" -v key="$key" '
        # Detect section header (no leading spaces)
        /^[^ #]/ {
            current_section = ($0 ~ "^" section ":") ? section : ""
        }

        # Match key inside the target section
        current_section == section && /^[[:space:]]+/ {
            # Strip leading spaces to get "key: value"
            sub(/^[[:space:]]+/, "")

            if ($0 ~ "^" key ":") {
                # Extract value after "key:"
                sub(/^[^:]+:[[:space:]]*/, "")
                # Remove inline comments and trailing spaces
                sub(/#.*$/, "")
                sub(/[[:space:]]+$/, "")
                print
                exit
            }
        }
    ' "$CONFIG_FILE"
}

# Function to expand variables in config values
expand_vars() {
    local value=$1

    # Replace $USER with actual username
    value="${value//\$USER/$USER}"

    # Replace $PIPELINE_WORKSPACE
    value="${value//\$PIPELINE_WORKSPACE/$PIPELINE_WORKSPACE}"

    # Replace ${global.<key>} with value from [global] section in config
    while [[ "$value" =~ \$\{global\.([a-zA-Z_]+)\} ]]; do
        local key="${BASH_REMATCH[1]}"
        local resolved
        resolved=$(get_section_value "global" "$key")
        value="${value//\$\{global\.${key}\}/$resolved}"
    done

    echo "$value"
}

# Made with Bob