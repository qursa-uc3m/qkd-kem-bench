#!/bin/bash

source /opt/scripts/oqs_env.sh

# Verify settings
echo -e "\nDocker environment settings:"
echo "PROJECT_DIR=$PROJECT_DIR"
echo "OPENSSL_INSTALL=$OPENSSL_INSTALL"
echo "OPENSSL_CONF=$OPENSSL_CONF"
echo "OPENSSL_MODULES=$OPENSSL_MODULES"

# Print current environment variables
echo -e "\nCurrent environment variables:"
echo "QKD_BACKEND: $QKD_BACKEND"
echo "SSL_CERT_DIR: $SSL_CERT_DIR"
echo "SSL_CERT_TYPE: $SSL_CERT_TYPE"
echo "DEFAULT_GROUPS: $DEFAULT_GROUPS"

if [ "$QKD_DEBUG" > 0 ]; then
  echo -e "DEBUG MODE: ACTIVE with level $QKD_DEBUG\n"
else    
  echo -e "DEBUG MODE: INACTIVE\n"
fi

# Replace placeholders in nginx.conf
sed -i "s/__DEFAULT_GROUPS__/$DEFAULT_GROUPS/g" /opt/nginx/conf/nginx.conf
sed -i "s/__SSL_CERT_DIR__/$SSL_CERT_DIR/g" /opt/nginx/conf/nginx.conf
sed -i "s/__SSL_CERT_TYPE__/$SSL_CERT_TYPE/g" /opt/nginx/conf/nginx.conf

# Debug: Show final configuration
echo -e "\nFinal NGINX configuration:"
grep -n "ssl_certificate" /opt/nginx/conf/nginx.conf
grep -n "ssl_ecdh_curve" /opt/nginx/conf/nginx.conf

# Check provider loading
echo -e "\nCheck providers loading ..."
openssl version
openssl list -providers
echo ""

# Export all QKD environment variables
export QKD_MASTER_KME_HOSTNAME
export QKD_SLAVE_KME_HOSTNAME
export QKD_MASTER_CA_CERT_PATH
export QKD_SLAVE_CA_CERT_PATH
export QKD_MASTER_CERT_PATH
export QKD_MASTER_KEY_PATH
export QKD_SLAVE_CERT_PATH
export QKD_SLAVE_KEY_PATH
export QKD_MASTER_SAE
export QKD_SLAVE_SAE
export OPENSSL_INSTALL
export OPENSSL_CONF
export OPENSSL_MODULES

# Write environment variables to a file for NGINX to use
env | grep -E "QKD_|OPENSSL" > /tmp/nginx_env.txt

# Start NGINX with explicitly passed environment
exec env $(cat /tmp/nginx_env.txt | xargs) /opt/nginx/sbin/nginx -g "daemon off;"