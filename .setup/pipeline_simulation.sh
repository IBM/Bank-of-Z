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
export LIB_DIR="$SCRIPTS_DIR/lib"
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/prerequisites.sh"

TMPHLQ=$(printf '%s' "${PIPELINE_TMPHLQ:-$(basename "$HOME")}" | tr '[:lower:]' '[:upper:]')
gitRepository=$(git remote get-url origin | sed 's#.*/##' | sed 's/\.git$//')
branchName=$(git branch --show-current)

echo "Pipeline Simulation Parameters:"
echo "  Git Repository: $gitRepository"
echo "  Branch: $branchName"
echo "  Temporary HLQ: $TMPHLQ"

# =======================================
# Stage 1: Verify prerequisites
# =======================================
#print_stage "STAGE 1: Verify Prerequisites"
#if ! verify_build_prerequisites; then
#    exit 1
#fi

# =======================================
# Stage 2: Refresh git (not for Grub)
# =======================================
if [ "${GRUB:-}" == "False" ]; then
    git reset --hard
    git pull
fi

# =======================================
# Stage 3: DBB Build
# =======================================
cd "$SCRIPTS_DIR"
print_stage "STAGE 2: DBB Build"
bash tasks/task-dbb-build.sh

# =======================================
# Stage 4: Deploy Build
# =======================================
cd "$SCRIPTS_DIR"
print_stage "STAGE 3: Deploy Build"
bash tasks/task-wazi-deploy.sh&
# ZOAU Issue with ZOWE
PID=$!
wait $PID
RC=$?
print_stage "Update done with RC=$RC"
exit $RC
