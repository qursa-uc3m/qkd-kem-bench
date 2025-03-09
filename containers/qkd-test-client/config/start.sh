#!/bin/bash

# Print environment settings
echo -e "\nDocker environment settings:"
echo "PROJECT_DIR=$PROJECT_DIR"
echo "OPENSSL_INSTALL=$OPENSSL_INSTALL"
echo "OPENSSL_CONF=$OPENSSL_CONF"
echo "OPENSSL_MODULES=$OPENSSL_MODULES"

# Print current environment variables
echo -e "\nCurrent environment variables:"
echo "QKD_BACKEND: $QKD_BACKEND"
echo "ACCOUNT_ID: $ACCOUNT_ID"

if [ "$QKD_DEBUG" > 0 ]; then
  echo -e "DEBUG MODE: ACTIVE with level $QKD_DEBUG\n"
else    
  echo -e "DEBUG MODE: INACTIVE\n"
fi

# Check if certificates exist in the shared volume
if [ -d "/opt/certs" ] && [ "$(ls -A /opt/certs 2>/dev/null)" ]; then
  echo -e "\nCertificate volume is populated and accessible"
  ls -la /opt/certs | head -n 10
else
  echo -e "\nWARNING: Certificate volume appears empty or inaccessible"
fi

# Source the environment script and check provider loading
echo -e "\nCheck providers loading ..."
. /opt/scripts/oqs_env.sh
openssl list -providers
echo ""

# Keep container running
echo "qkd-test-client container is ready to receive commands"
exec tail -f /dev/null