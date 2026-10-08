#!/bin/bash
# build-remote.sh - Incremental build and redeploy for Bank of Z
#
# Stops all Bank of Z servers, runs an incremental DBB build and Wazi Deploy,
# then restarts all servers. The restart step is skipped if build or deploy fails.
#
# Usage: bash build-remote.sh
#
# Called by the BankOfZAppBuild zapp.yaml profile via grub_client execute.
# IMS_DISABLED must NOT be set in the environment; IMS is included in every cycle.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Change into SCRIPT_DIR so that git rev-parse (called by detect_bank_of_z_location
# inside setenv.sh / pipeline-common.sh) resolves the repo root correctly and
# sets EXECUTION_MODE=grub rather than falling through to the VSCode path.
cd "$SCRIPT_DIR"

source "$SCRIPT_DIR/config/setenv.sh"

echo "==> Stopping all Bank of Z servers..."
bash "$SCRIPT_DIR/runtime-manage.sh" stop all

echo "==> Running incremental build and deploy..."
bash "$SCRIPT_DIR/pipeline-common.sh" build-and-deploy

echo "==> Restarting all Bank of Z servers..."
bash "$SCRIPT_DIR/runtime-manage.sh" start all
