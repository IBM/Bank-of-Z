#!/bin/env bash
# Expected variables/functions from caller:
# SCRIPTS_DIR, SANDBOX_DIR, APP_BASE_NAME, APP_BASE_NAME_LOWER, HOME
# get_section_value, print_stage, print_info, print_warning, print_success, print_error
# opercmd, tsocmd, mrm

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPTS_DIR/config.yaml"
chtag -t -c ISO8859-1 $CONFIG_FILE
LIB_DIR="$SCRIPTS_DIR/lib"
source "$LIB_DIR/utilities.sh"
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/prerequisites.sh"


#########################################################
# Create z/OS Connect Server
#########################################################
print_stage "Create z/OS Connect Server"

# Get z/OS Connect home from config
ZOSCONNECT_HOME=$(get_section_value 'zosconnect' 'zosconnect_home')
ZOSCONNECT_HOME=$(echo $ZOSCONNECT_HOME | sed "s|~|$HOME|g")

# Server will be created in sandbox
export WLP_USER_DIR="${SANDBOX_DIR}/zosconnect-server"

print_info "Creating z/OS Connect server at: $WLP_USER_DIR"

# Remove old server if exists
if [ -d "$WLP_USER_DIR" ]; then
    print_warning "Removing existing server at $WLP_USER_DIR"
    rm -rf "$WLP_USER_DIR"
fi

# Create server using z/OS Connect command
${ZOSCONNECT_HOME}/zosconnect create ${APP_BASE_NAME_LOWER}Server --template=zosconnect:openApi3

RC=$?
if [ $RC -eq 0 ]; then
    print_success "z/OS Connect server created successfully at $WLP_USER_DIR"
else
    print_error "Failed to create z/OS Connect server (RC=$RC)"
    exit 1
fi

set +e
opercmd  "C BAQ${APP_BASE_NAME}"& 2>/dev/null
sleep 5
tsocmd "RDEFINE STARTED BAQ${APP_BASE_NAME}.* STDATA(USER(IBMUSER) TRUSTED(YES))"
tsocmd "SETROPTS RACLIST(STARTED) REFRESH"
mrm "SYS1.PROCLIB(BAQ${APP_BASE_NAME})"
set -e
