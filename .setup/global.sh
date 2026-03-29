
#!/bin/sh

# Function to parse YAML config - reads a key within a specific section
# Usage: get_section_value <section> <key>
get_section_value() {
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


# Function to expand variables in config values
expand_vars() {
    value=$1

    # Replace $USER with actual username
    value=$(echo "$value" | sed "s|\$USER|$USER|g")

    # Replace $PIPELINE_WORKSPACE
    value=$(echo "$value" | sed "s|\$PIPELINE_WORKSPACE|$PIPELINE_WORKSPACE|g")

    # Replace ${global.<key>} with value from [global] section in config
    while echo "$value" | grep -q '\${global\.[a-zA-Z_]*}'; do
        key=$(echo "$value" | sed 's/.*\${global\.\([a-zA-Z_]*\)}.*/\1/')
        resolved=$(get_section_value "global" "$key")
        value=$(echo "$value" | sed "s|\${global\.${key}}|$resolved|g")
    done

    echo "$value"
}

# Made with Bob
