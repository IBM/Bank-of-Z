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

# Global configuration file
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

# Set PIPELINE_WORKSPACE for config.yaml variable expansion
export PIPELINE_WORKSPACE="$WORKSPACE_DIR"

# Expand environment variables in config.yaml using our bundled envsubst
$WORKSPACE_DIR/.setup/envsubst < $WORKSPACE_DIR/.setup/config.yaml > $WORKSPACE_DIR/.setup/config.yaml.expanded
export CONFIG_FILE="$WORKSPACE_DIR/.setup/config.yaml.expanded"

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

#########################################################
# STAGE 3: Run Wazi Deploy - Only deploy modules
#########################################################
WAZIDEPLOY_HOME=$(get_section_value 'wazideploy' 'wazideploy_home')
. $WAZIDEPLOY_HOME/bin/activate
wazideploy-generate -v
wazideploy-generate\
  -dm ../dbb/WaziDeploy/zDeploy/deployment-configuration/deployment-method.yml\
  -dp logs/deployment-plan.yml -pif logs/bank-of-z-zos-native-*.tar

if [ $? -eq 0 ]; then
     drm BANKZ.CICSBOZ.*&
     TARGET_HLQ=$(get_section_value 'pipeline_script' 'target_hlq')
     # Overide default mapping (need something more generic)
     cp .setup/deploy/types_pattern_mapping.yml ../dbb/WaziDeploy/zDeploy/deployment-configuration/global
     export USER=$(get_user)
     echo "* USER=$USER"
     wazideploy-deploy -dp logs/deployment-plan.yml\
       -pif logs/bank-of-z-zos-native-*.tar -ef .setup/deploy/Development.yml \
       -wf logs/ -e deploy_cfg_home=../dbb/WaziDeploy/zDeploy -e hlq=$TARGET_HLQ\
       -pt deploy &
    PID=$!
    wait $PID
    RC=$?
    if [ $RC -eq 0 ]; then
         print_success "Wazi Deploy completed successfully!"
    else
        print_error "Wazi Deploy failed with return code: $RC"
        echo ""
        echo "Check logs in: $WORKSPACE_DIR/logs"
        echo ""
        exit 1
    fi
else
    print_error "Wazi Deploy failed with return code: $RC"
    echo ""
    echo "Check logs in: $WORKSPACE_DIR/logs"
    echo ""
fi
deactivate

#########################################################
# STAGE 4: Create CICS instance with zconfig
#########################################################

# Activate zconfig virtual environment
ZCONFIG_HOME=$(get_section_value 'zconfig' 'zconfig_home')
ZCONFIG_HOME=$(echo $ZCONFIG_HOME | sed "s|~|$HOME|g")
if [ -f $ZCONFIG_HOME/bin/activate ]; then
    source $ZCONFIG_HOME/bin/activate
else
    print_warning "zconfig virtual environment not found at $ZCONFIG_HOME/bin/activate"
fi

# Apply CICS region configuration
cd $WORKSPACE_DIR/.setup/zconfig
zconfig apply cics-region.yaml&
PID=$!
wait $PID
RC=$?
if [ $RC -eq 0 ]; then
    print_success "ZConfig completed successfully!"
else
   print_error "ZConfig failed with return code: $RC"
   echo ""
   echo "Check logs in: $WORKSPACE_DIR/logs"
   echo ""
   exit 1
fi
deactivate
echo ""
# Start CICS region
jsub BANKZ.CICSBOZ.DFHSTART&
sleep 3
echo "CICS Region Job Started"
echo ""

#########################################################
# STAGE 5: Create DB2 database
#########################################################

jsub -f "$WORKSPACE_DIR/.setup/jcl/Db2-drop.jcl"&
sleep 3
jsub -f "$WORKSPACE_DIR/.setup/jcl/Db2-create.jcl"&
sleep 3
jsub -f "$WORKSPACE_DIR/.setup/jcl/Db2-bind.jcl"&
sleep 3
jsub -f "$WORKSPACE_DIR/.setup/jcl/Db2-insert.jcl"&
sleep 3
