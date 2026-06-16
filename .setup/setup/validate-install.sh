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

# =========================
# Environment
# =========================
export DBB_HOME="${DBB_HOME:-$(get_section_value 'dbb' 'dbb_home')}"
export ZOAU_HOME="${ZOAU_HOME:-$(get_section_value 'zoau' 'zoau_home')}"
export ZCONFIG_HOME="${ZCONFIG_HOME:-$(get_section_value 'zconfig' 'zconfig_home')}"
export WAZIDEPLOY_HOME="${WAZIDEPLOY_HOME:-$(get_section_value 'wazideploy' 'wazideploy_home')}"
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
print_info "${CYAN}[VALIDATE]${NC} ========================================="
print_info "${CYAN}[VALIDATE]${NC} Checking DBB Runtime Environment"
print_info "${CYAN}[VALIDATE]${NC} ========================================="

DBB_MIN_VERSION="3.0.4.1"

if command -v dbb >/dev/null 2>&1; then
    DBB_OUTPUT=$(dbb --version 2>&1 || true)
    print_info "${CYAN}[VALIDATE]${NC} DBB Output:"
    if [ -n "$DBB_OUTPUT" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] && print_info "${CYAN}[VALIDATE]${NC}   $line"
        done <<< "$DBB_OUTPUT"
    fi
    
    # Extract version from output
    DBB_VERSION=$(echo "$DBB_OUTPUT" | grep -i "Dependency Based Build version" | sed 's/.*version \([0-9.]*\).*/\1/' || echo "unknown")
    
    if [ "$DBB_VERSION" != "unknown" ]; then
        print_info "${CYAN}[VALIDATE]${NC} Detected DBB version: $DBB_VERSION"
        print_info "${CYAN}[VALIDATE]${NC} Minimum required version: $DBB_MIN_VERSION"
        
        if version_compare "$DBB_VERSION" "$DBB_MIN_VERSION"; then
            print_success "${GREEN}[VALIDATE]${NC} DBB version check PASSED"
            VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
        else
            print_error "${RED}[VALIDATE]${NC} DBB version check FAILED (found $DBB_VERSION, need $DBB_MIN_VERSION)"
            VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
        fi
    else
        print_warning "${YELLOW}[VALIDATE]${NC} Could not determine DBB version"
        VALIDATION_WARNINGS=$((VALIDATION_WARNINGS + 1))
    fi
else
    print_error "${RED}[VALIDATE]${NC} DBB command not found in PATH"
    print_error "${RED}[VALIDATE]${NC} Expected location: $DBB_HOME/bin/dbb"
    VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
fi

# =========================
# Validation: ZOAU
# =========================
print_info "${CYAN}[VALIDATE]${NC} ========================================="
print_info "${CYAN}[VALIDATE]${NC} Checking ZOAU Installation"
print_info "${CYAN}[VALIDATE]${NC} ========================================="

ZOAU_MIN_VERSION="1.4.1.0"

if command -v zoauversion >/dev/null 2>&1; then
    ZOAU_OUTPUT=$(zoauversion 2>&1 || true)
    print_info "${CYAN}[VALIDATE]${NC} ZOAU Output:"
    if [ -n "$ZOAU_OUTPUT" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] && print_info "${CYAN}[VALIDATE]${NC}   $line"
        done <<< "$ZOAU_OUTPUT"
    fi
    
    # Extract version from output (format: "2026/02/27 09:00:18 CUT v1.4.1.0 ...")
    ZOAU_VERSION=$(echo "$ZOAU_OUTPUT" | sed -n 's/.*v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' || echo "unknown")
    [ -z "$ZOAU_VERSION" ] && ZOAU_VERSION="unknown"
    
    if [ "$ZOAU_VERSION" != "unknown" ]; then
        print_info "${CYAN}[VALIDATE]${NC} Detected ZOAU version: $ZOAU_VERSION"
        print_info "${CYAN}[VALIDATE]${NC} Minimum required version: $ZOAU_MIN_VERSION"
        
        if version_compare "$ZOAU_VERSION" "$ZOAU_MIN_VERSION"; then
            print_success "${GREEN}[VALIDATE]${NC} ZOAU version check PASSED"
            VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
        else
            print_error "${RED}[VALIDATE]${NC} ZOAU version check FAILED (found $ZOAU_VERSION, need $ZOAU_MIN_VERSION)"
            VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
        fi
    else
        print_warning "${YELLOW}[VALIDATE]${NC} Could not determine ZOAU version"
        VALIDATION_WARNINGS=$((VALIDATION_WARNINGS + 1))
    fi
else
    print_error "${RED}[VALIDATE]${NC} zoauversion command not found in PATH"
    print_error "${RED}[VALIDATE]${NC} Expected location: $ZOAU_HOME/bin/zoauversion"
    VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
fi

# =========================
# Validation: zconfig
# =========================
print_info "${CYAN}[VALIDATE]${NC} ========================================="
print_info "${CYAN}[VALIDATE]${NC} Checking zconfig Installation"
print_info "${CYAN}[VALIDATE]${NC} ========================================="

