#!/bin/env bash

#########################################################
# Run Pipeline Simulation Script
# This script updates and uploads the pipeline simulation
# script with configured values, then executes it
#########################################################

set -eu  # Exit on error
# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/config/setenv.sh"
PIPELINE_SCRIPT_SOURCE=$SCRIPTS_DIR/pipeline_simulation.sh

# Parse command line arguments
GIT_REPO=${1:-"https://github.com/IBM/Bank-of-Z.git"}
GIT_BRANCH=${2:-$(git rev-parse --abbrev-ref HEAD)}

if [ -z "$GIT_REPO" ] || [ -z "$GIT_BRANCH" ]; then
    print_error "Usage: $0 <git_repository> <git_branch>"
    exit 1
fi

print_info "Git Repository: $GIT_REPO"
print_info "Git Branch: $GIT_BRANCH"

# Ensure parent directory exists on USS
PIPELINE_SCRIPT_TARGET="$(get_section_value 'sandbox' 'path')/Bank-of-Z/.setup/pipeline_simulation.sh"
SCRIPT_PARENT_DIR=$(dirname "$PIPELINE_SCRIPT_TARGET")
print_info "Ensuring parent directory exists: $SCRIPT_PARENT_DIR"
zowe rse-api-for-zowe-cli create uss-directory "$SCRIPT_PARENT_DIR" &> /dev/null || true

# Delete existing file if it exists
print_info "Removing existing pipeline script if present..."
zowe rse-api-for-zowe-cli delete uss-file "$PIPELINE_SCRIPT_TARGET" &> /dev/null || true

# Upload the script directly (no sed modifications needed)
print_info "Uploading pipeline simulation build script to USS..."
if zowe rse-api-for-zowe-cli upload file-to-uss "$PIPELINE_SCRIPT_SOURCE" "$PIPELINE_SCRIPT_TARGET" --encoding IBM-1047; then
    # Make script executable
    print_info "Making script executable..."
    zowe rse-api-for-zowe-cli issue unix "chmod +x $(basename $PIPELINE_SCRIPT_TARGET)" --cwd "$SCRIPT_PARENT_DIR"
    
    print_success "Pipeline simulation build script uploaded successfully"
else
    print_error "Failed to upload pipeline simulation build script"
    exit 1
fi

print_info "Uploading pipeline simulation deploy scripts to USS..."
if zowe rse-api-for-zowe-cli upload dir-to-uss "$(dirname "$PIPELINE_SCRIPT_SOURCE")/deploy" "$(dirname $PIPELINE_SCRIPT_TARGET)/deploy" --encoding UTF-8; then
    print_success "Pipeline simulation deploy scripts uploaded successfully"
else
    print_error "Failed to upload pipeline simulation script"
    exit 1
fi

# Execute the pipeline script on USS with environment variables
print_info "Executing pipeline simulation on USS..."
echo ""

# Build the command with environment variable exports
set -o pipefail

if ! zowe rse-api-for-zowe-cli issue unix-shell "export GRUB='False' && bash $PIPELINE_SCRIPT_TARGET" --cwd "$(dirname $PIPELINE_SCRIPT_TARGET)" 2>&1 | tee /tmp/deploy.log; then
    print_error "Failed install Bank of Z on the target!!"
    exit 1
fi
if grep -i "error\|failed\|RC=[^0]\|return code [^0]" /tmp/build.log | grep -v "Failed to change files and directory owner with chown"; then
    print_error "Failed update Bank of Z on the target!!"
    exit 1
fi

# Summary
print_stage "UPDATE COMPLETE"
print_success "Environment update completed successfully!"
