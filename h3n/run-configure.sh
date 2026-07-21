#!/bin/bash
set -e

# Source environment setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-env.sh"
"$SCRIPT_DIR/setup-ssh.sh"

echo "Running configure playbook with dynamic inventory..."
ansible-playbook ./configure/configure-h3n.yml \
    -e artifactory_user=$ARTIFACTORY_USER \
    -e artifactory_api_key=$ARTIFACTORY_API_KEY \
    -e github_pat=$PAT \
    -e w3_username=$H3N_USER \
    -e w3_password=$H3N_PASS \
    -i ./configure/host.yaml \
    "$@"

echo "Configure playbook complete!"

# Made with Bob
