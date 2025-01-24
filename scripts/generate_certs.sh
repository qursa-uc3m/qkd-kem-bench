#!/bin/bash

BASE_DIR=$(pwd)
echo ""
echo "========== SESSION PATHS & CONFIG =========="
echo ""
echo "Base directory: $BASE_DIR"

# First, determine OpenSSL installation location - this is the primary condition
if [ ! -z "$OPENSSL_INSTALL" ]; then
    # Case 1: User specified custom OpenSSL installation
    OPENSSL="${OPENSSL_INSTALL}/bin/openssl"
    PROVIDER_PATH="${OPENSSL_INSTALL}/lib/ossl-modules"
elif [ -f "${BASE_DIR}/.local/bin/openssl" ]; then
    # Case 2: Local installation in project directory
    OPENSSL="${BASE_DIR}/.local/bin/openssl"
    PROVIDER_PATH="${BASE_DIR}/_build/lib"
else
    # Case 3: System-wide installation
    OPENSSL="/opt/oqs_openssl3/bin/openssl"
    PROVIDER_PATH="/opt/oqs_openssl3/lib/ossl-modules"
fi

# Set up environment variables based on determined paths
export LD_LIBRARY_PATH="${PROVIDER_PATH}:$LD_LIBRARY_PATH"
export OPENSSL_MODULES="${PROVIDER_PATH}"
export OPENSSL_CONF="${BASE_DIR}/scripts/openssl-ca.cnf"

# Debug: Print all paths
echo "OpenSSL binary: $OPENSSL"
echo "Provider path: $PROVIDER_PATH"
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
echo "OPENSSL_MODULES: $OPENSSL_MODULES"
echo "OpenSSL configuration file: $OPENSSL_CONF"

# Verify critical files exist
if [ ! -f "$OPENSSL_CONF" ]; then
    echo "Error: OpenSSL configuration file not found at $OPENSSL_CONF"
    exit 1
fi

if [ ! -f "$OPENSSL" ]; then
    echo "Error: OpenSSL binary not found at $OPENSSL"
    exit 1
fi

# Verify provider libraries exist
OQS_PROVIDER_PATH="${PROVIDER_PATH}/oqsprovider.so"
if [ ! -f "$OQS_PROVIDER_PATH" ]; then
    echo "Error: OQS provider library not found at $OQS_PROVIDER_PATH"
    exit 1
fi
echo "OQS provider library: $OQS_PROVIDER_PATH"

# Create directory structure
CERT_BASE_DIR="${BASE_DIR}/certs"
DILITHIUM_DIR="${CERT_BASE_DIR}/dilithium"
MLDSA_DIR="${CERT_BASE_DIR}/mldsa"
FALCON_DIR="${CERT_BASE_DIR}/falcon"
SPHINCS_SHA2_DIR="${CERT_BASE_DIR}/sphincssha2"
SPHINCS_SHAKE_DIR="${CERT_BASE_DIR}/sphincsshake"
RSA_DIR="${CERT_BASE_DIR}/rsa"

mkdir -p ${CERT_BASE_DIR}
mkdir -p ${DILITHIUM_DIR}
mkdir -p ${MLDSA_DIR}
mkdir -p ${FALCON_DIR}
mkdir -p ${SPHINCS_SHA2_DIR}
mkdir -p ${SPHINCS_SHAKE_DIR}
mkdir -p ${RSA_DIR}

# Verify OpenSSL version
echo ""
echo "========== OPENSSL VERSION INFO =========="
echo ""
echo "Running OpenSSL from: $OPENSSL"
OPENSSL_MODULES="${PROVIDER_PATH}"
${OPENSSL} version || { echo "Error: OpenSSL binary not found or not executable."; exit 1; }
echo ""

# Generate conf files.
printf "\
[ req ]\n\
prompt                 = no\n\
distinguished_name     = req_distinguished_name\n\
\n\
[ req_distinguished_name ]\n\
C                      = CA\n\
ST                     = ON\n\
L                      = Waterloo\n\
O                      = wolfSSL Inc.\n\
OU                     = Engineering\n\
CN                     = Root Certificate\n\
emailAddress           = root@wolfssl.com\n\
\n\
[ ca_extensions ]\n\
subjectKeyIdentifier   = hash\n\
authorityKeyIdentifier = keyid:always,issuer:always\n\
keyUsage               = critical, keyCertSign\n\
basicConstraints       = critical, CA:true\n" > root.conf

