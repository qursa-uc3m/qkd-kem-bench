#!/bin/bash

# qkd_api_test.sh
# Comprehensive testing script for QuKayDee ETSI014 API

set -e

# ------------------------------
# Function Definitions
# ------------------------------

# Function to print section headers
print_header() {
    echo -e "\n\033[1;36m=== $1 ===\033[0m\n"
}

# Function to print informational messages in blue
print_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

# Function to print success messages in green
print_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

# Function to print error messages in red
print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# Function to print warning messages in yellow
print_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

# Function to print JSON with proper indentation and coloring
print_json() {
    echo "$1" | jq -C '.'
}

# Function to check if a file exists with improved output
check_file_exists() {
    local file="$1"
    local desc="$2"
    
    if [[ ! -f "$file" ]]; then
        print_error "Required ${desc} not found: $file"
        return 1
    else
        print_success "Found ${desc}: $file"
        return 0
    fi
}

# ------------------------------
# API Testing Definitions
# ------------------------------

# Function to perform the STATUS API call
get_status() {
    print_header "Retrieving Status Information"
    print_info "Querying status for Slave SAE: ${SLAVE_SAE_ID}"
    print_info "Using KME endpoint: ${QKD_MASTER_KME_HOSTNAME}"
    
    response=$(curl --silent --show-error -i \
        --cacert "${CACERT}" \
        --cert "${MASTER_CERT}" \
        --key "${MASTER_KEY}" \
        --header "Accept: application/json" \
        "${QKD_MASTER_KME_HOSTNAME}/api/v1/keys/${SLAVE_SAE_ID}/status")
    
    # Extract HTTP status code
    http_code=$(echo "$response" | grep HTTP | awk '{print $2}')
    
    if [[ "$http_code" -eq 200 ]]; then
        print_success "Status retrieved successfully (HTTP $http_code)"
        # Extract JSON body (skip headers)
        body=$(echo "$response" | sed -n '/^\r$/,$p' | tail -n +2)
        print_json "$body"
        
        # Extract and display key metrics
        local stored_keys=$(echo "$body" | jq -r '.stored_key_count')
        local max_keys=$(echo "$body" | jq -r '.max_key_count')
        local key_size=$(echo "$body" | jq -r '.key_size')
        
        print_info "Current Status:"
        print_info "├── Stored Keys: $stored_keys / $max_keys"
        print_info "└── Key Size: $key_size bits"
    else
        print_error "Failed to retrieve status (HTTP $http_code)"
        body=$(echo "$response" | sed -n '/^\r$/,$p' | tail -n +2)
        print_json "$body"
        return 1
    fi
}

# Function to perform the GET_KEYS API call
# Function to perform the GET_KEYS API call
get_enc_keys() {
    print_header "Retrieving Encryption Keys"
    print_info "Requesting encryption keys for Slave SAE: ${SLAVE_SAE_ID}"
    print_info "Using KME endpoint: ${QKD_MASTER_KME_HOSTNAME}"
    
    response=$(curl --silent --show-error -i \
        --cacert "${CACERT}" \
        --cert "${MASTER_CERT}" \
        --key "${MASTER_KEY}" \
        --header "Accept: application/json" \
        "${QKD_MASTER_KME_HOSTNAME}/api/v1/keys/${SLAVE_SAE_ID}/enc_keys")
    
    # Extract HTTP status code
    http_code=$(echo "$response" | grep HTTP | awk '{print $2}')
    
    if [[ "$http_code" -eq 200 ]]; then
        print_success "Encryption keys retrieved successfully (HTTP $http_code)"
        # Extract JSON body (skip headers)
        body=$(echo "$response" | sed -n '/^\r$/,$p' | tail -n +2)
        
        # Extract key details before displaying
        local key_count=$(echo "$body" | jq '.keys | length')
        local first_key_id=$(echo "$body" | jq -r '.keys[0].key_ID')
        
        # Display response information
        print_info "Response:"
        print_json "$body"
        print_info "Keys Retrieved: $key_count"
        print_info "Selected Key ID: $first_key_id"
        print_success "Key ID extraction successful"
        
        # Return just the key_ID
        echo "$first_key_id"
    else
        print_error "Failed to retrieve encryption keys (HTTP $http_code)"
        body=$(echo "$response" | sed -n '/^\r$/,$p' | tail -n +2)
        print_json "$body"
        return 1
    fi
}

