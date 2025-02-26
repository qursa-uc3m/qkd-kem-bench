#!/bin/bash

# Start the nginx container
docker-compose up -d nginx-server

# Check status
docker-compose logs nginx-server

# Exec into the container
docker-compose exec nginx-server bash -c '

# Inside the container, check the environment variables
echo ""
echo "Environment variables:"
echo "----------------------"
echo "SSL_CERT_DIR: $SSL_CERT_DIR"
echo "SSL_CERT_TYPE: $SSL_CERT_TYPE"
echo "QKD_BACKEND: $QKD_BACKEND"
echo "DEFAULT_GROUPS: $DEFAULT_GROUPS"
echo ""

# Source the environment script and check provider loading
echo "Check providers loading ..."
#. /opt/scripts/oqs_env.sh
openssl list -providers
echo ""

# Verify ETSI014 API configuration for cerberis-xgr
echo "Check ETSI014 API configuration ..."
echo "QKD_MASTER_KME_HOSTNAME: $QKD_MASTER_KME_HOSTNAME"
echo "QKD_SLAVE_KME_HOSTNAME: $QKD_SLAVE_KME_HOSTNAME"
echo "QKD_MASTER_SAE: $QKD_MASTER_SAE"
echo "QKD_SLAVE_SAE: $QKD_SLAVE_SAE"
echo ""

# Check connectivity to cerberis nodes (if QKD_BACKEND=cerberis-xgr)
#if [ "$QKD_BACKEND" = "cerberis-xgr" ]; then
#  apt-get update && apt-get install -y curl
#  curl -k --connect-timeout 5 $QKD_MASTER_KME_HOSTNAME
#  echo "Status of curl to QKD_MASTER_KME_HOSTNAME: $?"
#fi

# Check NGINX configuration
# nginx -t

# Check if NGINX is running
# ps aux | grep nginx

# Exit container
exit'
