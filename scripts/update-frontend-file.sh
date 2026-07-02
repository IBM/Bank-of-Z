#!/bin/bash
# =============================================================================
# Script: update-frontend-file.sh
# Purpose: Quickly update a single file in the deployed frontend WAR
# Usage: ./scripts/update-frontend-file.sh <local-file-path>
# Example: ./scripts/update-frontend-file.sh src/frontend/account-details.html
# =============================================================================

set -e

# Check arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <local-file-path>"
    echo "Example: $0 src/frontend/account-details.html"
    exit 1
fi

LOCAL_FILE="$1"
FILENAME=$(basename "$LOCAL_FILE")

# Validate file exists
if [ ! -f "$LOCAL_FILE" ]; then
    echo "Error: File not found: $LOCAL_FILE"
    exit 1
fi

# Configuration
REMOTE_HOST="hsslp25p7.pok.stglabs.ibm.com"
REMOTE_USER="ibmuser"
WAR_PATH="/usr/local/sandboxes/bank-of-z/frontend/servers/bankz-frontend/apps/bank-frontend-vanilla.war"
TMP_DIR="/tmp/frontend-update-$$"

echo "==================================================================="
echo "Frontend File Update"
echo "==================================================================="
echo "Local file:  $LOCAL_FILE"
echo "Remote file: $FILENAME"
echo "Remote host: $REMOTE_USER@$REMOTE_HOST"
echo "WAR path:    $WAR_PATH"
echo "==================================================================="

# Step 1: Copy file to z/OS
echo "[1/4] Copying file to z/OS..."
scp "$LOCAL_FILE" "$REMOTE_USER@$REMOTE_HOST:/tmp/$FILENAME"

# Step 2: Update WAR file on z/OS
echo "[2/4] Updating WAR file..."
ssh "$REMOTE_USER@$REMOTE_HOST" << EOF
set -e
cd /tmp
# Update the file in the WAR
jar -uvf "$WAR_PATH" "$FILENAME"
# Clean up
rm -f "$FILENAME"
echo "WAR file updated successfully"
EOF

echo "[3/4] Waiting for Liberty to reload (5 seconds)..."
sleep 5

echo "[4/4] Done!"
echo "==================================================================="
echo "Frontend file updated successfully!"
echo "The Liberty server should automatically reload the application."
echo "Check the browser to verify the changes."
echo "==================================================================="

# Made with Bob
