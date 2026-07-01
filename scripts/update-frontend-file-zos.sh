#!/bin/env bash
# =============================================================================
# Script: update-frontend-file-zos.sh
# Purpose: Update a single file in the deployed frontend WAR (runs on z/OS)
# Usage: ./scripts/update-frontend-file-zos.sh <file-path-in-repo>
# Example: ./scripts/update-frontend-file-zos.sh src/frontend/account-details.html
# =============================================================================

set -e

# Check arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <file-path-in-repo>"
    echo "Example: $0 src/frontend/account-details.html"
    exit 1
fi

REPO_FILE="$1"
FILENAME=$(basename "$REPO_FILE")

# Configuration
REPO_DIR="/usr/local/sandboxes/bank-of-z/Bank-of-Z"
WAR_PATH="/usr/local/sandboxes/bank-of-z/frontend/servers/bankz-frontend/apps/bank-frontend-vanilla.war"
SOURCE_FILE="$REPO_DIR/$REPO_FILE"

# Validate file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: File not found: $SOURCE_FILE"
    exit 1
fi

echo "==================================================================="
echo "Frontend File Update (z/OS)"
echo "==================================================================="
echo "Source file: $SOURCE_FILE"
echo "Target file: $FILENAME"
echo "WAR path:    $WAR_PATH"
echo "==================================================================="

# Step 1: Copy file to temp location
echo "[1/3] Copying file to temp location..."
cp "$SOURCE_FILE" "/tmp/$FILENAME"

# Step 2: Update WAR file
echo "[2/3] Updating WAR file..."
cd /tmp
jar -uvf "$WAR_PATH" "$FILENAME"

# Step 3: Clean up
echo "[3/3] Cleaning up..."
rm -f "/tmp/$FILENAME"

echo "==================================================================="
echo "Frontend file updated successfully!"
echo "Liberty will automatically reload the application."
echo "==================================================================="

# Made with Bob