printf "\
[ req ]\n\
prompt                 = no\n\
distinguished_name     = req_distinguished_name\n\
\n\
[ req_distinguished_name ]\n\
C                      = CA\n\
ST                     = ON\n\
L                      = Waterloo\n\
O                      = wolfSSL Inc.\n\
OU                     = Engineering\n\
CN                     = Entity Certificate\n\
emailAddress           = entity@wolfssl.com\n\
\n\
[ x509v3_extensions ]\n\
subjectAltName = IP:127.0.0.1\n\
subjectKeyIdentifier   = hash\n\
authorityKeyIdentifier = keyid:always,issuer:always\n\
keyUsage               = critical, digitalSignature\n\
extendedKeyUsage       = critical, serverAuth,clientAuth\n\
basicConstraints       = critical, CA:false\n" > entity.conf


echo "========== GENERATING CERTIFICATES =========="
echo ""

###############################################################################
# Dilithium (All Levels)
###############################################################################

DILITHIUM_LEVELS=("dilithium2" "dilithium3" "dilithium5")

for level in "${DILITHIUM_LEVELS[@]}"; do
    echo "Generating ${level^^} keys..."
    ${OPENSSL} genpkey -algorithm ${level} -outform pem -out ${DILITHIUM_DIR}/${level}_root_key.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default
    ${OPENSSL} genpkey -algorithm ${level} -outform pem -out ${DILITHIUM_DIR}/${level}_entity_key.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo "Generating ${level^^} root certificate..."
    ${OPENSSL} req -x509 -config root.conf -extensions ca_extensions -days 1095 -set_serial 256 -key ${DILITHIUM_DIR}/${level}_root_key.pem -out ${DILITHIUM_DIR}/${level}_root_cert.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo "Generating ${level^^} entity CSR..."
    ${OPENSSL} req -new -config entity.conf -key ${DILITHIUM_DIR}/${level}_entity_key.pem -out ${DILITHIUM_DIR}/${level}_entity_req.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo "Generating ${level^^} entity certificate..."
    ${OPENSSL} x509 -req -in ${DILITHIUM_DIR}/${level}_entity_req.pem -CA ${DILITHIUM_DIR}/${level}_root_cert.pem -CAkey ${DILITHIUM_DIR}/${level}_root_key.pem -extfile entity.conf -extensions x509v3_extensions -days 1095 -set_serial 257 -out ${DILITHIUM_DIR}/${level}_entity_cert.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo ""
done

###############################################################################
# ML-DSA (All Levels)
###############################################################################

MLDSA_LEVELS=("mldsa44" "mldsa65" "mldsa87")

for level in "${MLDSA_LEVELS[@]}"; do
    echo "Generating ${level^^} keys..."
    ${OPENSSL} genpkey -algorithm ${level} -outform pem -out ${MLDSA_DIR}/${level}_root_key.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default
    ${OPENSSL} genpkey -algorithm ${level} -outform pem -out ${MLDSA_DIR}/${level}_entity_key.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo "Generating ${level^^} root certificate..."
    ${OPENSSL} req -x509 -config root.conf -extensions ca_extensions -days 1095 -set_serial 512 -key ${MLDSA_DIR}/${level}_root_key.pem -out ${MLDSA_DIR}/${level}_root_cert.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo "Generating ${level^^} entity CSR..."
    ${OPENSSL} req -new -config entity.conf -key ${MLDSA_DIR}/${level}_entity_key.pem -out ${MLDSA_DIR}/${level}_entity_req.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo "Generating ${level^^} entity certificate..."
    ${OPENSSL} x509 -req -in ${MLDSA_DIR}/${level}_entity_req.pem -CA ${MLDSA_DIR}/${level}_root_cert.pem -CAkey ${MLDSA_DIR}/${level}_root_key.pem -extfile entity.conf -extensions x509v3_extensions -days 1095 -set_serial 513 -out ${MLDSA_DIR}/${level}_entity_cert.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo ""
done

###############################################################################
# Falcon (All Levels)
###############################################################################

FALCON_LEVELS=("falcon512" "falcon1024")

