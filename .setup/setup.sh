
#!/bin/bash

#########################################################
# Setup Script for Pipeline Simulation Environment
# This script prepares the remote z/OS USS environment
#########################################################

set -e  # Exit on error
set -x

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yaml"

# Function to print colored messages
print_info() {
    { set +x; } 2>/dev/null
    echo -e "${BLUE}[INFO]${NC} $1"
    { set -x; } 2>/dev/null
}

print_success() {
    { set +x; } 2>/dev/null
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    { set -x; } 2>/dev/null
}

print_warning() {
    { set +x; } 2>/dev/null
    echo -e "${YELLOW}[WARNING]${NC} $1"
    { set -x; } 2>/dev/null
}

print_error() {
    { set +x; } 2>/dev/null
    echo -e "${RED}[ERROR]${NC} $1"
    { set -x; } 2>/dev/null
}

print_stage() {
    { set +x; } 2>/dev/null
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    { set -x; } 2>/dev/null
}

# Function to parse YAML config (simple parser for our needs)
get_config_value() {
    local key=$1
    local value=$(grep "^[[:space:]]*${key}:" "$CONFIG_FILE" | head -1 | sed 's/^[[:space:]]*[^:]*:[[:space:]]*//' | sed 's/#.*//' | sed 's/[[:space:]]*$//')
    echo "$value"
}

