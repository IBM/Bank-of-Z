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
    ZRB_HOME=$(get_section_value 'zconfig' 'zcb_home')
    ZRB_HOME=$(echo $ZRB_HOME | sed "s|~|$HOME|g")
    
    export PATH="$ZRB_HOME/bin:$DBB_HOME/bin:/usr/lpp/IBM/zoautil/bin:$PIPELINE_SCRIPTS:$PATH"
    
    export DBB_HLQ=$(get_section_value 'pipeline_script' 'dbb_hlq')
}

# Get the current USER
get_user() {
  if [ -n "$USER" ]; then
    echo "$USER"
  elif [ -n "$LOGNAME" ]; then
    echo "$LOGNAME"
  else
    echo "${HOME##*/}"
  fi
}

# Made with Bob