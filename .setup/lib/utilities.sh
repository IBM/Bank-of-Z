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
get_section_value() {
    local script_dir

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    python3 "${script_dir}/config.py" "$1" "$2"
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
#   #APP_ZOS_VERSION
#   #CICS_IPIC_PORT
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
        | sed "s/#APP_ZOS_VERSION/${APP_ZOS_VERSION:-}/g" \
        | sed "s/#CICS_IPIC_PORT/${CICS_IPIC_PORT:-}/g" \
        > "$tmp_jcl"

    # Submit JCL asynchronously
    jsub -f "$tmp_jcl" &

    # Give the submission process time to start
    sleep 3

    # Optional cleanup
    # rm -f "$tmp_jcl"
}

# ============================================================
# Submit a JCL job and wait for completion.
#
# This function:
#   1. Submits a JCL file using `jsub`
#   2. Extracts the generated JOBID from the submit output
#   3. Monitors the job status using `jls`
#   4. Waits until the job reaches a final JES state
#   5. Displays:
#        - Final job status
#        - JESYSMSG spool content
#   6. Returns:
#        - 0 if the job completes with an acceptable
#          condition code (default: CC=0000 or CC=0004)
#        - 8 if the job fails, including:
#            * ABEND
#            * JCL error
#            * Security error
#            * Job cancellation
#            * Condition code higher than MAXRC
#
# Parameters:
#   $1 -> Path to the JCL file to submit
#   $2 -> Optional MAXRC value
#         Default = 4
#
# Dependencies:
#   - jsub
#   - jls
#   - pjdd
#
# Examples:
#   run_job_and_wait "./MYJOB.jcl"
#     -> Accepts CC=0000 to CC=0004
#
#   run_job_and_wait "./MYJOB.jcl" 8
#     -> Accepts CC=0000 to CC=0008
# ============================================================
run_job_and_wait() {
  local JCLFILE="$1"
  local MAXRC="${2:-4}"

  print_info "Submitting $JCLFILE via jsub ..."
  OUT=$(jsub -f "$JCLFILE")

  JOBID=$(echo "$OUT" | awk '{
    for (i=1; i<=NF; i++) {
      if ($i ~ /^JOB[0-9]+$/) { print $i; exit }
    }
  }')

  [ -z "$JOBID" ] && { print_error "no JOBID returned by jsub"; return 8; }

  print_info "Waiting for job $JOBID..."

  while :; do
    LINE=$(jls "$JOBID" 2>/dev/null | grep "$JOBID" | tail -1 || true)
    [ -n "$LINE" ] && print_info "$LINE"

    print_info "$LINE" | grep -Eq "OUTPUT|CC |ABEND|JCLERR|CANCELED|SEC ERROR" && break 

    sleep 3
  done

  FINAL=$(jls "$JOBID" | grep "$JOBID" | tail -1)

  STATUS=$(echo "$FINAL" | awk '{print $4}')
  RC=$(echo "$FINAL" | awk '{print $5}')

  if [ "$STATUS" = "CC" ]; then
    case "$RC" in
      0000|0004)
        return 0
        ;;
      0008)
        [ "$MAXRC" = "8" ] && return 0
        ;;
      0012)
        [ "$MAXRC" = "12" ] && return 0
        ;;
    esac
  fi
  print_error "Job failed: $JOBID"
  print_info "===== JESYSMSG ====="
  pjdd "$JOBID" JES2 JESYSMSG 2>/dev/null || true
return 8
}

# ============================================================
# Configuration loader
# ============================================================

# Loads application configuration.
#
# Behavior:
#   - Verifies that CONFIG_FILE exists
#   - Loads BANK_OF_Z_WORK_DIR from:
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

    # Use provided workspace if available
    if [ ! -f "$BANK_OF_Z_WORK_DIR" ]; then
        # Otherwise read from YAML configuration
        export BANK_OF_Z_WORK_DIR=$(get_section_value 'sandbox' 'path')
    fi

    print_success "Configuration loaded successfully"

    print_info "Workspace: $BANK_OF_Z_WORK_DIR"
}


# ============================================================
# Detects how the pipeline/script is being executed.
#
# Supported execution modes:
#
# 1. GRUB mode
#    - Triggered when running directly inside the Bank-of-Z
#      Git repository.
#    - Uses the repository root as the workspace directory.
#
# 2. VSCode mode
#    - Triggered when not running inside a Git repository.
#    - Assumes execution is orchestrated externally
#      (e.g. VSCode task, CI pipeline, remote runner).
#    - Uses BANK_OF_Z_WORK_DIR if provided, otherwise the
#      current working directory.
#
# This function initializes:
#   - EXECUTION_MODE
#   - WORKSPACE_DIR
#
# Possible values for EXECUTION_MODE:
#   - grub
#   - vscode
#   - unknown
# ============================================================
detect_bank_of_z_location() {
    local IN_REPO=false
    # Detect if we're already in the Bank-of-Z repository
    print_stage "Detecting Bank of Z location..."
    
    # Check if current directory is a git repo and if it's Bank-of-Z
    if git rev-parse --git-dir > /dev/null 2>&1; then
        local repo_name=$(basename "$(git rev-parse --show-toplevel)")
        if [[ "$repo_name" =~ ^Bank-of-Z ]]; then
            IN_REPO=true
            EXECUTION_MODE="grub"
            BANK_DIR="$(git rev-parse --show-toplevel)"
            print_info "Running from within Bank-of-Z repository"
            print_info "Repository location: $BANK_DIR"
            print_success "Using current repository (GRUB workflow detected)"
        fi
    fi
    
    # If not in repo, use the cloned version in workspace
    if [ "$IN_REPO" = false ]; then
        BANK_DIR="$BANK_OF_Z_WORK_DIR/Bank-of-Z"
        print_info "Using cloned repository at: $BANK_DIR"
        EXECUTION_MODE="vscode"
        if [ ! -d "$BANK_DIR" ]; then
            print_error "Bank-of-Z not found at: $BANK_DIR"
            print_info "Expected location: $BANK_DIR"
            print_info "This should have been cloned by the orchestrator script"
            return 1
        fi
        print_success "Found Bank-of-Z at workspace location (VSCode workflow detected)"
    fi
    BANK_OF_Z_WORK_DIR=$(dirname $BANK_DIR)
    return 0
}