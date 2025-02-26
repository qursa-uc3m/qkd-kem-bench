#!/bin/bash

# Test script to verify h2load-bench container configuration

echo "=== Testing h2load-bench container configuration ==="

echo -e "\n1. Checking if container image exists:"
docker images | grep h2load-bench

echo -e "\n2. Running basic container test with environment check:"
docker run --rm containers_h2load-bench /bin/bash -c "
    echo '== Container environment variables =='
    echo \"OPENSSL_INSTALL: \$OPENSSL_INSTALL\"
    echo \"OPENSSL_CONF: \$OPENSSL_CONF\"
    echo \"OPENSSL_MODULES: \$OPENSSL_MODULES\"
    echo \"LD_LIBRARY_PATH: \$LD_LIBRARY_PATH\"
    echo \"QKD_BACKEND: \$QKD_BACKEND\"
    
    echo -e '\n== File existence checks =='
    echo \"OpenSSL config file exists: \$(test -f \$OPENSSL_CONF && echo Yes || echo No)\"
    echo \"OpenSSL modules directory exists: \$(test -d \$OPENSSL_MODULES && echo Yes || echo No)\"
    echo \"OpenSSL binary exists: \$(which openssl || echo Not found)\"
    echo \"h2load binary exists: \$(which h2load || echo Not found)\"
    echo \"h2load-wrapper exists: \$(test -f /usr/local/bin/h2load-wrapper && echo Yes || echo No)\"
    
    echo -e '\n== Library checks =='
    echo \"oqsprovider.so exists: \$(test -f \$OPENSSL_MODULES/oqsprovider.so && echo Yes || echo No)\"
    echo \"qkdkemprovider.so exists: \$(test -f \$OPENSSL_MODULES/qkdkemprovider.so && echo Yes || echo No)\"
    echo \"libqkd-etsi-api.so exists: \$(find \$OPENSSL_INSTALL -name \"libqkd-etsi-api.so\" || echo Not found)\"
    
    echo -e '\n== Source environment script and check OpenSSL providers =='
    . /opt/scripts/oqs_env.sh
    openssl list -providers
    
    echo -e '\n== Test h2load version =='
    h2load --version
    
    echo -e '\n== Check h2load-wrapper content =='
    cat /usr/local/bin/h2load-wrapper
"

echo -e "\n3. Testing basic HTTPS connection to nginx-server:"
docker run --rm --network=host containers_h2load-bench /bin/bash -c "
    . /opt/scripts/oqs_env.sh
    echo 'Attempting TLS connection to nginx-server:4433...'
    timeout 5 openssl s_client -connect nginx-server:4433 -brief || echo 'Connection failed'
"

echo -e "\n4. Testing h2load basic command:"
docker run --rm --network=host containers_h2load-bench /bin/bash -c "
    . /opt/scripts/oqs_env.sh
    echo 'Attempting simple h2load request...'
    h2load -n 1 -c 1 https://nginx-server:4433 || echo 'h2load request failed'
"

echo -e "\n=== Test completed ==="