#!/bin/bash

# Load OpenSSL environment
. /opt/scripts/oqs_env.sh

echo -e "\n Check providers loading ..."
openssl list -providers
echo -e "\n"

# Execute h2load with all arguments
exec h2load "$@"