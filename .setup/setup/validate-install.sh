#!/bin/env bash
set -e
# =============================================================================
# Script  : validate.sh
# Summary : Validate installed components and their versions
#
# - Validates DBB runtime environment
# - Validates ZOAU installation
# - Validates zconfig installation
# - Validates Wazi Deploy installation
# - Checks minimum version requirements
# - Reports validation results
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"
cd "$SCRIPTS_DIR"

exec > >(while IFS= read -r line; do
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    printf "${CYAN}[VALIDATE]${NC} %s\n" "${line}"
done) 2>&1

# =========================
# Environment
# =========================
export DBB_CONFG_HOME=$(get_section_value 'dbb' 'dbb_home')
if [ -f "$DBB_CONFG_HOME/bin/dbb" ]; then
    export DBB_HOME=$DBB_CONFG_HOME
fi
export PATH="$DBB_HOME/bin:$ZOAU_HOME/bin:$PATH"
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"

# =========================
# Validation counters
# =========================
VALIDATION_PASSED=0
VALIDATION_FAILED=0
VALIDATION_WARNINGS=0

# =========================
# Version comparison function
# =========================
version_compare() {
    local version=$1
    local minimum=$2
    
    # Convert versions to comparable format (remove non-numeric suffixes)
    local ver_clean=$(echo "$version" | sed 's/[^0-9.].*$//')
    local min_clean=$(echo "$minimum" | sed 's/[^0-9.].*$//')
    
    # Simple version comparison without sort -V
    # Split versions into arrays
    IFS='.' read -ra ver_parts <<< "$ver_clean"
    IFS='.' read -ra min_parts <<< "$min_clean"
    
    # Compare each part
    local max_parts=${#ver_parts[@]}
    [ ${#min_parts[@]} -gt $max_parts ] && max_parts=${#min_parts[@]}
    
    for ((i=0; i<max_parts; i++)); do
        local v=${ver_parts[$i]:-0}
        local m=${min_parts[$i]:-0}
        
        if [ "$v" -gt "$m" ]; then
            return 0  # version > minimum
        elif [ "$v" -lt "$m" ]; then
            return 1  # version < minimum
        fi
    done
    
    return 0  # versions are equal
}

# =========================
# Validation: DBB Runtime
# =========================
print_info "========================================="
print_info "Checking DBB Runtime Environment"
print_info "========================================="

DBB_MIN_VERSION="3.0.5"

if command -v dbb >/dev/null 2>&1; then
    DBB_OUTPUT=$(dbb --version 2>&1 || true)
    print_info "DBB Output:"
    if [ -n "$DBB_OUTPUT" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] && print_info "  $line"
        done <<< "$DBB_OUTPUT"
    fi
    
    # Extract version from output
    DBB_VERSION=$(echo "$DBB_OUTPUT" | grep -i "Dependency Based Build version" | sed 's/.*version \([0-9.]*\).*/\1/' || echo "unknown")
    
    if [ "$DBB_VERSION" != "unknown" ]; then
        print_info "Detected DBB version: $DBB_VERSION"
        print_info "Minimum required version: $DBB_MIN_VERSION"
        
        if version_compare "$DBB_VERSION" "$DBB_MIN_VERSION"; then
            print_success "DBB version check PASSED"
            VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
        else
            print_error "DBB version check FAILED (found $DBB_VERSION, need $DBB_MIN_VERSION)"
            VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
        fi
    else
        print_warning "Could not determine DBB version"
        VALIDATION_WARNINGS=$((VALIDATION_WARNINGS + 1))
    fi
else
    print_error "DBB command not found in PATH"
    print_error "Expected location: $DBB_HOME/bin/dbb"
    VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
fi

# =========================
# Validation: ZOAU
# =========================
print_info "========================================="
print_info "Checking ZOAU Installation"
print_info "========================================="

ZOAU_MIN_VERSION="1.4.1.0"

if command -v zoauversion >/dev/null 2>&1; then
    ZOAU_OUTPUT=$(zoauversion 2>&1 || true)
    print_info "ZOAU Output:"
    if [ -n "$ZOAU_OUTPUT" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] && print_info "  $line"
        done <<< "$ZOAU_OUTPUT"
    fi
    
    # Extract version from output (format: "2026/02/27 09:00:18 CUT v1.4.1.0 ...")
    ZOAU_VERSION=$(echo "$ZOAU_OUTPUT" | sed -n 's/.*v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' || echo "unknown")
    [ -z "$ZOAU_VERSION" ] && ZOAU_VERSION="unknown"
    
    if [ "$ZOAU_VERSION" != "unknown" ]; then
        print_info "Detected ZOAU version: $ZOAU_VERSION"
        print_info "Minimum required version: $ZOAU_MIN_VERSION"
        
        if version_compare "$ZOAU_VERSION" "$ZOAU_MIN_VERSION"; then
            print_success "ZOAU version check PASSED"
            VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
        else
            print_error "ZOAU version check FAILED (found $ZOAU_VERSION, need $ZOAU_MIN_VERSION)"
            VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
        fi
    else
        print_warning "Could not determine ZOAU version"
        VALIDATION_WARNINGS=$((VALIDATION_WARNINGS + 1))
    fi
else
    print_error "zoauversion command not found in PATH"
    print_error "Expected location: $ZOAU_HOME/bin/zoauversion"
    VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
fi

# =========================
# Validation: zconfig
# =========================
print_info "========================================="
print_info "Checking zconfig Installation"
print_info "========================================="

if [ -f "$ZCONFIG_HOME/bin/activate" ]; then
    print_info "Found zconfig activation script: $ZCONFIG_HOME/bin/activate"
    
    # Test zconfig by sourcing and running ls command
    ZCONFIG_OUTPUT=$(bash -c "source '$ZCONFIG_HOME/bin/activate' && zconfig ls 2>&1" || true)
    
    if echo "$ZCONFIG_OUTPUT" | grep -q "TYPE"; then
        print_info "zconfig Output:"
        ZCONFIG_PREVIEW=$(echo "$ZCONFIG_OUTPUT" | head -5)
        if [ -n "$ZCONFIG_PREVIEW" ]; then
            while IFS= read -r line; do
                [ -n "$line" ] && print_info "  $line"
            done <<< "$ZCONFIG_PREVIEW"
        fi
        print_success "zconfig installation check PASSED"
        VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
    else
        print_error "zconfig command failed or returned unexpected output"
        print_info "Output: $ZCONFIG_OUTPUT"
        VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
    fi
else
    print_error "zconfig activation script not found"
    print_error "Expected location: $ZCONFIG_HOME/bin/activate"
    VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
fi

# =========================
# Validation: Wazi Deploy
# =========================
print_info "========================================="
print_info "Checking Wazi Deploy Installation"
print_info "========================================="

WAZIDEPLOY_MIN_VERSION="3.0.7.3"

if [ -f "$DEPLOY_WAZIDEPLOY_HOME/bin/activate" ]; then
    print_info "Found Wazi Deploy activation script: $DEPLOY_WAZIDEPLOY_HOME/bin/activate"
    
    # Test wazideploy-deploy version
    WAZIDEPLOY_OUTPUT=$(bash -c "source '$DEPLOY_WAZIDEPLOY_HOME/bin/activate' && wazideploy-deploy --version 2>&1" || true)
    
    print_info "Wazi Deploy Output:"
    if [ -n "$WAZIDEPLOY_OUTPUT" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] && print_info "  $line"
        done <<< "$WAZIDEPLOY_OUTPUT"
    fi
    
    # Extract version from output (format: "Version: 3.0.7.3")
    WAZIDEPLOY_VERSION=$(echo "$WAZIDEPLOY_OUTPUT" | grep -i "Version:" | sed 's/.*Version: \([0-9.]*\).*/\1/' || echo "unknown")
    
    if [ "$WAZIDEPLOY_VERSION" != "unknown" ]; then
        print_info "Detected Wazi Deploy version: $WAZIDEPLOY_VERSION"
        print_info "Minimum required version: $WAZIDEPLOY_MIN_VERSION"
        
        if version_compare "$WAZIDEPLOY_VERSION" "$WAZIDEPLOY_MIN_VERSION"; then
            print_success "Wazi Deploy version check PASSED"
            VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
        else
            print_error "Wazi Deploy version check FAILED (found $WAZIDEPLOY_VERSION, need $WAZIDEPLOY_MIN_VERSION)"
            VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
        fi
    else
        print_warning "Could not determine Wazi Deploy version"
        VALIDATION_WARNINGS=$((VALIDATION_WARNINGS + 1))
    fi
else
    print_error "Wazi Deploy activation script not found"
    print_error "Expected location: $DEPLOY_WAZIDEPLOY_HOME/bin/activate"
    VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
fi

# =========================
# Summary
# =========================
print_info "========================================="
print_info "Validation Summary"
print_info "========================================="
print_info "Checks passed:  $VALIDATION_PASSED"
print_info "Checks failed:  $VALIDATION_FAILED"
print_info "Warnings:       $VALIDATION_WARNINGS"

if [ $VALIDATION_FAILED -eq 0 ]; then
    print_success "All validation checks PASSED"
    exit 0
else
    print_error "Validation FAILED with $VALIDATION_FAILED error(s)"
    exit 1
fi

# Made with Bob