if [ -f "$ZCONFIG_HOME/bin/activate" ]; then
    print_info "${CYAN}[VALIDATE]${NC} Found zconfig activation script: $ZCONFIG_HOME/bin/activate"
    
    # Test zconfig by sourcing and running ls command
    ZCONFIG_OUTPUT=$(bash -c "source '$ZCONFIG_HOME/bin/activate' && zconfig ls 2>&1" || true)
    
    if echo "$ZCONFIG_OUTPUT" | grep -q "TYPE"; then
        print_info "${CYAN}[VALIDATE]${NC} zconfig Output:"
        ZCONFIG_PREVIEW=$(echo "$ZCONFIG_OUTPUT" | head -5)
        if [ -n "$ZCONFIG_PREVIEW" ]; then
            while IFS= read -r line; do
                [ -n "$line" ] && print_info "${CYAN}[VALIDATE]${NC}   $line"
            done <<< "$ZCONFIG_PREVIEW"
        fi
        print_success "${GREEN}[VALIDATE]${NC} zconfig installation check PASSED"
        VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
    else
        print_error "${RED}[VALIDATE]${NC} zconfig command failed or returned unexpected output"
        print_info "${CYAN}[VALIDATE]${NC} Output: $ZCONFIG_OUTPUT"
        VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
    fi
else
    print_error "${RED}[VALIDATE]${NC} zconfig activation script not found"
    print_error "${RED}[VALIDATE]${NC} Expected location: $ZCONFIG_HOME/bin/activate"
    VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
fi

# =========================
# Validation: Wazi Deploy
# =========================
print_info "${CYAN}[VALIDATE]${NC} ========================================="
print_info "${CYAN}[VALIDATE]${NC} Checking Wazi Deploy Installation"
print_info "${CYAN}[VALIDATE]${NC} ========================================="

WAZIDEPLOY_MIN_VERSION="3.0.7.1"

if [ -f "$WAZIDEPLOY_HOME/bin/activate" ]; then
    print_info "${CYAN}[VALIDATE]${NC} Found Wazi Deploy activation script: $WAZIDEPLOY_HOME/bin/activate"
    
    # Test wazideploy-deploy version
    WAZIDEPLOY_OUTPUT=$(bash -c "source '$WAZIDEPLOY_HOME/bin/activate' && wazideploy-deploy --version 2>&1" || true)
    
    print_info "${CYAN}[VALIDATE]${NC} Wazi Deploy Output:"
    if [ -n "$WAZIDEPLOY_OUTPUT" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] && print_info "${CYAN}[VALIDATE]${NC}   $line"
        done <<< "$WAZIDEPLOY_OUTPUT"
    fi
    
    # Extract version from output (format: "Version: 3.0.7.3")
    WAZIDEPLOY_VERSION=$(echo "$WAZIDEPLOY_OUTPUT" | grep -i "Version:" | sed 's/.*Version: \([0-9.]*\).*/\1/' || echo "unknown")
    
    if [ "$WAZIDEPLOY_VERSION" != "unknown" ]; then
        print_info "${CYAN}[VALIDATE]${NC} Detected Wazi Deploy version: $WAZIDEPLOY_VERSION"
        print_info "${CYAN}[VALIDATE]${NC} Minimum required version: $WAZIDEPLOY_MIN_VERSION"
        
        if version_compare "$WAZIDEPLOY_VERSION" "$WAZIDEPLOY_MIN_VERSION"; then
            print_success "${GREEN}[VALIDATE]${NC} Wazi Deploy version check PASSED"
            VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
        else
            print_error "${RED}[VALIDATE]${NC} Wazi Deploy version check FAILED (found $WAZIDEPLOY_VERSION, need $WAZIDEPLOY_MIN_VERSION)"
            VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
        fi
    else
        print_warning "${YELLOW}[VALIDATE]${NC} Could not determine Wazi Deploy version"
        VALIDATION_WARNINGS=$((VALIDATION_WARNINGS + 1))
    fi
else
    print_error "${RED}[VALIDATE]${NC} Wazi Deploy activation script not found"
    print_error "${RED}[VALIDATE]${NC} Expected location: $WAZIDEPLOY_HOME/bin/activate"
    VALIDATION_FAILED=$((VALIDATION_FAILED + 1))
fi

# =========================
# Summary
# =========================
print_info "${CYAN}[VALIDATE]${NC} ========================================="
print_info "${CYAN}[VALIDATE]${NC} Validation Summary"
print_info "${CYAN}[VALIDATE]${NC} ========================================="
print_info "${CYAN}[VALIDATE]${NC} Checks passed:  $VALIDATION_PASSED"
print_info "${CYAN}[VALIDATE]${NC} Checks failed:  $VALIDATION_FAILED"
print_info "${CYAN}[VALIDATE]${NC} Warnings:       $VALIDATION_WARNINGS"

if [ $VALIDATION_FAILED -eq 0 ]; then
    print_success "${GREEN}[VALIDATE]${NC} All validation checks PASSED"
    exit 0
else
    print_error "${RED}[VALIDATE]${NC} Validation FAILED with $VALIDATION_FAILED error(s)"
    exit 1
fi

# Made with Bob
