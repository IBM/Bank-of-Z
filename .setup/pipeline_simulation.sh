#!/bin/env sh

# Accept git repository and branch as command-line arguments
gitRepository=${1:-"https://github.com/IBM/Bank-of-Z.git"}
branchName=${2:-"main"}

# DBB repository location on USS
export DBB_REPO=${DBB_REPO:-$PIPELINE_WORKSPACE/dbb}

# Location of the configured CBS scripts on USS - https://github.com/IBM/dbb/tree/main/Templates/Common-Backend-Scripts
# Not yet used
export PIPELINE_SCRIPTS=${DBB_REPO}/Templates/Common-Backend-Scripts

# Pipeline Workspace / use a shared folder/zfs
export PIPELINE_WORKSPACE=${PIPELINE_WORKSPACE:-$PIPELINE_WORKSPACE/workspace}

# zBuilder framework path (used for DBB_BUILD)
export DBB_BUILD_PATH=${DBB_BUILD_PATH:-$PIPELINE_WORKSPACE/zBuilder}

# zBuilder framework dbb hlq build
export DBB_HLQ=${DBB_HLQ:-BANKZ.BOZ.BLD}

# Adding pipeline scripts to PATH of the user running this script
export PATH=$PIPELINE_SCRIPTS:$PATH
TMPHLQ=$(printf '%s' "${PIPELINE_TMPHLQ:-$(basename "$HOME")}" | tr '[:lower:]' '[:upper:]')

# Using a timestamp to simulate the buildIdentifier and unique workspace
timestamp=$(date +%F_%H-%M-%S)
rc=0

if [ "$1" != "GRUB" ]; then
    # Extract application name from repository URL (last part before .git)
    application=$(basename "$gitRepository" .git)
else
    application=$APP_NAME
    gitRepository=$APP_NAME
fi

echo "Pipeline Simulation Parameters:"
echo "  Git Repository: $gitRepository"
echo "  Branch: $branchName"
echo "  Application: $application"
echo "  Workspace: $PIPELINE_WORKSPACE"
echo "  Temporary HLQ: $TMPHLQ"


# This script simulates the entire pipeline process (clone, build, package & deploy)

if [ "$1" != "GRUB" ]; then
    # Define workspace
    workspaceDir=$PIPELINE_WORKSPACE/$application/build-$timestamp
    mkdir -p workspaceDir
    export DBB_LIFECYCLE=pipeline

    # Clone repository
    if [ $rc -eq 0 ]; then
        echo "Cloning repository..."
        gitClone.sh -w $workspaceDir -r $gitRepository -b $branchName
        rc=$?
    fi
    echo "[STAGE] Clone repo completed in $workspaceDir with rc:$rc"
else
    workspaceDir=$PIPELINE_WORKSPACE
    rm -rf $workspaceDir/logs
    export DBB_LIFECYCLE=full
fi


if [ $rc -eq 0 ]; then
    # Set the DBB environment variables
    export DBB_HOME=/usr/lpp/IBM/dbb
    export PATH=$DBB_HOME/bin:$PATH
    export DBB_BUILD=$DBB_BUILD_PATH
    
    # Run build
    cd $workspaceDir/$application

    # simulation
    dbb build $DBB_LIFECYCLE --hlq $DBB_HLQ
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

if [ $rc -ne 0 ]; then
    exit $rc
fi

if [ "$(echo "$RUN_DEPLOY" | tr '[:upper:]' '[:lower:]')" = "true" ]; then

    # Use zDeploy Framework (no CBS for now)
    #wazideploy-generate.sh -w  $application/$branchName/${buildImplementation}build_$timestamp -a $application -b $branchName -P release -R $release -I $timestamp

    # Set the DBB environment variables
    . /global/opt/pyenv/gdp/bin/activate
    export ZOAU_HOME=/usr/lpp/IBM/zoautil
    export PATH=$ZOAU_HOME/bin:$PATH
    export LIBPATH=$ZOAU_HOME/lib:$LIBPATH

    cd $PIPELINE_WORKSPACE
    # Set the Wazi Deploy zBuilder environment variables
    export DEPLOYMENT_METHOD=$PWD/dbb/WaziDeploy/zDeploy/deployment-configuration/deployment-method.yml
    export PACKAGE_URL=$(ls $workspaceDir/logs/build-*.tar 2>/dev/null)
    export ZDEPLOY_FOLDER=$PWD/dbb/WaziDeploy/zDeploy
    export DEPLOY_ENV_FILE=$PWD/deploy/Development.yml
    
    if [ -z "$PACKAGE_URL" ] || [ ! -f "$PACKAGE_URL" ]; then
        echo "[STAGE] Wazi Deploy stage skipped nothing to deploy in $PACKAGE_URL rc:$rc"
        exit 0
    fi

    # zDeploy framework target hlq
    export TARGET_HLQ=${TARGET_HLQ:-BANKZ.CICSBANKZ}

    # Locations of evidences
    evidenceDir=$PIPELINE_WORKSPACE/$application/evidences
    
    # Print Wazi Deploy version
    wazideploy-generate -v 

    # Wazi Deploy generation step
    wazideploy-generate \
        --deploymentMethod $DEPLOYMENT_METHOD \
        --deploymentPlan $workspaceDir/deploymentPlan.yaml \
        --deploymentPlanReport $workspaceDir/deploymentPlanReport.html \
        --packageInputFile $PACKAGE_URL
    rc=$?
    echo "[STAGE] Wazi Deploy generate completed in $workspaceDir with rc:$rc"

    # Overide default mapping (need something more generic)
    cp deploy/types_pattern_mapping.yml dbb/WaziDeploy/zDeploy/deployment-configuration/global
    
    if [ $rc -eq 0 ]; then
        # Wazi Deploy deploy step 
        wazideploy-deploy \
            --workingFolder $workspaceDir \
            --deploymentPlan $workspaceDir/deploymentPlan.yaml \
            --envFile $DEPLOY_ENV_FILE \
            -e hlq=$TARGET_HLQ \
            -e deploy_cfg_home=$ZDEPLOY_FOLDER \
            --packageInputFile $PACKAGE_URL \
            --evidencesFileName $evidenceDir/evidence-$timestamp.yaml &
        PID=$!
        wait $PID
        rc=$?
        echo "[STAGE] Wazi Deploy deploy completed in $workspaceDir with rc:$rc"
    fi
    deactivate
fi
