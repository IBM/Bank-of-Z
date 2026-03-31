#!/bin/env bash

#########################################################
# Run Pipeline Simulation Script
# This script updates and uploads the pipeline simulation
# script with configured values, then executes it
#########################################################

set -e  # Exit on error

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yaml"

# Source library scripts
LIB_DIR="$SCRIPT_DIR/lib"
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/config.sh"

# Check for .env file
if [ ! -f $SCRIPT_DIR/.env ]; then
  echo -e "${RED}[ERROR] The .env file does not exist. Please run Setup Pipeline Environment before.${NC}"
  exit 1
fi

source "$SCRIPT_DIR/.env"

# Parse command line arguments
GIT_REPO=${1:-""}
GIT_BRANCH=${2:-""}

if [ -z "$GIT_REPO" ] || [ -z "$GIT_BRANCH" ]; then
    print_error "Usage: $0 <git_repository> <git_branch>"
    exit 1
fi

print_info "Git Repository: $GIT_REPO"
print_info "Git Branch: $GIT_BRANCH"

# Load configuration
print_info "Loading configuration from $CONFIG_FILE..."

if [ ! -f "$CONFIG_FILE" ]; then
    print_error "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

PIPELINE_BASE_WORKSPACE=$PIPELINE_WORKSPACE

PIPELINE_SCRIPT_SOURCE="$SCRIPT_DIR/$(get_section_value 'pipeline_script' 'source')"
PIPELINE_SCRIPT_TARGET=$(expand_vars "$(get_section_value 'pipeline_script' 'target')")
PIPELINE_SCRIPT_WORKSPACE=$(expand_vars "$(get_section_value 'pipeline_script' 'workspace')")

ZBUILDER_TARGET_DIR=$(expand_vars "$(get_section_value 'zbuilder' 'target_dir')")
JAVA_HOME=$(get_section_value 'zbuilder' 'java_home')
PIPELINE_TMPHLQ=$(get_section_value 'pipeline_script' 'tmphlq')

# Get DBB repository target directory from config
DBB_REPO_TARGET=$(get_section_value 'repositories' 'target_dir')
DBB_HLQ=$(get_section_value 'pipeline_script' 'dbb_hlq')
DBB_REPO_PATH="$PIPELINE_BASE_WORKSPACE/$DBB_REPO_TARGET"

# Get Wazi Deploy target config
TARGET_HLQ=$(get_section_value 'pipeline_script' 'target_hlq')
RUN_DEPLOY=$(get_section_value 'pipeline_script' 'run_deploy')

print_info "Pipeline script source: $PIPELINE_SCRIPT_SOURCE"
print_info "Pipeline script target: $PIPELINE_SCRIPT_TARGET"
print_info "Pipeline workspace: $PIPELINE_SCRIPT_WORKSPACE"
print_info "DBB repository path: $DBB_REPO_PATH"
print_info "zBuilder target directory: $ZBUILDER_TARGET_DIR"

if [ ! -f "$PIPELINE_SCRIPT_SOURCE" ]; then
    print_error "Pipeline simulation script not found: $PIPELINE_SCRIPT_SOURCE"
    exit 1
fi

# Ensure parent directory exists on USS
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
EXEC_CMD="export PIPELINE_WORKSPACE='$PIPELINE_SCRIPT_WORKSPACE' && \
export DBB_REPO='$DBB_REPO_PATH' && \
export DBB_BUILD_PATH='$ZBUILDER_TARGET_DIR' && \
export DBB_BUILD='$ZBUILDER_TARGET_DIR' && \
export DBB_HLQ='$DBB_HLQ' && \
export TARGET_HLQ='$TARGET_HLQ' && \
export RUN_DEPLOY='$RUN_DEPLOY' && \
export PIPELINE_TMPHLQ='$PIPELINE_TMPHLQ' && \
export PIPELINE_WORKSPACE='$PIPELINE_WORKSPACE' && \
export JAVA_HOME='$JAVA_HOME' && \
$PIPELINE_SCRIPT_TARGET $GIT_REPO $GIT_BRANCH"

zowe rse-api-for-zowe-cli issue unix-shell "$EXEC_CMD" --cwd "$SCRIPT_PARENT_DIR"

# Made with Bob