# Function to perform the GET_KEYS_WITH_IDs API call
get_dec_keys() {
    local key_id=$1
    print_header "Retrieving Decryption Keys"
    print_info "Requesting decryption key for ID: ${key_id}"
    print_info "Using KME endpoint: ${QKD_SLAVE_KME_HOSTNAME}"
    
    # Construct the JSON payload
    json_payload=$(jq -n \
        --arg key_id "$key_id" \
        --arg master_sae "$MASTER_SAE_ID" \
        '{
            key_IDs: [{
                key_ID: $key_id,
                master_SAE_ID: $master_sae
            }]
        }')
    
    print_info "Request Payload:"
    print_json "$json_payload"
    
    response=$(curl --silent --show-error -i \
        --cacert "${CACERT}" \
        --cert "${SLAVE_CERT}" \
        --key "${SLAVE_KEY}" \
        --header "Accept: application/json" \
        --header "Content-Type: application/json" \
        --data "${json_payload}" \
        "${QKD_SLAVE_KME_HOSTNAME}/api/v1/keys/${MASTER_SAE_ID}/dec_keys")
    
    # Extract HTTP status code
    http_code=$(echo "$response" | grep HTTP | awk '{print $2}')
    
    if [[ "$http_code" -eq 200 ]]; then
        print_success "Decryption key retrieved successfully (HTTP $http_code)"
        # Extract JSON body (skip headers)
        body=$(echo "$response" | sed -n '/^\r$/,$p' | tail -n +2)
        print_info "Response:"
        print_json "$body"
        
        # Verify key ID matches request
        local returned_key_id=$(echo "$body" | jq -r '.keys[0].key_ID')
        if [[ "$returned_key_id" == "$key_id" ]]; then
            print_success "Key ID verification successful"
        else
            print_warning "Key ID mismatch: Expected $key_id, got $returned_key_id"
        fi
    else
        print_error "Failed to retrieve decryption key (HTTP $http_code)"
        body=$(echo "$response" | sed -n '/^\r$/,$p' | tail -n +2)
        print_json "$body"
        return 1
    fi
}

# ------------------------------
# Environment Variables Setup
# ------------------------------

# Replace with your actual account ID
ACCOUNT_ID="2507"

# Assign paths to variables for easier reference

export QKD_CA_CERT_PATH="/home/dsobral/Repos/qkd-kem-bench/qkd_certs/account-2507-server-ca-qukaydee-com.crt"

export MASTER_SAE_ID="sae-1"
export SLAVE_SAE_ID="sae-2"

export QKD_MASTER_KME_HOSTNAME="https://kme-1.acct-${ACCOUNT_ID}.etsi-qkd-api.qukaydee.com"
export QKD_SLAVE_KME_HOSTNAME="https://kme-2.acct-${ACCOUNT_ID}.etsi-qkd-api.qukaydee.com"

export QKD_MASTER_CERT_PATH="/home/dsobral/Repos/qkd-kem-bench/qkd_certs/sae-1.crt"
export QKD_MASTER_KEY_PATH="/home/dsobral/Repos/qkd-kem-bench/qkd_certs/sae-1.key"

export QKD_SLAVE_CERT_PATH="/home/dsobral/Repos/qkd-kem-bench/qkd_certs/sae-2.crt"
export QKD_SLAVE_KEY_PATH="/home/dsobral/Repos/qkd-kem-bench/qkd_certs/sae-2.key"


CACERT="${QKD_MASTER_CA_CERT_PATH}"

MASTER_CERT="${QKD_MASTER_CERT_PATH}"
MASTER_KEY="${QKD_MASTER_KEY_PATH}"

SLAVE_CERT="${QKD_SLAVE_CERT_PATH}"
SLAVE_KEY="${QKD_SLAVE_KEY_PATH}"

# ------------------------------
# Main Script
# ------------------------------

print_header "QuKayDee ETSI014 API Testing Script"

# Pre-flight checks
print_header "Pre-flight Checks"
print_info "Verifying required certificates and keys..."

# Check for required certificate and key files
check_file_exists "${CACERT}" "CA certificate" || exit 1
check_file_exists "${MASTER_CERT}" "master certificate" || exit 1
check_file_exists "${MASTER_KEY}" "master key" || exit 1
check_file_exists "${SLAVE_CERT}" "slave certificate" || exit 1
check_file_exists "${SLAVE_KEY}" "slave key" || exit 1

print_success "All pre-flight checks passed"

# Execute API tests
if ! get_status; then
    print_error "Status check failed. Aborting further tests."
    exit 1
fi

# Get encryption keys
print_header "Retrieving Encryption Key "
print_info "Querying status for Slave SAE: ${SLAVE_SAE_ID}"
print_info "Using KME endpoint: ${QKD_MASTER_KME_HOSTNAME}"

key_id_output=$(get_enc_keys)
enc_keys_status=$?

if [ $enc_keys_status -ne 0 ]; then
    print_error "Failed to retrieve encryption keys. Aborting."
    exit 1
fi

print_success "Encryption key retrieved successfully"

# Extract just the last line which contains the key_ID
key_id=$(echo "$key_id_output" | tail -n 1)
if [[ -z "$key_id" || "$key_id" == "null" ]]; then
    print_error "Failed to extract valid encryption key ID. Aborting."
    exit 1
fi

# Get decryption key using the extracted key_ID
if ! get_dec_keys "$key_id"; then
    print_error "Failed to retrieve decryption key."
    exit 1
fi

print_header "Test Summary"
print_success "All API tests completed successfully"
