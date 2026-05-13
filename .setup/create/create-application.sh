#!/bin/env bash
set -e
# =============================================================================
# Script  : create-application.sh
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
# Stage 1: Verify prerequisites
# =========================
#print_stage "STAGE 1: Verify Prerequisites"
#if ! verify_build_prerequisites; then
#    exit 1
#fi

# =========================
# Stage 2: DBB Build
# =========================
cd "$SCRIPTS_DIR"
print_stage "STAGE 2: DBB Build"
bash ../tasks/task-dbb-build.sh full

# =========================
# Stage 3: Deploy Build
# =========================
cd "$SCRIPTS_DIR"
print_stage "STAGE 3: Deploy Build"
bash ../tasks/task-wazi-deploy.sh true&
# ZOAU Issue with ZOWE
PID=$!
wait $PID

# =========================
# Stage 4: Create DB2 database
# =========================
cd "$SCRIPTS_DIR"
print_stage "STAGE 4: Create DB2 database"
bash ./create-db2-tables.sh

# =========================
# Stage 5: Create CICS region
# =========================
cd "$SCRIPTS_DIR"
print_stage "STAGE 5: Create CICS region with zconfig"
bash ./create-cics-region.sh&
# ZOAU Issue with ZOWE
PID=$!
wait $PID
RC=$?
print_stage "Creation done with RC=$RC"

# =========================
# Stage 6: Create z/OS Connect Server
# =========================
#cd "$SCRIPTS_DIR"
#print_stage "STAGE 3: Create z/OS Connect Server"
#bash ./create-zosconnect-server.sh

# =========================
# Stage 7: Create application frontend
# =========================
#cd "$SCRIPTS_DIR"
#print_stage "STAGE 4: Create application frontend"
#bash ./create-application-frontend.sh

# =========================
# Stage 8: Install TAZ in CICS region
# =========================
#cd "$SCRIPTS_DIR"
#print_stage "STAGE 5: Install TAZ in CICS region"
#bash ./create-taz-configuration.sh

exit $RC
