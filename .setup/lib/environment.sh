#!/bin/env bash

#########################################################
# Environment Setup Library
# Provides functions for setting up DBB and z/OS
# environment variables
#########################################################

# Function to setup DBB environment variables
# Usage: setup_dbb_environment [workspace_dir]
setup_dbb_environment() {
    local workspace_dir=${1:-$(pwd)}
    local parent_dir=$(dirname "$workspace_dir")
    
    # DBB repository location on USS (shared across builds)
    export DBB_REPO="${DBB_REPO:-$parent_dir/dbb}"
    
    # DBB_BUILD path - points to the build configuration directory
    export DBB_BUILD_PATH="${DBB_BUILD_PATH:-$workspace_dir/.setup/build}"
    export DBB_BUILD="$DBB_BUILD_PATH"
    
    # DBB Home (standard installation path)
    export DBB_HOME="${DBB_HOME:-/usr/lpp/IBM/dbb}"
    
    # Java Home (required for DBB)
    if [ -z "$JAVA_HOME" ]; then
        export JAVA_HOME="/usr/lpp/java/java21/current_64"
    fi
    
    # LIBPATH for z/OS libraries
    export LIBPATH=/usr/lpp/IBM/cvg/v1r24/go/lib:/lib:/usr/lib:.:/usr/lpp/IBM/foz/v1r1/lib:/usr/lpp/IBM/cyp/v3r13/pyz/lib:/usr/lpp/db2d10/jdbc/lib:/usr/lpp/IBM/dbb/lib:/usr/lpp/IBM/zoautil//lib
    
    # ZOAU Home
    export ZOAU_HOME=/usr/lpp/IBM/zoautil/
    
    # Z_CONFIG directory
    export Z_CONFIG_CONFIG_DIR="${Z_CONFIG_CONFIG_DIR:-$parent_dir/zconfig}"
    
    # Pipeline scripts from DBB repository
    export PIPELINE_SCRIPTS="$DBB_REPO/Templates/Common-Backend-Scripts"
    
    # Add DBB, ZOAU, ZRB to PATH
    export PATH="$DBB_HOME/bin:/usr/lpp/IBM/zoautil/bin:/u/ibmuser/zrb/cics-resource-builder-1.0.6/bin:$PIPELINE_SCRIPTS:$PATH"
}

# Made with Bob