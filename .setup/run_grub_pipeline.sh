#!/bin/env bash

#########################################################
# Run Pipeline Simulation Script
# This script updates and uploads the pipeline simulation
# script with configured values, then executes it
#########################################################

set -e  # Exit on error

# Script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

CONFIG_FILE="$SCRIPT_DIR/config.yaml"
APP_NAME=$(basename "$(dirname "$SCRIPT_DIR")")
PIPELINE_WORKSPACE="$(cd "$SCRIPT_DIR/../.." && pwd)"
PIPELINE_BASE_WORKSPACE=$PIPELINE_WORKSPACE

. $SCRIPT_DIR/global.sh

# Function to print colored messages
print_info() {
    echo "[INFO] $1"
}

print_success() {
    echo "[SUCCESS] $1"
}

print_error() {
    echo "[ERROR] $1"
}

# Parse command line arguments
GIT_REPO="GRUB"
GIT_BRANCH=$(git branch --show-current)

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

chtag -tc ISO8859-1 $CONFIG_FILE

PIPELINE_SCRIPT_SOURCE="$SCRIPT_DIR/$(get_section_value 'pipeline_script' 'source')"
PIPELINE_SCRIPT_TARGET=$PIPELINE_SCRIPT_SOURCE
PIPELINE_SCRIPT_WORKSPACE=$PIPELINE_WORKSPACE

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

# Execute the pipeline script on USS with environment variables
print_info "Executing pipeline simulation on USS..."
echo ""

# Build the command with environment variable exports
export PIPELINE_WORKSPACE=$PIPELINE_SCRIPT_WORKSPACE
export DBB_REPO=$DBB_REPO_PATH
export DBB_BUILD_PATH=$ZBUILDER_TARGET_DIR
export DBB_BUILD=$ZBUILDER_TARGET_DIR
export DBB_HLQ=$DBB_HLQ
export TARGET_HLQ=$TARGET_HLQ
export RUN_DEPLOY=$RUN_DEPLOY
export PIPELINE_TMPHLQ=$PIPELINE_TMPHLQ
export APP_NAME=$APP_NAME
export JAVA_HOME=$JAVA_HOME

cd "$SCRIPT_PARENT_DIR"

$PIPELINE_SCRIPT_TARGET $GIT_REPO $GIT_BRANCH

# Made with Bob
