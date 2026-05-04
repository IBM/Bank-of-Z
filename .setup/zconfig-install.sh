#!/bin/env bash
#########################################################
# Build Script
# This script runs on the remote z/OS USS system after
# the workspace has been cloned by grub
# 
# This script is responsible for:
# - Setting up the build environment
# - Installing required dependencies
# - Creating and running a CICS Region
# - Creating and populating Db2 database
#########################################################
set -eu
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

exec > >(while IFS= read -r line; do print_info "${CYAN}[ZCONFIG-INSTALL]${NC} $line"; done) 2>&1

# =========================
# Environment
# =========================
export APP_BASE_NAME=$(get_section_value 'app' 'base_name')
export APP_BASE_NAME_LOWER=${APP_BASE_NAME,,}
export APP_VERSION=$(get_section_value 'app' 'zos_version')
export SANDBOX_DIR=${SANDBOX_DIR:-$(get_section_value 'sandbox' 'path')}
export CMCI_PORT=${CMCI_PORT:-$(get_section_value 'zconfig' 'cmci_port')}
export ZOAU_HOME=${ZOAU_HOME:-$(get_section_value 'zoau' 'zoau_home')}
export ZCONFIG_HOME=$(get_section_value 'zconfig' 'zconfig_home')
export ZCONFIG_HOME=$(echo $ZCONFIG_HOME | sed "s|~|$HOME|g")
export ZCS_HOME=$(get_section_value 'zconfig' 'zcb_home')
export ZCS_HOME=$(echo $ZCS_HOME | sed "s|~|$HOME|g")
export PATH=$ZOAU_HOME/bin:$PATH
export LIBPATH="$ZOAU_HOME/lib:${LIBPATH:-}"
export JAVA_HOME=$(get_section_value 'zconfig' 'java_home')

# =========================
# Cleanup
# =========================
rm -rf $SCRIPTS_DIR/logs

#########################################################
# Cancel CICS region (ignore errors if already cancelled)
#########################################################
set +e
jcan P "CICS${APP_BASE_NAME}"& 2>/dev/null
opercmd "C CICS${APP_BASE_NAME}"& 2>/dev/null
sleep 10
drm "${APP_BASE_NAME}.CICS${APP_BASE_NAME}.*"&  2>/dev/null
set -e

#########################################################
# STAGE 1: Verify Prerequisites
#########################################################
print_stage "STAGE 1: Verify Prerequisites"
# Verify all prerequisites
if ! verify_build_prerequisites; then
    exit 1
fi

#########################################################
# STAGE 2: Create CICS instance with zconfig
#########################################################
print_stage "STAGE 2: Create CICS instance with zconfig"
# Activate zconfig virtual environment
export PATH=$ZCS_HOME/bin:$PATH
if [ -f $ZCONFIG_HOME/bin/activate ]; then
    source $ZCONFIG_HOME/bin/activate
else
    print_warning "zconfig virtual environment not found at $ZCONFIG_HOME/bin/activate"
fi

# Apply CICS region configuration
cd $SCRIPTS_DIR/zconfig
zconfig apply\
  -e  applid="CICS${APP_BASE_NAME}" \
  -e sysid="${APP_BASE_NAME}" \
  -e region_hlq="${APP_BASE_NAME}" \
  -e jvm_profile_dir="$SANDBOX_DIR" \
  -e java_home="/usr/lpp/java/java21/current_64" \
  -e cmci_port="$CMCI_PORT" \
  cics-region.yaml
RC=$?
if [ $RC -eq 0 ]; then
    print_success "ZConfig completed successfully!"
else
   print_error "ZConfig failed with return code: $RC"
   echo ""
   echo "Check logs in: $SCRIPTS_DIR/logs"
   echo ""
   exit 1
fi
deactivate

echo ""
# Start CICS region
jsub ${APP_BASE_NAME}.CICS${APP_BASE_NAME}.DFHSTART&
sleep 10
echo "CICS Region Job Started"
echo ""

#########################################################
# STAGE 3: Create DB2 database
#########################################################
print_stage "STAGE 3: Create DB2 database"
submit_jcl "$SCRIPTS_DIR/jcl/Db2-drop.jcl"
sleep 3
submit_jcl "$SCRIPTS_DIR/jcl/Db2-create.jcl"
sleep 3
submit_jcl "$SCRIPTS_DIR/jcl/Db2-bind.jcl"
sleep 3
submit_jcl "$SCRIPTS_DIR/jcl/Db2-insert.jcl"
sleep 3

#########################################################
# Stage 4: Config CICS region IPC
#########################################################
print_stage "Stage 4: Config CICS region IPC"
submit_jcl "$SCRIPTS_DIR/jcl/Cics-ipc.jcl"
sleep 3
opercmd "F CICS${APP_BASE_NAME},CEDA INSTALL TCPIPSERVICE(ZOSCONN) GROUP(${APP_BASE_NAME}GRP)"&
sleep 2 
opercmd "F CICS${APP_BASE_NAME},CEDA INSTALL IPCONN(ZOSCONN) GROUP(${APP_BASE_NAME}GRP)"&
sleep 2
opercmd "F CICS${APP_BASE_NAME},CEMT SET TCPIPSERVICE(ZOSCONN) OPEN"&
sleep 2

#########################################################
# STAGE 5: Create z/OS Connect Server
#########################################################
cd $SCRIPTS_DIR
print_stage "STAGE 5: Create z/OS Connect Server"
bash ./create-zosconnect-server.sh

#########################################################
# STAGE 6: Create application fronted
#########################################################
print_stage "STAGE 6: Create application fronted"
bash ./create-application-frontend.sh

#########################################################
# STAGE 7: Install TAZ in CICS region
#########################################################
print_stage "STAGE 7: Install TAZ in CICS region"
bash ./taz-install.sh

