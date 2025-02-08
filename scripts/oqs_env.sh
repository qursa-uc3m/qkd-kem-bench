#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Get the project root directory (two levels up from scripts/)
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"

# Set default paths based on installation type
if [ ! -z "$OPENSSL_INSTALL" ]; then
   # Approach 1: System installation
   OPENSSL_PATH="$OPENSSL_INSTALL"
   PROVIDER_PATH="${PROJECT_DIR}/_build/lib"
elif [ -f "${PROJECT_DIR}/.local/bin/openssl" ]; then
   # Approach 2: Self-contained
   OPENSSL_PATH="${PROJECT_DIR}/.local"
   PROVIDER_PATH="${PROJECT_DIR}/_build/lib"
else
   # Approach 3: Manual installation (default or custom)
   MANUAL_PATH="${1:-/opt/oqs_openssl3}"
   OPENSSL_PATH="${MANUAL_PATH}"
   PROVIDER_PATH="${MANUAL_PATH}/oqs-provider/_build/lib"
fi

# Export environment variables
export OPENSSL_CONF="${PROJECT_DIR}/scripts/openssl-ca.cnf"
export OPENSSL_MODULES="${PROVIDER_PATH}"
export PATH="${OPENSSL_PATH}/bin:$PATH"
export LD_LIBRARY_PATH="${OPENSSL_PATH}/lib64:${OPENSSL_PATH}/lib:$LD_LIBRARY_PATH"

# Print settings
echo "Environment variables set:"
echo "OPENSSL_CONF=$OPENSSL_CONF"
echo "OPENSSL_MODULES=$OPENSSL_MODULES"
echo "PATH updated to include: ${OPENSSL_PATH}/bin"
echo "LD_LIBRARY_PATH updated to include: ${OPENSSL_PATH}/lib64:${OPENSSL_PATH}/lib"
echo ""

# Check if CERBERIS_XGR is enabled
if [ "${QKD_BACKEND}" = "qukaydee" ]; then
    echo "Setting up Cerberis QuKayDee environment:"
    
    # Certificate configuration
    export QKD_MASTER_CERT_PATH="${PROJECT_DIR}/qkd_certs/sae-1.crt"
    export QKD_MASTER_KEY_PATH="${PROJECT_DIR}/qkd_certs/sae-1.key"
    export QKD_MASTER_CA_CERT_PATH="${PROJECT_DIR}/qkd_certs/account-${ACCOUNT_ID}-server-ca-qukaydee-com.crt"

    export QKD_SLAVE_CERT_PATH="${PROJECT_DIR}/qkd_certs/sae-2.crt"
    export QKD_SLAVE_KEY_PATH="${PROJECT_DIR}/qkd_certs/sae-2.key"
    export QKD_SLAVE_CA_CERT_PATH="${PROJECT_DIR}/qkd_certs/account-${ACCOUNT_ID}-server-ca-qukaydee-com.crt"
    
    # QuKayDee configuration
    if [ -z "${ACCOUNT_ID}" ]; then
        echo "Warning: ACCOUNT_ID not set. Please set your QuKayDee account ID."
    else
        export QKD_MASTER_KME_HOSTNAME="https://kme-1.acct-${ACCOUNT_ID}.etsi-qkd-api.qukaydee.com"
        export QKD_SLAVE_KME_HOSTNAME="https://kme-2.acct-${ACCOUNT_ID}.etsi-qkd-api.qukaydee.com"
        export QKD_MASTER_SAE="sae-1"
        export QKD_SLAVE_SAE="sae-2"
        
        echo "QKD_MASTER_KME_HOSTNAME=$QKD_MASTER_KME_HOSTNAME"
        echo "QKD_SLAVE_KME_HOSTNAME=$QKD_SLAVE_KME_HOSTNAME"
    fi
else
    echo "Using default QKD backend (simulated)"
fi

