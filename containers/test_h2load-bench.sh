#!/bin/bash

# Start the h2load container interactively
docker-compose run h2load-bench bash

# Inside the container, check the environment variables
echo "QKD_BACKEND: $QKD_BACKEND"

# Source the environment script and check provider loading
. /opt/scripts/oqs_env.sh
openssl list -providers

# Check that QKD-KEM provider is loaded and configured
openssl list -providers -verbose | grep -A 20 qkdkemprovider

# Verify ETSI014 API configuration for cerberis-xgr
echo "QKD_MASTER_KME_HOSTNAME: $QKD_MASTER_KME_HOSTNAME"
echo "QKD_SLAVE_KME_HOSTNAME: $QKD_SLAVE_KME_HOSTNAME"

# Check connectivity to NGINX server
apk add --no-cache curl
curl -k --connect-timeout 5 https://localhost:4433
echo "Status of curl to NGINX server: $?"

# Check connectivity to cerberis nodes (if QKD_BACKEND=cerberis-xgr)
if [ "$QKD_BACKEND" = "cerberis-xgr" ]; then
  curl -k --connect-timeout 5 $QKD_MASTER_KME_HOSTNAME
  echo "Status of curl to QKD_MASTER_KME_HOSTNAME: $?"
fi

# Test a basic h2load command
echo "Testing h2load with default settings..."
h2load -n 1 -c 1 https://localhost:4433 --groups kyber512

# Exit container
exit