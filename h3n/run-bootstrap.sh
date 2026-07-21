#!/bin/bash
set -e

# Source environment setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-env.sh"
"$SCRIPT_DIR/setup-ssh.sh"

echo "Running bootstrap playbook with dynamic inventory..."
ansible-playbook ./bootstrap/bootstrap-h3n.yml \
    -e artifactory_user=$ARTIFACTORY_USER \
    -e artifactory_api_key=$ARTIFACTORY_API_KEY \
    -i ./bootstrap/host.yaml

echo "Bootstrap playbook complete!"

# Made with Bob
