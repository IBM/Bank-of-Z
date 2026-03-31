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

# Activate zconfig virtual environment
if [ -f ~/zconfig2/bin/activate ]; then
    source ~/zconfig2/bin/activate
else
    print_warning "zconfig2 virtual environment not found at ~/zconfig2/bin/activate"
fi

print_info "Workspace directory: $WORKSPACE_DIR"

# Global configureation file
CONFIG_FILE="$WORKSPACE_DIR/.setup/config.yaml"
chtag -t -c ISO8859-1 $CONFIG_FILE

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
jcan P "CICSBOZ" 2>/dev/null || true

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
if run_dbb_build "$DBB_HLQ" "full"; then
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

# Apply CICS region configuration
cd $WORKSPACE_DIR/.setup/zconfig
zconfig apply cics-region.yaml
echo ""
# Start CICS region
job_id=$(jsub BANKZ.BOZ.CICSBOZ.DFHSTART)
echo "CICS Region Job ID: $job_id"
echo ""

jsub -f "$WORKSPACE_DIR/Db2-drop.jcl"
sleep 3
jsub -f "$WORKSPACE_DIR/Db2-create.jcl"
sleep 3
jsub -f "$WORKSPACE_DIR/Db2-bind.jcl"
sleep 3
jsub -f "$WORKSPACE_DIR/Db2-insert.jcl"

exit $BUILD_RC
