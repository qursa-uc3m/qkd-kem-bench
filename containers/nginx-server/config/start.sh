#!/bin/bash

# Source the environment script
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

if [ "$QKD_DEBUG" -gt 0 ]; then
  echo -e "DEBUG MODE: ACTIVE with level $QKD_DEBUG\n"
else    
  echo -e "DEBUG MODE: INACTIVE\n"
fi

# Copy original nginx.conf to a template file
cp /opt/nginx/conf/nginx.conf /opt/nginx/conf/nginx.conf.template

# Create a list of variable names for substitution (without $ prefix)
VARS=$(env | grep -E "^(QKD_|OPENSSL|SSL_CERT_DIR|SSL_CERT_TYPE|DEFAULT_GROUPS)" | cut -d= -f1)

# Create the comma-separated list with $ prefix for envsubst
DOLLAR_VARS=""
for var in $VARS; do
    if [ -z "$DOLLAR_VARS" ]; then
        DOLLAR_VARS="\$$var"
    else
        DOLLAR_VARS="$DOLLAR_VARS,\$$var"
    fi
    # Also export the variable to make sure it's available
    export "$var"
done

echo "Variables to be substituted: $DOLLAR_VARS"

# Process the template with envsubst
envsubst "$DOLLAR_VARS" < /opt/nginx/conf/nginx.conf.template > /opt/nginx/conf/nginx.conf

# Debug: Show final configuration
echo -e "\nFinal NGINX configuration:"
grep -n "ssl_certificate" /opt/nginx/conf/nginx.conf
grep -n "ssl_ecdh_curve" /opt/nginx/conf/nginx.conf

# Check providers loading
echo -e "\nCheck providers loading ..."
openssl version
openssl list -providers
echo ""

# Make sure our paths include all necessary libraries
export LD_LIBRARY_PATH="$OPENSSL_INSTALL/lib64:$OPENSSL_INSTALL/lib:$OPENSSL_MODULES:$LD_LIBRARY_PATH:/opt"

# Start NGINX directly - no need for the exec env wrapper
echo -e "\nStarting Nginx ..."
/opt/nginx/sbin/nginx -g "daemon off;"