# Function to get value from a specific section
get_section_value() {
    local section=$1
    local key=$2
    local in_section=0
    local value=""
    
    while IFS= read -r line; do
        # Check if we're entering the target section
        if [[ "$line" =~ ^${section}: ]]; then
            in_section=1
            continue
        fi
        
        # Check if we've left the section (new top-level key)
        if [[ $in_section -eq 1 ]] && [[ "$line" =~ ^[a-zA-Z] ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
            break
        fi
        
        # If we're in the section, look for the key
        if [[ $in_section -eq 1 ]] && [[ "$line" =~ ^[[:space:]]+${key}: ]]; then
            value=$(echo "$line" | sed 's/^[[:space:]]*[^:]*:[[:space:]]*//' | sed 's/#.*//' | sed 's/[[:space:]]*$//')
            break
        fi
    done < "$CONFIG_FILE"
    
    echo "$value"
}

# Function to expand variables in config values
expand_vars() {
    local value=$1
    # Replace $USER with actual username
    value="${value//\$USER/$USER}"
    echo "$value"
}

# Function to recursively upload directory contents file by file
upload_directory_recursive() {
    local source_dir=$1
    local target_dir=$2
    local file_count=0
    local error_count=0
    
    print_info "Scanning directory: $source_dir"
    
    # Find all files (not directories) in source directory
    while IFS= read -r -d '' file; do
        # Get relative path from source directory
        local rel_path="${file#$source_dir/}"
        local target_path="$target_dir/$rel_path"
        local target_parent=$(dirname "$target_path")
        
        # Create parent directory on USS if it doesn't exist (ignore errors if already exists)
        zowe rse-api-for-zowe-cli create uss-directory "$target_parent" &> /dev/null
        
        # Upload file
        if zowe rse-api-for-zowe-cli upload file-to-uss "$file" "$target_path" &> /dev/null; then
            ((file_count++))
            if [ $((file_count % 10)) -eq 0 ]; then
                print_info "Uploaded $file_count files..."
            fi
        else
            print_warning "Failed to upload: $rel_path"
            ((error_count++))
        fi
    done < <(find "$source_dir" -type f -print0)
    
    print_info "Upload complete: $file_count files uploaded, $error_count errors"
    
    if [ $error_count -gt 0 ]; then
        return 1
    fi
    return 0
}

# Check if Zowe CLI is installed
check_zowe_cli() {
    print_info "Checking Zowe CLI installation..."
    if ! command -v zowe &> /dev/null; then
        print_error "Zowe CLI is not installed or not in PATH"
        print_info "Please install Zowe CLI: npm install -g @zowe/cli"
        exit 1
    fi
    print_success "Zowe CLI is installed"
    
    # Check if RSE API plugin is installed
    print_info "Checking Zowe RSE API plugin..."
    if ! zowe rse-api-for-zowe-cli --help &> /dev/null; then
        print_warning "Zowe RSE API plugin may not be installed"
        print_info "Install with: zowe plugins install @zowe/rse-api-for-zowe-cli"
    else
        print_success "Zowe RSE API plugin is available"
    fi
}

# Load configuration
load_config() {
    print_info "Loading configuration from $CONFIG_FILE..."
    
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Parse configuration values
    PIPELINE_WORKSPACE=$(expand_vars "$(get_section_value 'global' 'sandbox')")
    BRANCH=$(get_section_value 'pipeline' 'branch')
    TMPHLQ=$(get_section_value 'pipeline' 'tmphlq')
    DBB_REPO_URL=$(get_config_value 'url')
    ZBUILDER_SOURCE="$SCRIPT_DIR/$(get_section_value 'zbuilder' 'source_dir')"
    ZBUILDER_TARGET=$(expand_vars "$(get_section_value 'zbuilder' 'target_dir')")
    PIPELINE_SCRIPT_SOURCE="$SCRIPT_DIR/$(get_section_value 'pipeline_script' 'source')"
    PIPELINE_SCRIPT_TARGET=$(expand_vars "$(get_section_value 'pipeline_script' 'target')")
    
    print_success "Configuration loaded successfully"
    echo "  Workspace: $PIPELINE_WORKSPACE"
    echo "  Branch: $BRANCH"
    echo "  Temp HLQ: $TMPHLQ"
}

#########################################################
# STAGE 1: Initialize Working Directory
#########################################################
stage1_initialize_workspace() {
    print_stage "STAGE 1: Initialize Working Directory"
    
    print_info "Target workspace: $PIPELINE_WORKSPACE"
    
    # Check if directory exists on remote system
    print_info "Checking if workspace directory exists on remote system..."
    
    if zowe rse-api-for-zowe-cli list uss "$PIPELINE_WORKSPACE" &> /dev/null; then
        print_warning "Workspace directory already exists: $PIPELINE_WORKSPACE"
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Deleting existing workspace directory..."
            zowe rse-api-for-zowe-cli delete uss "$PIPELINE_WORKSPACE"
            print_success "Existing workspace deleted"
        else
            print_info "Keeping existing workspace directory"
            return 0
        fi
    fi
    
    # Create workspace directory
    print_info "Creating workspace directory: $PIPELINE_WORKSPACE"
    zowe rse-api-for-zowe-cli create uss-directory "$PIPELINE_WORKSPACE"
    
    print_success "Workspace directory initialized: $PIPELINE_WORKSPACE"
}

#########################################################
# STAGE 2: Clone Required Accelerators
#########################################################
stage2_clone_accelerators() {
    print_stage "STAGE 2: Clone Required Accelerators"
    
    print_info "Cloning DBB repository on remote z/OS system..."
    print_info "Repository: $DBB_REPO_URL"
    print_info "Target: $PIPELINE_WORKSPACE/dbb"
    
    # Check if git is available on the remote system
    print_info "Checking git availability on remote system..."
    if ! zowe rse-api-for-zowe-cli issue unix "which git" --cwd "$PIPELINE_WORKSPACE" &> /dev/null; then
        print_error "Git is not available on the remote z/OS system"
        print_info "Please ensure git is installed and in the PATH on z/OS USS"
        exit 1
    fi
    print_success "Git is available on remote system"
    
    # Check if dbb directory already exists
    print_info "Checking if dbb directory already exists..."
    if zowe rse-api-for-zowe-cli list uss "$PIPELINE_WORKSPACE/dbb" &> /dev/null; then
        print_warning "DBB directory already exists: $PIPELINE_WORKSPACE/dbb"
        read -p "Do you want to delete and re-clone it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Removing existing dbb directory..."
            zowe rse-api-for-zowe-cli issue unix "rm -rf dbb" --cwd "$PIPELINE_WORKSPACE"
            print_success "Existing dbb directory removed"
        else
            print_info "Keeping existing dbb directory"
            return 0
        fi
    fi
    
    # Clone repository on remote system
    print_info "Cloning repository on remote z/OS system (this may take a few minutes)..."
    if zowe rse-api-for-zowe-cli issue unix "git clone $DBB_REPO_URL" --cwd "$PIPELINE_WORKSPACE"; then
        print_success "DBB repository cloned successfully on remote system"
    else
        print_error "Failed to clone DBB repository on remote system"
        print_info "Please check:"
        print_info "  - Network connectivity from z/OS to GitHub"
        print_info "  - Git configuration on z/OS"
        print_info "  - Repository URL: $DBB_REPO_URL"
        exit 1
    fi
    
    # Verify the clone
    print_info "Verifying cloned repository..."
    if zowe rse-api-for-zowe-cli list uss "$PIPELINE_WORKSPACE/dbb" &> /dev/null; then
        print_success "Repository verification successful"
    else
        print_error "Repository verification failed"
        exit 1
    fi
}

#########################################################
# STAGE 3: Upload Build Framework and Scripts
#########################################################
stage3_upload_framework() {
    print_stage "STAGE 3: Upload Build Framework and Scripts"
    
    # Print datasets configuration from Languages.yaml
    print_info "Datasets configuration from Languages.yaml:"
    echo ""
    if [ -f "$ZBUILDER_SOURCE/languages/Languages.yaml" ]; then
        grep -A 200 "^variables:" "$ZBUILDER_SOURCE/languages/Languages.yaml" | grep -E "^[[:space:]]*#.*Example:" | head -20
    else
        print_warning "Languages.yaml not found at: $ZBUILDER_SOURCE/languages/Languages.yaml"
    fi
    echo ""
    
    # Upload zBuilder framework
    print_info "Uploading zBuilder framework to USS..."
    print_info "Source: $ZBUILDER_SOURCE"
    print_info "Target: $ZBUILDER_TARGET"
    
    # Check if source directory exists
    if [ ! -d "$ZBUILDER_SOURCE" ]; then
        print_error "zBuilder source directory not found: $ZBUILDER_SOURCE"
        exit 1
    fi
    
    # Check if target directory already exists
    print_info "Checking if zBuilder directory already exists..."
    if zowe rse-api-for-zowe-cli list uss "$ZBUILDER_TARGET" &> /dev/null; then
        print_warning "zBuilder directory already exists: $ZBUILDER_TARGET"
        read -p "Do you want to delete and re-upload it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Removing existing zBuilder directory..."
            zowe rse-api-for-zowe-cli issue unix "rm -rf $(basename $ZBUILDER_TARGET)" --cwd "$(dirname $ZBUILDER_TARGET)"
            print_success "Existing zBuilder directory removed"
        else
            print_info "Keeping existing zBuilder directory, skipping upload"
            return 0
        fi
    fi
    
    # Create parent directory if needed
    PARENT_DIR=$(dirname "$ZBUILDER_TARGET")
    print_info "Ensuring parent directory exists: $PARENT_DIR"
    if ! zowe rse-api-for-zowe-cli list uss "$PARENT_DIR" &> /dev/null; then
        zowe rse-api-for-zowe-cli create uss-directory "$PARENT_DIR"
    else
        print_info "Parent directory already exists: $PARENT_DIR"
    fi
    
    # Create target directory
    print_info "Creating target directory: $ZBUILDER_TARGET"
    if ! zowe rse-api-for-zowe-cli create uss-directory "$ZBUILDER_TARGET" &> /dev/null; then
        print_warning "Target directory may already exist or creation failed"
    fi
    
    # Upload directory recursively file by file
    print_info "Uploading zBuilder framework files (this may take a few minutes)..."
    if upload_directory_recursive "$ZBUILDER_SOURCE" "$ZBUILDER_TARGET"; then
        print_success "zBuilder framework uploaded successfully"
    else
        print_error "Failed to upload zBuilder framework (some files may have failed)"
        exit 1
    fi
    
    print_success "zBuilder framework upload completed successfully"
    print_info "Note: Pipeline simulation script will be uploaded when you run the 'Run Pipeline Simulation' task"
}

#########################################################
# Main execution
#########################################################
main() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Pipeline Simulation Environment Setup Script      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Check prerequisites
    check_zowe_cli
    
    # Load configuration
    load_config
    
    # Execute stages
    stage1_initialize_workspace
    stage2_clone_accelerators
    stage3_upload_framework
    
    # Summary
    print_stage "SETUP COMPLETE"
    print_success "Environment setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Review the uploaded files on USS"
    echo "  3. Run the pipeline simulation task from VS Code"
    echo ""
}

# Run main function
main "$@"

# Made with Bob
