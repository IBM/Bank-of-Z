#!/bin/bash

#########################################################
# Run Pipeline Simulation Script
# This script updates and uploads the pipeline simulation
# script with configured values, then executes it
#########################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f $SCRIPT_DIR/.env ]; then
  echo -e "${RED}[ERROR] The .env file does not exist. Please run Setup Pipeline Environment before.${NC}"
  exit 1
fi

CONFIG_FILE="$SCRIPT_DIR/config.yaml"

. $SCRIPT_DIR/global.sh
. $SCRIPT_DIR/.env

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

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
PIPELINE_TMPHLQ=$(get_section_value 'pipeline_script' 'tmphlq')

# Get DBB repository target directory from config
DBB_REPO_TARGET=$(get_section_value 'repositories' 'target_dir')
DBB_REPO_PATH="$PIPELINE_BASE_WORKSPACE/$DBB_REPO_TARGET"

print_info "Pipeline script source: $PIPELINE_SCRIPT_SOURCE"
print_info "Pipeline script target: $PIPELINE_SCRIPT_TARGET"
print_info "Pipeline workspace: $PIPELINE_SCRIPT_WORKSPACE"
print_info "DBB repository path: $DBB_REPO_PATH"
print_info "zBuilder target directory: $ZBUILDER_TARGET_DIR"
print_info "Temporary HLQ: $PIPELINE_TMPHLQ"

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
print_info "Uploading pipeline simulation script to USS..."
if zowe rse-api-for-zowe-cli upload file-to-uss "$PIPELINE_SCRIPT_SOURCE" "$PIPELINE_SCRIPT_TARGET" --encoding IBM-1047; then
    # Make script executable
    print_info "Making script executable..."
    zowe rse-api-for-zowe-cli issue unix "chmod +x $(basename $PIPELINE_SCRIPT_TARGET)" --cwd "$SCRIPT_PARENT_DIR"
    
    print_success "Pipeline simulation script uploaded successfully"
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
export TMPHLQ='$PIPELINE_TMPHLQ' && \
export PIPELINE_WORKSPACE='$PIPELINE_WORKSPACE' && \
$PIPELINE_SCRIPT_TARGET $GIT_REPO $GIT_BRANCH"

zowe rse-api-for-zowe-cli issue unix-shell "$EXEC_CMD" --cwd "$SCRIPT_PARENT_DIR"

# Made with Bob
