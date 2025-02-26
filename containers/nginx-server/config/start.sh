#!/bin/bash

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

# Replace placeholders in nginx.conf
sed -i "s/__DEFAULT_GROUPS__/$DEFAULT_GROUPS/g" /opt/nginx/conf/nginx.conf
sed -i "s/__SSL_CERT_DIR__/$SSL_CERT_DIR/g" /opt/nginx/conf/nginx.conf
sed -i "s/__SSL_CERT_TYPE__/$SSL_CERT_TYPE/g" /opt/nginx/conf/nginx.conf

# Debug: Show final configuration
echo -e "\nFinal NGINX configuration:"
grep -n "ssl_certificate" /opt/nginx/conf/nginx.conf
grep -n "ssl_ecdh_curve" /opt/nginx/conf/nginx.conf

# Source the environment script and check provider loading
echo -e "\nCheck providers loading ..."
. /opt/scripts/oqs_env.sh
openssl list -providers
echo ""

# Start nginx
exec /opt/nginx/sbin/nginx -g "daemon off;"