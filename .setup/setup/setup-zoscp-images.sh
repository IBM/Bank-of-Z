#!/bin/env bash
set -e
# =============================================================================
# Script  : setup-zoscp-images.sh
# Summary : Pull IBM z/OS Container Platform images
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# - Pulls IBM z/OS Connect container image
# - Pulls IBM Java container image
#
# Note: To be able to pull the images, you must have appropriate entitlement keys
#
## =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/../config/setenv.sh"

# =========================
# Validate Image Admin Role
# =========================
print_stage "Validate Image Admin RACF Permissions"
print_info "${CYAN}[ZOSCP]${NC} Checking FACILITY class profiles for image admin role..."

IMGADMIN_PROFILES=(
    "BPX.FILEATTR.APF"
    "BPX.FILEATTR.PROGCTL"
    "BPX.FILEATTR.SHARELIB"
)

CURRENT_USER=$(echo "${ZOS_USER:-$USER}" | tr '[:lower:]' '[:upper:]')
IMGADMIN_FAILED=0

# Verify the current session is running as UID 0
UID_OUTPUT=$(id 2>&1)
print_info "${CYAN}[ZOSCP]${NC} Current identity: $UID_OUTPUT"
if echo "$UID_OUTPUT" | grep -q "uid=0"; then
    print_success "${GREEN}[ZOSCP]${NC} Running as UID 0 - confirmed"
else
    print_error "${RED}[ZOSCP]${NC} Not running as UID 0 - this script must be run after switching to a UID 0 userid"
    print_error "${RED}[ZOSCP]${NC} This ensures images are pulled into /var/lib/podman/storage for other users of Podman."
    exit 1
fi

set +e
for PROFILE in "${IMGADMIN_PROFILES[@]}"; do
    RL_OUTPUT=$(tsocmd "RL FACILITY $PROFILE AUTHUSER" 2>&1 || true)
    if echo "$RL_OUTPUT" | grep -qi "READ"; then
        print_success "${GREEN}[ZOSCP]${NC} FACILITY profile $PROFILE - access confirmed for $CURRENT_USER"
    else
        print_error "${RED}[ZOSCP]${NC} FACILITY profile $PROFILE - access NOT found for $CURRENT_USER"
        print_error "${RED}[ZOSCP]${NC} Run: PERMIT $PROFILE CL(FACILITY) ACC(READ) ID($CURRENT_USER)"
        IMGADMIN_FAILED=$((IMGADMIN_FAILED + 1))
    fi
done
set -e

if [ $IMGADMIN_FAILED -gt 0 ]; then
    print_error "${RED}[ZOSCP]${NC} Image admin role check FAILED - $IMGADMIN_FAILED profile(s) missing"
    exit 1
fi
print_success "Image admin role check PASSED"

# =========================
# Pull z/OS Container Platform images
# =========================
print_stage "Pull z/OS Container Platform Images"

ZOSCP_PODMAN="/usr/lpp/IBM/zoscp/bin/podman"

# Load registry secrets from protected file (chmod 600, not in git).
# Each registry requires a named variable: REGISTRY_API_KEY_<NAME>=<secret>
# All non-secret config (image, registry, username, api_key_var) is in config.yaml.
REGISTRY_CREDENTIALS_FILE="$HOME/.profile.bankz"
if [ ! -f "$REGISTRY_CREDENTIALS_FILE" ]; then
    print_error "${RED}[ZOSCP]${NC} Registry credentials file not found: $REGISTRY_CREDENTIALS_FILE"
    print_error "${RED}[ZOSCP]${NC} Add REGISTRY_API_KEY_<NAME> entries to $REGISTRY_CREDENTIALS_FILE and chmod 600 $REGISTRY_CREDENTIALS_FILE"
    exit 1
fi
source "$REGISTRY_CREDENTIALS_FILE"

# ---------------------------------------------------------------------------
# Images: "IMAGE|REGISTRY|USERNAME|API_KEY_VAR"
# Add new entries here when pulling additional images.
# ---------------------------------------------------------------------------
IMAGES=(
    "${ZOSCP_ZOSCONNECT_IMAGE}|${ZOSCP_ZOSCONNECT_REGISTRY}|${ZOSCP_ZOSCONNECT_REGISTRY_USERNAME}|${ZOSCP_ZOSCONNECT_API_KEY_VAR}"
    "${ZOSCP_JAVA_IMAGE}|${ZOSCP_JAVA_REGISTRY}|${ZOSCP_JAVA_REGISTRY_USERNAME}|${ZOSCP_JAVA_API_KEY_VAR}"
)

# ---------------------------------------------------------------------------
# Login once per unique registry
# ---------------------------------------------------------------------------
LOGGED_IN_REGISTRIES=""

for ENTRY in "${IMAGES[@]}"; do
    IFS='|' read -r IMAGE REGISTRY USERNAME API_KEY_VAR <<< "$ENTRY"

    if ! echo "$LOGGED_IN_REGISTRIES" | grep -qF "|${REGISTRY}|"; then
        API_KEY=$(eval echo "\$$API_KEY_VAR")
        if [ -z "$API_KEY" ]; then
            print_error "${RED}[ZOSCP]${NC} $API_KEY_VAR is not set in $REGISTRY_CREDENTIALS_FILE"
            exit 1
        fi

        print_info "${CYAN}[ZOSCP]${NC} Logging in to registry: $REGISTRY (username: $USERNAME)..."
        echo "$API_KEY" | "$ZOSCP_PODMAN" login "$REGISTRY" --username "$USERNAME" --password-stdin
        RC=$?
        if [ $RC -ne 0 ]; then
            print_error "${RED}[ZOSCP]${NC} Login failed for $REGISTRY (RC=$RC)"
            exit 1
        fi
        print_success "${GREEN}[ZOSCP]${NC} Login successful: $REGISTRY"
        LOGGED_IN_REGISTRIES="${LOGGED_IN_REGISTRIES}|${REGISTRY}|"
    fi
done

# ---------------------------------------------------------------------------
# Pull images — continue on failure, report all results at end
# ---------------------------------------------------------------------------
PULL_FAILED=""

set +e
for ENTRY in "${IMAGES[@]}"; do
    IFS='|' read -r IMAGE REGISTRY USERNAME API_KEY_VAR <<< "$ENTRY"

    print_info "${CYAN}[ZOSCP]${NC} Pulling image: $IMAGE"
    "$ZOSCP_PODMAN" pull "$IMAGE"
    RC=$?
    if [ $RC -ne 0 ]; then
        print_error "${RED}[ZOSCP]${NC} Failed to pull $IMAGE (RC=$RC)"
        PULL_FAILED="${PULL_FAILED}  - $IMAGE\n"
    else
        print_success "${GREEN}[ZOSCP]${NC} Pulled: $IMAGE"
    fi
done
set -e

if [ -n "$PULL_FAILED" ]; then
    print_error "${RED}[ZOSCP]${NC} The following images could not be pulled:"
    printf "${PULL_FAILED}"
    print_error "${RED}[ZOSCP]${NC} Check entitlements and registry credentials for the failed images above."
    exit 1
fi

print_success "z/OS Container Platform image pull completed"
