#!/bin/env bash

# Function to parse YAML config - reads a key within a specific section
# Usage: get_section_value <section> <key>


_get_section_value_() {
    section=$1
    key=$2

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

get_section_value() {
    section=$1
    key=$2
    expand_vars $(_get_section_value_ $1 $2)
}

# Function to expand variables in config values
expand_vars() {
    value=$1

    # Replace $USER with actual username
    value=$(echo "$value" | sed "s|\$USER|$USER|g")

    # Replace $CICS_CMCI_USER
    value="${value//\$CICS_CMCI_USER/$CICS_CMCI_USER}"

    # Replace $CICS_CMCI_PASSWORD
    value="${value//\$CICS_CMCI_PASSWORD/$CICS_CMCI_PASSWORD}"

    # Replace ${section.key} with value from matching YAML section
    while [[ "$value" =~ \$\{([a-zA-Z_][a-zA-Z0-9_]*)\.([a-zA-Z_][a-zA-Z0-9_]*)\} ]]; do
        section="${BASH_REMATCH[1]}"
        key="${BASH_REMATCH[2]}"
        ref="${BASH_REMATCH[0]}"

        resolved="$(get_section_value "$section" "$key")"
        [[ -z "$resolved" ]] && break

        resolved="$(expand_vars "$resolved")"
        value="${value//$ref/$resolved}"
    done
    echo "$value"
}

resolve_path() {
  local path="$1"
  local dir file

  dir=$(dirname "$path")
  file=$(basename "$path")

  cd "$dir" 2>/dev/null || return 1
  printf "%s/%s\n" "$(pwd -P)" "$file"
}

submit_jcl() {
  local jcl_file="$1"
  local tmp_jcl="/tmp/$(basename "$jcl_file").$$"

  # Prepare JCL by replacing placeholder
  cat  "$jcl_file" | sed "s/#APP_BASE_NAME/${APP_BASE_NAME}/g" | sed "s/#APP_VERSION/${APP_VERSION}/g" > "$tmp_jcl"

  # Submit JCL in background
  jsub -f "$tmp_jcl" &

  # Allow submission to start
  sleep 3

  # Remove temporary file
  # rm -f "$tmp_jcl"
}