for level in "${FALCON_LEVELS[@]}"; do
    echo "Generating ${level^^} keys..."
    ${OPENSSL} genpkey -algorithm ${level} -outform pem -out ${FALCON_DIR}/${level}_root_key.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default
    ${OPENSSL} genpkey -algorithm ${level} -outform pem -out ${FALCON_DIR}/${level}_entity_key.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo "Generating ${level^^} root certificate..."
    ${OPENSSL} req -x509 -config root.conf -extensions ca_extensions -days 1095 -set_serial 1024 -key ${FALCON_DIR}/${level}_root_key.pem -out ${FALCON_DIR}/${level}_root_cert.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo "Generating ${level^^} entity CSR..."
    ${OPENSSL} req -new -config entity.conf -key ${FALCON_DIR}/${level}_entity_key.pem -out ${FALCON_DIR}/${level}_entity_req.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo "Generating ${level^^} entity certificate..."
    ${OPENSSL} x509 -req -in ${FALCON_DIR}/${level}_entity_req.pem -CA ${FALCON_DIR}/${level}_root_cert.pem -CAkey ${FALCON_DIR}/${level}_root_key.pem -extfile entity.conf -extensions x509v3_extensions -days 1095 -set_serial 1025 -out ${FALCON_DIR}/${level}_entity_cert.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo ""
done

###############################################################################
# SPHINCS+ SHA2 (All Levels)
###############################################################################

# Commented algorithms are not currently supported for TLS ops

SPHINCS_SHA2_LEVELS=(
    "sphincssha2128fsimple"
    "sphincssha2128ssimple"
    "sphincssha2192fsimple"
    #"sphincssha2192ssimple"
    #"sphincssha2256fsimple" 
    #"sphincssha2256ssimple" 
)

for level in "${SPHINCS_SHA2_LEVELS[@]}"; do
    echo "Generating ${level^^} keys..."
    ${OPENSSL} genpkey -algorithm ${level} -outform pem -out ${SPHINCS_SHA2_DIR}/${level}_root_key.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default
    ${OPENSSL} genpkey -algorithm ${level} -outform pem -out ${SPHINCS_SHA2_DIR}/${level}_entity_key.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo "Generating ${level^^} root certificate..."s
    ${OPENSSL} req -x509 -config root.conf -extensions ca_extensions -days 1095 -set_serial 4096 -key ${SPHINCS_SHA2_DIR}/${level}_root_key.pem -out ${SPHINCS_SHA2_DIR}/${level}_root_cert.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo "Generating ${level^^} entity CSR..."
    ${OPENSSL} req -new -config entity.conf -key ${SPHINCS_SHA2_DIR}/${level}_entity_key.pem -out ${SPHINCS_SHA2_DIR}/${level}_entity_req.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo "Generating ${level^^} entity certificate..."
    ${OPENSSL} x509 -req -in ${SPHINCS_SHA2_DIR}/${level}_entity_req.pem -CA ${SPHINCS_SHA2_DIR}/${level}_root_cert.pem -CAkey ${SPHINCS_SHA2_DIR}/${level}_root_key.pem -extfile entity.conf -extensions x509v3_extensions -days 1095 -set_serial 4097 -out ${SPHINCS_SHA2_DIR}/${level}_entity_cert.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo ""
done

###############################################################################
# SPHINCS+ SHAKE (All Levels)
###############################################################################

# Commented algorithms are not currently supported for TLS ops

SPHINCS_SHAKE_LEVELS=(
    "sphincsshake128fsimple"
    #"sphincsshake128ssimple"
    #"sphincsshake192fsimple"
    #"sphincsshake192ssimple"
    #"sphincsshake256fsimple"
    #"sphincsshake256ssimple"
)

for level in "${SPHINCS_SHAKE_LEVELS[@]}"; do
    echo "Generating ${level^^} keys..."
    ${OPENSSL} genpkey -algorithm ${level} -outform pem -out ${SPHINCS_SHAKE_DIR}/${level}_root_key.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default
    ${OPENSSL} genpkey -algorithm ${level} -outform pem -out ${SPHINCS_SHAKE_DIR}/${level}_entity_key.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo "Generating ${level^^} root certificate..."
    ${OPENSSL} req -x509 -config root.conf -extensions ca_extensions -days 1095 -set_serial 4096 -key ${SPHINCS_SHAKE_DIR}/${level}_root_key.pem -out ${SPHINCS_SHAKE_DIR}/${level}_root_cert.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo "Generating ${level^^} entity CSR..."
    ${OPENSSL} req -new -config entity.conf -key ${SPHINCS_SHAKE_DIR}/${level}_entity_key.pem -out ${SPHINCS_SHAKE_DIR}/${level}_entity_req.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo "Generating ${level^^} entity certificate..."
    ${OPENSSL} x509 -req -in ${SPHINCS_SHAKE_DIR}/${level}_entity_req.pem -CA ${SPHINCS_SHAKE_DIR}/${level}_root_cert.pem -CAkey ${SPHINCS_SHAKE_DIR}/${level}_root_key.pem -extfile entity.conf -extensions x509v3_extensions -days 1095 -set_serial 4097 -out ${SPHINCS_SHAKE_DIR}/${level}_entity_cert.pem -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default

    echo ""
