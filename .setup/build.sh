#!/bin/env bash
set -e

#########################################################
# Build Script for Bank-of-Z
# This script runs on the remote z/OS USS system after
# the workspace has been cloned by grub
# 
# This script is responsible for:
# - Setting up the build environment
# - Installing required dependencies
# - Building the application with DBB
# - Creating and running a CICS Region
# - Deploying the application to CICS
# - Creating and populating Db2 database
#########################################################

# Get the directory where this script is located (the cloned workspace)
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rm -rf $WORKSPACE_DIR/logs

# Global configureation file
CONFIG_FILE="$WORKSPACE_DIR/.setup/config.yaml"
chtag -t -c ISO8859-1 $CONFIG_FILE

# Source library scripts
LIB_DIR="$WORKSPACE_DIR/.setup/lib"
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/environment.sh"
source "$LIB_DIR/prerequisites.sh"
source "$LIB_DIR/dbb.sh"

#########################################################
# Configuration
#########################################################

print_info "Workspace directory: $WORKSPACE_DIR"


# Application name (extracted from workspace directory name)
APPLICATION=$(basename "$WORKSPACE_DIR")
print_info "Application: $APPLICATION"

# Timestamp for unique build identifier
TIMESTAMP=$(date +%F_%H-%M-%S)
print_info "Build timestamp: $TIMESTAMP"

# Setup DBB environment variables
setup_dbb_environment "$WORKSPACE_DIR"

# Temporary HLQ for build datasets
# Consistent with pipeline_simulation.sh
export DBB_HLQ="${DBB_HLQ:-IBMUSER.BOZ.BLD}"
print_info "Using HLQ: $DBB_HLQ"

# Cancel CICS region (ignore errors if already cancelled)
jcan P "CICSBOZ"&

print_info "DBB_HOME: $DBB_HOME"
print_info "DBB_BUILD: $DBB_BUILD"
print_info "DBB_REPO: $DBB_REPO"
print_info "JAVA_HOME: $JAVA_HOME"
print_info "DBB_HLQ: $DBB_HLQ"

#########################################################
# STAGE 1: Verify Prerequisites
#########################################################
print_stage "STAGE 1: Verify Prerequisites"

# Verify all prerequisites
if ! verify_build_prerequisites; then
    exit 1
fi

# Setup DBB repository (clone if needed)
if ! setup_dbb_repository; then
    exit 1
fi

#########################################################
# STAGE 2: Run DBB Build
#########################################################
print_stage "STAGE 2: Run DBB Build"

# Change to workspace directory
cd "$WORKSPACE_DIR"

# Run DBB build
if bash ./dbb-build.sh "full"; then
    BUILD_RC=0
else
    BUILD_RC=$?
fi

#########################################################
# Build Summary
#########################################################
print_stage "BUILD SUMMARY"

if [ $BUILD_RC -eq 0 ]; then
    print_success "Build completed successfully!"
    echo ""
    echo "Build artifacts:"
    echo "  - HLQ: $DBB_HLQ"
    echo "  - Logs: $WORKSPACE_DIR/logs"
    echo "  - Timestamp: $TIMESTAMP"
    echo ""
else
    print_error "Build failed with return code: $BUILD_RC"
    echo ""
    echo "Check logs in: $WORKSPACE_DIR/logs"
    echo ""
fi

#########################################################
# STAGE 3: Run Wazi Deploy - Only deploy modules
#########################################################
print_stage "STAGE 3: Run Wazi Deploy"

# Change to workspace directory
cd "$WORKSPACE_DIR"

# Run DBB build
export INSTALL_APP="true"
if bash ./wazi-deploy.sh; then
    print_success "Wazi Deploy completed successfully!"
else
    print_error "Wazi Deploy failed with return code: $?"
    exit 1
fi

#########################################################
# STAGE 4: Create CICS instance with zconfig, DB2, TAZ
#########################################################
print_stage "STAGE 4: Create CICS instance with zconfig, DB2, TAZ"

# Change to workspace directory
cd "$WORKSPACE_DIR"

# Run DBB build
export INSTALL_APP="true"
if bash ./zconfig-install.sh; then
    print_success "Create CICS instance with zconfig, DB2, TAZ completed successfully!"
else
    print_error "Create CICS instance with zconfig, DB2, TAZ failed with return code: $?"
    exit 1
fi