#!/bin/env bash
set -e
# =============================================================================
# Script  : setup-application.sh
# Summary : Full application installation orchestrator
#
# Runs on the remote z/OS USS system after the workspace has been cloned.
# Sequentially executes all installation stages in the following order:
#
# 1. Install/Setup Middleware (CICS, IMS, z/OS Connect, DB2 Tables)
# 2. DBB Build (LOAD, DBRM, PSB, DBD, WAR - API & Frontend)
# 3. Wazi Deploy (deploys all artifacts including z/OS Connect)
# =============================================================================

# =========================
# Source library scripts
# =========================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LIB_DIR="$SCRIPTS_DIR/../lib"
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/prerequisites.sh"
chmod +x $SCRIPTS_DIR/*.sh

# =========================
# Stage: Verify prerequisites
# =========================
#print_stage "STAGE: Verify Prerequisites"
#if ! verify_build_prerequisites; then
#    exit 1
#fi

# =============================================================================
# PHASE 1: Install/Setup Middleware
# =============================================================================
print_stage "PHASE 1: Install/Setup Middleware"

# =========================
# Stage: Create CICS region
# =========================
cd "$SCRIPTS_DIR"
print_stage "STAGE 1: Create CICS region with zconfig"
bash ./setup-cics-region.sh&
# ZOAU Issue with ZOWE
PID=$!
wait $PID
RC=$?
print_stage "CICS region creation done with RC=$RC"

# =========================
# Stage: Create z/OS Connect Server
# =========================
cd "$SCRIPTS_DIR"
print_stage "STAGE 2: Create z/OS Connect Server"
bash ./setup-zosconnect-server.sh

# =========================
# Stage: Create IMS (if applicable)
# =========================
# TODO: Add IMS setup when available
# cd "$SCRIPTS_DIR"
# print_stage "STAGE: Create IMS"
# bash ./setup-ims.sh

# =========================
# Stage: Create DB2 database
# =========================
cd "$SCRIPTS_DIR"
print_stage "STAGE 3: Create DB2 database"
bash ./setup-db2-tables.sh

print_success "PHASE 1: Middleware setup completed"

# =============================================================================
# PHASE 2: DBB Build
# =============================================================================
cd "$SCRIPTS_DIR"
print_stage "PHASE 2: DBB Build"
bash ../tasks/task-dbb-build.sh full

print_success "PHASE 2: DBB Build completed"

# =============================================================================
# PHASE 3: Wazi Deploy
# =============================================================================
cd "$SCRIPTS_DIR"
print_stage "PHASE 3: Wazi Deploy"
bash ../tasks/task-wazi-deploy.sh&
# ZOAU Issue with ZOWE
PID=$!
wait $PID
RC=$?

print_success "PHASE 3: Wazi Deploy completed with RC=$RC"

# =========================
# PHASE 4: Populate DB2 database
# =========================
cd "$SCRIPTS_DIR"
print_stage "PHASE 4: Populate DB2 database"
bash ./populate-db2-tables.sh
print_success "PHASE 4: Populate DB2 database completed"

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
