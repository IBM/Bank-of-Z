#!/bin/bash
set -e

echo "=== GRUB Incremental Build and Deploy ==="
echo ""

# Run GRUB - build and deploy in one go
echo "Syncing code, building, and deploying..."
echo "DBB will detect changes using git and build only what's needed"
echo "Then wazideploy will deploy the package to Liberty"
echo ""

grub_client -v -o \
  --repo-path $(pwd) \
  --server-root /usr/local/sandboxes/bank-of-z \
  --ssh-patch zdvt \
  ./.grub/scripts/build-and-deploy-orchestrator.sh