done

###############################################################################
# RSA (Multiple Key Sizes)
###############################################################################

RSA_LEVELS=("rsa_2048" "rsa_3072" "rsa_4096")

for level in "${RSA_LEVELS[@]}"; do
    echo "Generating ${level^^} keys..."
    ${OPENSSL} genpkey -algorithm RSA -out ${RSA_DIR}/${level}_root_key.pem -pkeyopt rsa_keygen_bits:${level#rsa_}
    ${OPENSSL} genpkey -algorithm RSA -out ${RSA_DIR}/${level}_entity_key.pem -pkeyopt rsa_keygen_bits:${level#rsa_}

    echo "Generating ${level^^} root certificate..."
    ${OPENSSL} req -x509 -config root.conf -extensions ca_extensions -days 1095 -set_serial 2048 -key ${RSA_DIR}/${level}_root_key.pem -out ${RSA_DIR}/${level}_root_cert.pem

    echo "Generating ${level^^} entity CSR..."
    ${OPENSSL} req -new -config entity.conf -key ${RSA_DIR}/${level}_entity_key.pem -out ${RSA_DIR}/${level}_entity_req.pem

    echo "Generating ${level^^} entity certificate..."
    ${OPENSSL} x509 -req -in ${RSA_DIR}/${level}_entity_req.pem -CA ${RSA_DIR}/${level}_root_cert.pem -CAkey ${RSA_DIR}/${level}_root_key.pem -extfile entity.conf -extensions x509v3_extensions -days 1095 -set_serial 2049 -out ${RSA_DIR}/${level}_entity_cert.pem

    echo ""
done

###############################################################################
# Verify all generated certificates.
###############################################################################

echo "Verifying certificates..."

# Dilithium
for level in "${DILITHIUM_LEVELS[@]}"; do
    ${OPENSSL} verify -no-CApath -check_ss_sig -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default -CAfile ${DILITHIUM_DIR}/${level}_root_cert.pem ${DILITHIUM_DIR}/${level}_entity_cert.pem
done

# ML-DSA
for level in "${MLDSA_LEVELS[@]}"; do
    ${OPENSSL} verify -no-CApath -check_ss_sig -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default -CAfile ${MLDSA_DIR}/${level}_root_cert.pem ${MLDSA_DIR}/${level}_entity_cert.pem
done

# Falcon
for level in "${FALCON_LEVELS[@]}"; do
    ${OPENSSL} verify -no-CApath -check_ss_sig -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default -CAfile ${FALCON_DIR}/${level}_root_cert.pem ${FALCON_DIR}/${level}_entity_cert.pem
done

# SPHINCS+ SHA2 Verification
for level in "${SPHINCS_SHA2_LEVELS[@]}"; do
    ${OPENSSL} verify -no-CApath -check_ss_sig -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default -CAfile ${SPHINCS_SHA2_DIR}/${level}_root_cert.pem ${SPHINCS_SHA2_DIR}/${level}_entity_cert.pem
done

# SPHINCS+ SHAKE Verification
for level in "${SPHINCS_SHAKE_LEVELS[@]}"; do
    ${OPENSSL} verify -no-CApath -check_ss_sig -provider-path ${PROVIDER_PATH} -provider oqsprovider -provider default -CAfile ${SPHINCS_SHAKE_DIR}/${level}_root_cert.pem ${SPHINCS_SHAKE_DIR}/${level}_entity_cert.pem
done

# RSA
for level in "${RSA_LEVELS[@]}"; do
    ${OPENSSL} verify -no-CApath -check_ss_sig -CAfile ${RSA_DIR}/${level}_root_cert.pem ${RSA_DIR}/${level}_entity_cert.pem
done

echo ""

echo ""
echo "========== GENERATION COMPLETED SUCCESSFULLY =========="

# Cleanup temporary config files
rm -f root.conf entity.conf