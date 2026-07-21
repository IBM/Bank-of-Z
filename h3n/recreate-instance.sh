#!/bin/bash
set -e

# Source environment setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-env.sh"

echo "Deprovisioning existing H3N instance..."
ansible-playbook ./h3n_instance/deprovision.yml \
    -e h3n_system_name=$TWYD_H3N_SYS_NAME \
    -e h3n_user=$H3N_USER \
    -e h3n_pass=$H3N_PASS \
    -i ./h3n_instance/localhost_inventory.yml

echo "Provisioning CI builds H3N instance..."
ansible-playbook ./h3n_instance/provision.yml \
    -e h3n_system_name=$TWYD_H3N_SYS_NAME \
    -e h3n_user=$H3N_USER \
    -e h3n_pass=$H3N_PASS \
    -i ./h3n_instance/localhost_inventory.yml

echo "Extracting H3N instance details..."
if [ -f "./bootstrap/host.yaml" ]; then
    export H3N_HOST=$(yq eval '.source_system.hosts.zos.ansible_host' ./bootstrap/host.yaml)
    export H3N_PORT_22=$(yq eval '.source_system.hosts.zos.ansible_port' ./bootstrap/host.yaml)
    export H3N_PASSWORD=$(yq eval '.source_system.hosts.zos.ansible_password' ./bootstrap/host.yaml)
    export H3N_PORT_443=$(yq eval '.source_system.hosts.zos.port_443' ./bootstrap/host.yaml)

    echo "H3N Host: $H3N_HOST"
    echo "H3N Port 22: $H3N_PORT_22"
    echo "H3N Port 443: $H3N_PORT_443"
    echo "H3N Password: $H3N_PASSWORD"
else
    echo "Warning: bootstrap/host.yaml not found, skipping Secrets Manager upload"
fi

# SSH key setup is handled by setup-env.sh (sourced above)

echo "H3N instance recreation complete!"

# Made with Bob
