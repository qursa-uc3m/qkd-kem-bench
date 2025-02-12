#!/bin/bash

# Colors for output
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color
TICK="✓"
CROSS="✗"

# Parse arguments with defaults optimized for debugging
ITERATIONS=1
PROVIDER="qkd"
DELAY=0  # Default delay between tests
KEM="bikel1"
CERT="rsa_3072"

# Help function
print_usage() {
    echo "Usage: $0 [-i iterations] [-k kem] [-c cert] [-d delay_seconds]"
    echo "Debug script for TLS handshake testing"
    echo ""
    echo "Options:"
    echo "  -i  Number of iterations (default: 1)"
    echo "  -k  KEM algorithm to test (default: bikel1)"
    echo "  -c  Certificate to use (default: rsa_3072)"
    echo "  -d  Delay between tests in seconds (default: 0)"
    echo ""
    echo "Available KEMs: bikel1, bikel3, bikel5"
    echo "Available certs: rsa_2048, rsa_3072, rsa_4096, mldsa44, mldsa65, mldsa87, falcon512, falcon1024"
    exit 1
}

# Parse command line arguments
while getopts "i:k:c:d:h" opt; do
    case $opt in
        i) ITERATIONS="$OPTARG" ;;
        k) KEM="$OPTARG" ;;
        c) CERT="$OPTARG" ;;
        d) 
            if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
                DELAY="$OPTARG"
            else
                echo "Error: delay must be a non-negative integer" >&2
                exit 1
            fi
            ;;
        h) print_usage ;;
        *) print_usage ;;
    esac
done

# Setup environment
echo -e "${BLUE}Setting up environment...${NC}"
source ./scripts/oqs_env.sh 

export QKD_MASTER_KME="castor.det.uvigo.es:444"
export QKD_SLAVE_KME="castor.det.uvigo.es:442"

CACERT="${QKD_MASTER_CA_CERT_PATH}"

MASTER_CERT="${QKD_MASTER_CERT_PATH}"
MASTER_KEY="${QKD_MASTER_KEY_PATH}"

SLAVE_CERT="${QKD_SLAVE_CERT_PATH}"
SLAVE_KEY="${QKD_SLAVE_KEY_PATH}"

# Create debug log directory
DEBUG_DIR="$(pwd)/debug_logs"
mkdir -p "$DEBUG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DEBUG_LOG="${DEBUG_DIR}/tls_debug_${KEM}_${CERT}_${TIMESTAMP}.log"

# Print test configuration
echo -e "${BLUE}Test Configuration:${NC}"
echo "KEM Algorithm: $KEM"
echo "Certificate: $CERT"
echo "Iterations: $ITERATIONS"
echo "Delay between tests: $DELAY seconds"
echo "Debug log: $DEBUG_LOG"
echo ""

# Log system information
{
    echo "=== Test Configuration ==="
    echo "Date: $(date)"
    echo "KEM: $KEM"
    echo "Certificate: $CERT"
    echo "Iterations: $ITERATIONS"
    echo "Delay: $DELAY seconds"
    echo ""
    echo "=== System Information ==="
    echo "OS: $(uname -a)"
    echo "OpenSSL version: $(openssl version)"
    echo ""
} > "$DEBUG_LOG"

# Function to print separator line
print_separator() {
    echo -e "\n${BLUE}=========================================${NC}"
}

# Check QKD key pool status before test
echo -e "\n${BLUE}Checking QKD key pool status...${NC}"
curl -Ss --silent --show-error -i \
        --cacert "${CACERT}" \
        --cert "${MASTER_CERT}" \
        --key "${MASTER_KEY}" \
        --header "Accept: application/json" \
        -k "https://${QKD_MASTER_KME}/api/v1/keys/${QKD_SLAVE_SAE}/status" | tee -a "$DEBUG_LOG"
echo "" | tee -a "$DEBUG_LOG"

sleep 2

# Run the tests
for ((i=1; i<=ITERATIONS; i++)); do
    print_separator
    echo -e "${BLUE}Starting iteration $i of $ITERATIONS${NC}"
    echo -e "\n=== Starting iteration $i at $(date) ===" >> "$DEBUG_LOG"
    
    # Run the test with maximum verbosity
    echo -e "\n${BLUE}Running TLS handshake test...${NC}"
    {
        echo "=== TLS Test Output ==="
        OPENSSL_DEBUG=2 python3 scripts/test_qkd_kem_tls.py \
            -k "$KEM" \
            -c "$CERT" \
            -p "qkd" \
            2>&1
    } | tee -a "$DEBUG_LOG"
    
    # Check exit status
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo -e "\n${GREEN}${TICK} Test completed successfully${NC}"
    else
        echo -e "\n${RED}${CROSS} Test failed${NC}"
    fi
    
    # Add delay between iterations if not the last one
    if [ $i -lt $ITERATIONS ]; then
        echo -e "\n${BLUE}Waiting $DELAY seconds before next iteration...${NC}"
        echo "=== Delay period started at $(date) ===" >> "$DEBUG_LOG"
        sleep "$DELAY"
    fi
done

# Check QKD key pool status after test
    echo -e "\n${BLUE}Checking QKD key pool status after test...${NC}"
    curl -Ss --silent --show-error -i \
        --cacert "${CACERT}" \
        --cert "${MASTER_CERT}" \
        --key "${MASTER_KEY}" \
        --header "Accept: application/json" \
        -k "https://${QKD_MASTER_KME}/api/v1/keys/${QKD_SLAVE_SAE}/status" | tee -a "$DEBUG_LOG"
    echo "" | tee -a "$DEBUG_LOG"

print_separator
echo -e "${BLUE}Testing completed. Debug log saved to: $DEBUG_LOG${NC}"