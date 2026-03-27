#!/bin/bash

#########################################################
# Prerequisites Check Library
# Provides functions for verifying required tools
# and installations
#########################################################

# Function to check if DBB is installed
# Usage: check_dbb_installation
check_dbb_installation() {
    if [ ! -d "$DBB_HOME" ]; then
        print_error "DBB not found at $DBB_HOME"
        print_info "Please ensure DBB is installed on z/OS"
        return 1
    fi
    print_success "DBB installation found"
    return 0
}

# Function to check if Java is installed and valid
# Usage: check_java_installation
check_java_installation() {
    if [ -z "$JAVA_HOME" ]; then
        print_error "JAVA_HOME is not set"
        print_info "Please set JAVA_HOME environment variable or add it to the build script"
        print_info "Common z/OS Java locations: /usr/lpp/java/J8.0_64, /usr/lpp/java/J8.0"
        return 1
    fi
    
    if [ ! -d "$JAVA_HOME" ]; then
        print_error "JAVA_HOME directory does not exist: $JAVA_HOME"
        print_info "Please verify the Java installation path"
        return 1
    fi
    print_success "Java installation found at $JAVA_HOME"
    return 0
}

# Function to check if DBB build configuration exists
# Usage: check_dbb_build_config [dbb_build_path]
check_dbb_build_config() {
    local dbb_build_path=${1:-$DBB_BUILD_PATH}
    
    if [ ! -f "$dbb_build_path/dbb-build.yaml" ]; then
        print_error "DBB build configuration not found at $dbb_build_path/dbb-build.yaml"
        print_info "Expected location: $WORKSPACE_DIR/.setup/build/dbb-build.yaml"
        return 1
    fi
    print_success "DBB build configuration found at $dbb_build_path"
    return 0
}

# Function to check if git is available
# Usage: check_git_available
check_git_available() {
    if ! command -v git &> /dev/null; then
        print_error "Git is not available"
        print_info "Please ensure git is installed and in PATH"
        return 1
    fi
    print_success "Git is available"
    return 0
}

# Function to check if Zowe CLI is installed
# Usage: check_zowe_cli
check_zowe_cli() {
    print_info "Checking Zowe CLI installation..."
    if ! command -v zowe &> /dev/null; then
        print_error "Zowe CLI is not installed or not in PATH"
        print_info "Please install Zowe CLI: npm install -g @zowe/cli"
        return 1
    fi
    print_success "Zowe CLI is installed"
    
    # Check if RSE API plugin is installed
    print_info "Checking Zowe RSE API plugin..."
    if ! zowe rse-api-for-zowe-cli --help &> /dev/null; then
        print_warning "Zowe RSE API plugin may not be installed"
        print_info "Install with: zowe plugins install @zowe/rse-api-for-zowe-cli"
        return 1
    else
        print_success "Zowe RSE API plugin is available"
    fi
    return 0
}

# Function to verify all prerequisites for build
# Usage: verify_build_prerequisites
verify_build_prerequisites() {
    local rc=0
    
    check_dbb_installation || rc=1
    check_java_installation || rc=1
    check_dbb_build_config || rc=1
    
    return $rc
}

# Made with Bob