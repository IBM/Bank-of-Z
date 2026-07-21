#!/bin/bash
set -e

# Check for required environment variables
REQUIRED_VARS=("PAT" "H3N_USER" "H3N_PASS" "ARTIFACTORY_USER" "ARTIFACTORY_API_KEY" "TWYD_H3N_SYS_NAME")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "ERROR: The following required environment variables are not set:"
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "Please ensure all variables are defined in your .env file."
    echo "You can use .env.template as a reference."
    exit 1
fi

echo "All required environment variables are set."

echo "Installing Python 3.11..."
dnf install python3.11 -y
dnf install python3.11-pip -y

pip3.11 install 'requests'

echo "Creating virtual environment..."
VENV_DIR=".venv"
if [ ! -d "$VENV_DIR" ]; then
    python3.11 -m venv "$VENV_DIR"
fi

echo "Activating virtual environment..."
source "$VENV_DIR/bin/activate"

echo "Installing ansible..."
pip3.11 install --upgrade pip
pip3.11 install 'ansible-core==2.17.5'

echo "Installing IBM z/OS Core collection..."
ansible-galaxy collection install ibm.ibm_zos_core:1.16.0

echo "Installing H3N collection..."
# ansible-galaxy collection install git+https://${PAT}@github.ibm.com/IBMZSoftware/h3n_bootstrap.git,twyd-roles --force
ansible-galaxy collection install /root/h3n_bootstrap --force

echo "Updating CA trust store..."
echo | openssl s_client -showcerts -connect tivlp89.pok.stglabs.ibm.com:443 2>/dev/null | \
    awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/ {print}' > /tmp/ibm-chain.pem && \
    csplit -sz -f /tmp/cert- /tmp/ibm-chain.pem '/-----BEGIN CERTIFICATE-----/' '{*}' && \
    for cert in /tmp/cert-*; do \
        [ -s "$cert" ] && cp "$cert" /etc/pki/ca-trust/source/anchors/ibm-cert-$(basename $cert).crt; \
    done && \
    update-ca-trust extract && \
    rm -f /tmp/cert-* /tmp/ibm-chain.pem

echo "Environment setup complete!"

# Made with Bob
