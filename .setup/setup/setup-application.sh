#!/bin/env bash
set -e
# =============================================================================
# Script  : setup-application.sh
# Summary : Full application installation orchestrator
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# Sequentially executes all installation stages.
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LIB_DIR="$SCRIPTS_DIR/../lib"
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/prerequisites.sh"

# =========================
# Stage: Verify prerequisites
# =========================
#print_stage "STAGE: Verify Prerequisites"
#if ! verify_build_prerequisites; then
#    exit 1
#fi

# =========================
# Stage: DBB Build
# =========================
cd "$SCRIPTS_DIR"
print_stage "STAGE: DBB Build"
bash ../tasks/task-dbb-build.sh full

# =========================
# Stage: Deploy Build
# =========================
cd "$SCRIPTS_DIR"
print_stage "STAGE: Deploy Build"
bash ../tasks/task-wazi-deploy.sh true&
# ZOAU Issue with ZOWE
PID=$!
wait $PID

############# Needs to be moved into setup-common
# =========================
# Stage: Create DB2 database
# =========================
#cd "$SCRIPTS_DIR"
#print_stage "STAGE: Create DB2 database"
#bash ./setup-db2-tables.sh

# =========================
# Stage: Create CICS region
# =========================
#cd "$SCRIPTS_DIR"
#print_stage "STAGE: Create CICS region with zconfig"
#bash ./setup-cics-region.sh&
# ZOAU Issue with ZOWE
#PID=$!
#wait $PID
#RC=$?
#print_stage "Creation done with RC=$RC"
####################

# =========================
# Stage: Create z/OS Connect Server
# =========================
#cd "$SCRIPTS_DIR"
#print_stage "STAGE: Create z/OS Connect Server"
#bash ./setup-zosconnect-server.sh

# =========================
# Stage: Create application frontend
# =========================
#cd "$SCRIPTS_DIR"
#print_stage "STAGE: Create application frontend"
#bash ./setup-application-frontend.sh

# =========================
# Stage: Install TAZ in CICS region
# =========================
#cd "$SCRIPTS_DIR"
#print_stage "STAGE: Install TAZ in CICS region"
#bash ./setup-taz-configuration.sh

exit $RC
