#!/bin/bash

# Load OpenSSL environment
. /opt/scripts/oqs_env.sh

echo -e "\n Check providers loading ..."
openssl list -providers
echo -e "\n"

# Check if certificates exist in the shared volume
if [ -d "/opt/certs" ] && [ "$(ls -A /opt/certs 2>/dev/null)" ]; then
    echo "Certificate volume is populated and accessible"
else
    echo "WARNING: Certificate volume appears empty or inaccessible"
fi

# Execute h2load with all arguments
exec h2load "$@"