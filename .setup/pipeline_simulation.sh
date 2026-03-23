#!/bin/env bash

# Accept git repository and branch as command-line arguments
gitRepository=${1:-"https://github.com/IBM/Bank-of-Z.git"}
branchName=${2:-"main"}

# DBB repository location on USS
export DBB_REPO=${DBB_REPO:-/u/ibmuser/sandbox/dbb}

# Location of the configured CBS scripts on USS - https://github.com/IBM/dbb/tree/main/Templates/Common-Backend-Scripts
# Not yet used
export PIPELINE_SCRIPTS=${DBB_REPO}/Templates/Common-Backend-Scripts

# Pipeline Workspace / use a shared folder/zfs
export PIPELINE_WORKSPACE=${PIPELINE_WORKSPACE:-/u/ibmuser/sandbox/workspace}

# zBuilder framework path (used for DBB_BUILD)
export DBB_BUILD_PATH=${DBB_BUILD_PATH:-/u/ibmuser/sandbox/zBuilder}

# Adding pipeline scripts to PATH of the user running this script
export PATH=$PIPELINE_SCRIPTS:$PATH
export TMPHLQ=${TMPHLQ:-ibmuser}

# Using a timestamp to simulate the buildIdentifier and unique workspace
timestamp=$(date +%F_%H-%M-%S)
rc=0

# Extract application name from repository URL (last part before .git)
application=$(basename "$gitRepository" .git)

echo "Pipeline Simulation Parameters:"
echo "  Git Repository: $gitRepository"
echo "  Branch: $branchName"
echo "  Application: $application"
echo "  Workspace: $PIPELINE_WORKSPACE"
echo ""

# Define workspace
workspaceDir=$PIPELINE_WORKSPACE/$application/build-$timestamp
mkdir -p workspaceDir

# This script simulates the entire pipeline process (clone, build, package & deploy)

# Clone repository
if [ $rc -eq 0 ]; then
    echo "Cloning repository..."
    gitClone.sh -w $workspaceDir -r $gitRepository -b $branchName
    rc=$?
fi


echo "[STAGE] Clone repo completed in $workspaceDir with rc:$rc"

if [ $rc -eq 0 ]; then
    
    # Set the DBB environment variables
    export DBB_HOME=/usr/lpp/IBM/dbb
    export PATH=$DBB_HOME/bin:$PATH
    export DBB_BUILD=$DBB_BUILD_PATH
    
    # Run build
    cd $workspaceDir/$application
    dbb build full --hlq ibmuser.BOZ.BLD
    rc=$?
    
    # For later use
    #zBuilder.sh -w $workspaceDir -a $application -b $branchName -p build -v -t 'full'
    
fi

echo "[STAGE] Build completed in $workspaceDir with rc:$rc"

# collect logs
if [ $rc -eq 0 ]; then
    mkdir -p $workspaceDir/logs
    cp -Rf $workspaceDir/$application/logs $workspaceDir

    # Assemble all logs that can be pulled into the workspace via the VS Code custom task.
    prepareLogs.sh -w $workspaceDir
    
fi

echo "[STAGE] Packaging logs completed in $workspaceDir with rc:$rc"

if [ $rc -eq 0 ]; then
    packageBuildOutputs.sh -w $workspaceDir -a $application -b $branchName -p build -i $timestamp -r $timestamp
    rc=$?
fi

echo "[STAGE] Packaging completed in $workspaceDir with rc:$rc"

### NOT in use yet, can be activated/customized later, once we have the Common Backend scripts configured


exit

if [ $rc -eq 0 ]; then
    wazideploy-generate.sh -w  $application/$branchName/${buildImplementation}build_$timestamp -a $application -b $branchName -P release -R $release -I $timestamp
    rc=$?
fi
