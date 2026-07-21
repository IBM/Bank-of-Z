#!/bin/bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting H3N provisioning workflow..."

# Step 1: Recreate the H3N instance
echo "Step 1: Recreating H3N instance..."
"$SCRIPT_DIR/recreate-instance.sh"

# Step 2: Copy SSH key to the newly provisioned host
echo "Step 2: Setting up SSH key on new host..."
"$SCRIPT_DIR/setup-ssh.sh"

# Step 3: Run bootstrap playbook
echo "Step 3: Running bootstrap playbook..."
"$SCRIPT_DIR/run-bootstrap.sh"

# Step 4: Run configure playbook
echo "Step 4: Running configure playbook..."
"$SCRIPT_DIR/run-configure.sh"

echo "H3N provisioning complete!"
