#!/bin/bash
# =============================================================================
# Script  : build-and-deploy-orchestrator.sh
# Summary : Build and deploy in one go (so TAR file persists)
# =============================================================================

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/.setup/config/setenv.sh"

# =========================
# Logging Functions
# =========================
print_info() {
    echo "[INFO] $1"
}

print_success() {
    echo "[SUCCESS] $1"
}

print_error() {
    echo "[ERROR] $1" >&2
}

# =========================
# DBB Environment Setup
# =========================
setup_dbb_env() {
    print_info "Setting up DBB environment..."
    
    # Load DBB configuration
    export DBB_HOME=$(get_section_value 'dbb' 'dbb_home')
    export DBB_BUILD=$(get_section_value 'dbb' 'dbb_build')
    export JAVA_HOME=$(get_section_value 'java' 'java_home')
    
    # Gradle/Maven environment
    export GRADLE_USER_HOME="$SANDBOX_DIR/../.gradle"
    export GRADLE_OPTS="-Dfile.encoding=UTF-8"
    export MAVEN_OPTS="-Dmaven.repo.local=$SANDBOX_DIR/../.m2/repository"
    
    # Add DBB to PATH
    export PATH="$DBB_HOME/bin:$JAVA_HOME/bin:$PATH"
    
    print_info "DBB environment loaded"
    print_info "  DBB_HOME: $DBB_HOME"
    print_info "  DBB_BUILD: $DBB_BUILD"
    print_info "  JAVA_HOME: $JAVA_HOME"
}

# =========================
# Run DBB Build
# =========================
run_dbb_build() {
    local lifecycle=$1
    shift
    
    print_info "Executing DBB $lifecycle build..."
    
    local DBB_APP_CONF="$REPO_ROOT/dbb-app.yaml"
    
    print_info "Executing: dbb build $lifecycle --config $DBB_APP_CONF --hlq ${APP_BASE_NAME}.DBB --log-encoding ISO8859-1 $@"
    
    dbb build $lifecycle \
        --config "$DBB_APP_CONF" \
        --hlq "${APP_BASE_NAME}.DBB" \
        --log-encoding ISO8859-1 \
        "$@"
    
    local rc=$?
    if [ $rc -eq 0 ]; then
        print_success "DBB build completed successfully"
        return 0
    else
        print_error "DBB build failed with RC=$rc"
        return $rc
    fi
}

# =========================
# Main Build and Deploy
# =========================
main() {
    print_info "=== GRUB Incremental Build and Deploy ==="
    
    # Setup environment first
    setup_dbb_env
    
    print_info ""
    print_info "Step 1: Running DBB pipeline build"
    print_info "DBB will detect changes via git and build only what's needed"
    
    # Run incremental build (DBB handles incrementality via git)
    run_dbb_build pipeline \
        --config "$REPO_ROOT/dbb-app.yaml" \
        --hlq "${APP_BASE_NAME}.DBB" \
        --log-encoding ISO8859-1
    
    print_success "Incremental build complete"
    
    # Now deploy
    print_info ""
    print_info "Step 2: Deploying build package"
    
    # Find the latest package
    LOGS_DIR="$REPO_ROOT/logs"
    LATEST_PACKAGE=$(ls -t "$LOGS_DIR"/${APP_BASE_NAME}-*.tar 2>/dev/null | grep -v ".deployed$" | head -1)
    
    if [ -z "$LATEST_PACKAGE" ]; then
        print_info "No package generated - nothing to deploy (no compiled artifacts changed)"
        print_success "Build and deployment complete! (no-op deploy)"
        exit 0
    fi
    
    print_info "Found package: $(basename "$LATEST_PACKAGE")"
    
    # Export PACKAGE_URL so it persists through setenv.sh sourcing
    export PACKAGE_URL="$LATEST_PACKAGE"
    
    # Determine what was ACTUALLY CHANGED by checking git diff
    # This is more accurate than checking package contents (which is cumulative)
    print_info "Analyzing git changes to determine deployment strategy..."
    
    # Save current directory and change to repo root
    ORIG_DIR=$(pwd)
    cd "$REPO_ROOT" 2>/dev/null || cd /usr/local/sandboxes/bank-of-z/Bank-of-Z
    
    # Unset GIT_DIR to ensure git commands work in current directory
    unset GIT_DIR
    
    # Get list of changed files from git (last commit)
    CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || echo "")
    
    # Return to original directory
    cd "$ORIG_DIR"
    
    if [ -z "$CHANGED_FILES" ]; then
        print_info "No git changes detected, checking package contents as fallback..."
        CHANGED_FILES=$(tar -tf "$LATEST_PACKAGE" 2>/dev/null | grep -E '\.(war|cbl|pli|asm|html|js|css|yaml)$' || true)
    fi
    
    # Determine deployment tags based on what actually changed
    DEPLOY_TAGS=""
    
    # Check what types of files changed
    HAS_FRONTEND_CHANGES=$(echo "$CHANGED_FILES" | grep -qE '(src/frontend/|\.html$|\.js$|\.css$)' && echo "yes" || echo "no")
    HAS_BACKEND_CHANGES=$(echo "$CHANGED_FILES" | grep -qE '(src/base/cics/|src/base/ims/|\.cbl$|\.pli$|\.asm$|\.bms$)' && echo "yes" || echo "no")
    HAS_API_CHANGES=$(echo "$CHANGED_FILES" | grep -qE '(src/api/|openapi\.yaml)' && echo "yes" || echo "no")
    HAS_IMS_CHANGES=$(echo "$CHANGED_FILES" | grep -qE 'src/base/ims/' && echo "yes" || echo "no")
    
    if [ "$HAS_IMS_CHANGES" = "yes" ]; then
        # IMS components always need full deployment with IMS catalog
        DEPLOY_TAGS="-pt deploy,ims_catalog_management,zosconnect_copy,zosconnect_config,zosconnect_refresh"
        print_info "Detected IMS changes - full deployment with IMS catalog"
    elif [ "$HAS_FRONTEND_CHANGES" = "yes" ] && [ "$HAS_BACKEND_CHANGES" = "yes" ]; then
        # Both frontend and backend changed - need ALL deployment tags
        DEPLOY_TAGS="-pt deploy,zosconnect_copy,zosconnect_config,zosconnect_refresh"
        print_info "Detected frontend + backend changes - full deployment"
    elif [ "$HAS_FRONTEND_CHANGES" = "yes" ] || [ "$HAS_API_CHANGES" = "yes" ]; then
        # Frontend or API only - skip CICS/DB2/IMS
        DEPLOY_TAGS="-pt zosconnect_copy,zosconnect_config,zosconnect_refresh"
        print_info "Detected frontend/API-only changes - deploying WAR files only (skipping CICS/DB2/IMS)"
    elif [ "$HAS_BACKEND_CHANGES" = "yes" ]; then
        # Backend only - full deployment (no WAR files)
        DEPLOY_TAGS="-pt deploy"
        print_info "Detected backend-only changes - deploying CICS/DB2 only (skipping WAR files)"
    else
        # Default - full deployment with WAR files
        DEPLOY_TAGS="-pt deploy,zosconnect_copy,zosconnect_config,zosconnect_refresh"
        print_info "Using default full deployment"
    fi
    
    # Run wazideploy with appropriate tags
    print_info "Executing wazideploy with PACKAGE_URL=$PACKAGE_URL"
    bash "$REPO_ROOT/.setup/tasks/task-wazi-deploy.sh" $DEPLOY_TAGS
    
    print_success "Build and deployment complete!"
    print_info "Changes should now be visible on the website"
}

main "$@"

