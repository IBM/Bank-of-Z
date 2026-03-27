#!/bin/bash

#########################################################
# DBB Operations Library
# Provides functions for DBB repository management
# and build operations
#########################################################

# Function to clone or verify DBB repository
# Usage: setup_dbb_repository [parent_dir]
setup_dbb_repository() {
    local parent_dir=${1:-$(dirname "$WORKSPACE_DIR")}
    local dbb_repo="${DBB_REPO:-$parent_dir/dbb}"
    
    # Check if DBB repository exists (shared resource)
    if [ ! -d "$dbb_repo" ]; then
        print_info "DBB repository not found at $dbb_repo"
        print_info "Cloning DBB repository (one-time setup, will be reused by subsequent builds)..."
        
        cd "$parent_dir"
        
        if command -v git &> /dev/null; then
            if git clone https://github.com/IBM/dbb.git; then
                print_success "DBB repository cloned successfully to $dbb_repo"
                print_info "This repository will be reused by all future builds"
            else
                print_error "Failed to clone DBB repository"
                return 1
            fi
        else
            print_error "Git is not available. Please clone DBB repository manually to $dbb_repo"
            return 1
        fi
        
        cd "$WORKSPACE_DIR"
    else
        print_success "DBB repository found at $dbb_repo (reusing existing clone)"
    fi
    
    return 0
}

# Function to run DBB build
# Usage: run_dbb_build <hlq> [build_type]
run_dbb_build() {
    local hlq=$1
    local build_type=${2:-"full"}
    
    print_info "Starting DBB build with HLQ: $hlq"
    print_info "Build command: dbb build $build_type --hlq $hlq"
    
    if dbb build "$build_type" --hlq "$hlq"; then
        print_success "DBB build completed successfully"
        return 0
    else
        local rc=$?
        print_error "DBB build failed with return code: $rc"
        return $rc
    fi
}

# Function to collect build logs
# Usage: collect_build_logs [workspace_dir] [parent_dir]
collect_build_logs() {
    local workspace_dir=${1:-$WORKSPACE_DIR}
    local parent_dir=${2:-$(dirname "$workspace_dir")}
    
    # Ensure logs directory exists in the parent workspace for packaging
    mkdir -p "$parent_dir/logs"
    
    # Copy build logs from workspace to parent logs directory
    if [ -d "$workspace_dir/logs" ]; then
        print_info "Copying build logs to $parent_dir/logs"
        cp -Rf "$workspace_dir/logs"/* "$parent_dir/logs/" 2>/dev/null || true
        print_info "Build logs are available in: $workspace_dir/logs"
        
        # If prepareLogs.sh is available, use it to package logs
        if command -v prepareLogs.sh &> /dev/null; then
            print_info "Preparing logs for download..."
            prepareLogs.sh -w "$parent_dir"
            print_success "Logs prepared successfully"
        fi
    fi
    
    print_success "Log collection completed"
}

# Function to package build outputs
# Usage: package_build_outputs <application> <branch> <timestamp> [workspace_dir]
package_build_outputs() {
    local application=$1
    local branch=$2
    local timestamp=$3
    local workspace_dir=${4:-$WORKSPACE_DIR}
    local parent_dir=$(dirname "$workspace_dir")
    
    # If packageBuildOutputs.sh is available, use it
    if command -v packageBuildOutputs.sh &> /dev/null; then
        print_info "Packaging build outputs..."
        
        # packageBuildOutputs.sh expects the workspace to contain the application directory
        # Since our workspace IS the application, we need to use the parent directory
        local package_workspace="$parent_dir"
        
        packageBuildOutputs.sh -w "$package_workspace" -a "$application" -b "$branch" -p build -i "$timestamp" -r "$timestamp"
        print_success "Build outputs packaged successfully"
    else
        print_info "packageBuildOutputs.sh not available, skipping packaging"
    fi
}

# Made with Bob