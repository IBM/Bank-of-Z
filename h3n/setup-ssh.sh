#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up SSH keys for passwordless access..."

sudo dnf install -y sshpass
if ! command -v sshpass &> /dev/null; then
    echo "ERROR: Failed to install sshpass"
    exit 1
fi
echo "sshpass installed successfully"

SSH_DIR="$HOME/.ssh"
PRIVATE_KEY_FILE="$SSH_DIR/id_rsa"
PUBLIC_KEY_FILE="$SSH_DIR/id_rsa.pub"

if [ ! -f "$PRIVATE_KEY_FILE" ] || [ ! -f "$PUBLIC_KEY_FILE" ]; then
    echo "ERROR: SSH keys not found. Please mount your SSH keys with:"
    echo "  docker run -v ~/.ssh/id_rsa:/root/.ssh/id_rsa -v ~/.ssh/id_rsa.pub:/root/.ssh/id_rsa.pub ..."
    echo "  or"
    echo "  podman run -v ~/.ssh/id_rsa:/root/.ssh/id_rsa -v ~/.ssh/id_rsa.pub:/root/.ssh/id_rsa.pub ..."
    exit 1
fi

echo "SSH keys validated successfully"

# Copy keys to writable location to avoid config conflicts and allow ssh-copy-id to work
echo "Copying SSH keys to temporary writable location..."
TEMP_SSH_DIR="/tmp/.ssh"
mkdir -p "$TEMP_SSH_DIR"
cp "$PRIVATE_KEY_FILE" "$TEMP_SSH_DIR/id_rsa"
cp "$PUBLIC_KEY_FILE" "$TEMP_SSH_DIR/id_rsa.pub"
chmod 700 "$TEMP_SSH_DIR"
chmod 600 "$TEMP_SSH_DIR/id_rsa"
chmod 644 "$TEMP_SSH_DIR/id_rsa.pub"

PRIVATE_KEY_FILE="$TEMP_SSH_DIR/id_rsa"
PUBLIC_KEY_FILE="$TEMP_SSH_DIR/id_rsa.pub"

if [ ! -f "$SCRIPT_DIR/bootstrap/host.yaml" ]; then
    echo "ERROR: bootstrap/host.yaml not found. Run provision.yml first."
    exit 1
fi

ANSIBLE_HOST=$(yq eval '.source_system.hosts.zos.ansible_host' "$SCRIPT_DIR/bootstrap/host.yaml")
ANSIBLE_PORT=$(yq eval '.source_system.hosts.zos.ansible_port' "$SCRIPT_DIR/bootstrap/host.yaml")
ANSIBLE_USER=$(yq eval '.source_system.hosts.zos.ansible_user' "$SCRIPT_DIR/bootstrap/host.yaml")
ANSIBLE_PASSWORD=$(yq eval '.source_system.hosts.zos.ansible_password' "$SCRIPT_DIR/bootstrap/host.yaml")

if [ -z "$ANSIBLE_HOST" ] || [ -z "$ANSIBLE_PORT" ] || [ -z "$ANSIBLE_USER" ] || [ -z "$ANSIBLE_PASSWORD" ]; then
    echo "ERROR: Could not extract connection details from host.yaml"
    exit 1
fi

echo "Connecting to: $ANSIBLE_USER@$ANSIBLE_HOST:$ANSIBLE_PORT"

echo "Copying SSH public key to remote host..."
sshpass -p "$ANSIBLE_PASSWORD" ssh-copy-id \
    -i "$PUBLIC_KEY_FILE" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ControlMaster=no \
    -o ControlPath=none \
    -p "$ANSIBLE_PORT" \
    "$ANSIBLE_USER@$ANSIBLE_HOST"

echo "SSH key successfully copied to remote host"
echo "Passwordless SSH access configured"

# Made with Bob
