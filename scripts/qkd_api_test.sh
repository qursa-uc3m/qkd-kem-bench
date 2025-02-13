#!/bin/bash
# qkd_api_test.sh
# Comprehensive testing script for QuKayDee ETSI014 API

set -e

# ------------------------------------------------------------------
# Source common utilities (logging, file/path helpers, etc.)
# ------------------------------------------------------------------
SCRIPT_DIR=$(pwd)/scripts
source "${SCRIPT_DIR}/common.sh"

# ------------------------------------------------------------------
# API Testing Functions
# ------------------------------------------------------------------

get_status() {
    log_section "Retrieving Status Information"
    log_info "Querying status for Slave SAE: ${SLAVE_SAE_ID}"
    log_info "Using KME endpoint: ${QKD_MASTER_KME_HOSTNAME}"
    
    response=$(curl -Ss --silent --show-error -i \
        --cacert "${CACERT}" \
        --cert "${MASTER_CERT}" \
        --key "${MASTER_KEY}" \
        --header "Accept: application/json" \
        -k "https://${QKD_MASTER_KME_HOSTNAME}/api/v1/keys/${SLAVE_SAE_ID}/status")
    
    # Extract HTTP status code
    http_code=$(echo "$response" | grep HTTP | awk '{print $2}')
    
    if [[ "$http_code" -eq 200 ]]; then
        log_success "Status retrieved successfully (HTTP $http_code)"
        # Extract JSON body (skip headers)
        body=$(echo "$response" | sed -n '/^\r$/,$p' | tail -n +2)
        log_json "$body"
        
        # Extract and display key metrics
        local stored_keys=$(echo "$body" | jq -r '.stored_key_count')
        local max_keys=$(echo "$body" | jq -r '.max_key_count')
        local key_size=$(echo "$body" | jq -r '.key_size')
        
        log_info "Current Status:"
        log_info "├── Stored Keys: ${stored_keys} / ${max_keys}"
        log_info "└── Key Size: ${key_size} bits"
    else
        log_error "Failed to retrieve status (HTTP $http_code)"
        body=$(echo "$response" | sed -n '/^\r$/,$p' | tail -n +2)
        log_json "$body"
        return 1
    fi
}

get_enc_keys() {
    log_section "Retrieving Encryption Keys"
    log_info "Requesting encryption keys for Slave SAE: ${SLAVE_SAE_ID}"
    log_info "Using KME endpoint: ${QKD_MASTER_KME_HOSTNAME}"
    
    response=$(curl -sS --silent --show-error -i \
        --cacert "${CACERT}" \
        --cert "${MASTER_CERT}" \
        --key "${MASTER_KEY}" \
        --header "Accept: application/json" \
        -k "https://${QKD_MASTER_KME_HOSTNAME}/api/v1/keys/${SLAVE_SAE_ID}/enc_keys")
    
    # Extract HTTP status code
    http_code=$(echo "$response" | grep HTTP | awk '{print $2}')
    
    if [[ "$http_code" -eq 200 ]]; then
        log_success "Encryption keys retrieved successfully (HTTP $http_code)"
        # Extract JSON body (skip headers)
        body=$(echo "$response" | sed -n '/^\r$/,$p' | tail -n +2)
        
        # Extract key details before displaying
        local key_count=$(echo "$body" | jq '.keys | length')
        local first_key_id=$(echo "$body" | jq -r '.keys[0].key_ID')
        
        log_info "Response:"
        log_json "$body"
        log_info "Keys Retrieved: ${key_count}"
        log_info "Selected Key ID: ${first_key_id}"
        log_success "Key ID extraction successful"
        
        # Return just the key_ID
        echo "$first_key_id"
    else
        log_error "Failed to retrieve encryption keys (HTTP $http_code)"
        body=$(echo "$response" | sed -n '/^\r$/,$p' | tail -n +2)
        log_json "$body"
        return 1
    fi
}

get_dec_keys() {
    local key_id="$1"
    log_section "Retrieving Decryption Keys"
    log_info "Requesting decryption key for ID: ${key_id}"
    log_info "Using KME endpoint: ${QKD_SLAVE_KME_HOSTNAME}"
    
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
    
    log_info "Request Payload:"
    log_json "$json_payload"
    
    response=$(curl -Ss --silent --show-error -i \
        --cacert "${CACERT}" \
        --cert "${SLAVE_CERT}" \
        --key "${SLAVE_KEY}" \
        --header "Accept: application/json" \
        --header "Content-Type: application/json" \
        --data "${json_payload}" \
        -k "https://${QKD_SLAVE_KME_HOSTNAME}/api/v1/keys/${MASTER_SAE_ID}/dec_keys")
    
    # Extract HTTP status code
    http_code=$(echo "$response" | grep HTTP | awk '{print $2}')
    
    if [[ "$http_code" -eq 200 ]]; then
        log_success "Decryption key retrieved successfully (HTTP $http_code)"
        # Extract JSON body (skip headers)
        body=$(echo "$response" | sed -n '/^\r$/,$p' | tail -n +2)
        log_info "Response:"
        log_json "$body"
        
        # Verify key ID matches request
        local returned_key_id=$(echo "$body" | jq -r '.keys[0].key_ID')
        if [[ "$returned_key_id" == "$key_id" ]]; then
            log_success "Key ID verification successful"
        else
            log_warning "Key ID mismatch: Expected ${key_id}, got ${returned_key_id}"
        fi
    else
        log_error "Failed to retrieve decryption key (HTTP $http_code)"
        body=$(echo "$response" | sed -n '/^\r$/,$p' | tail -n +2)
        log_json "$body"
        return 1
    fi
}

# ------------------------------------------------------------------
# Environment Variables Setup
# ------------------------------------------------------------------

# Replace with your actual account ID
ACCOUNT_ID="2507"

if [ "${QKD_BACKEND}" = "qukaydee" ]; then
    log_info "Setting up QuKayDee environment:"
    export QKD_CA_CERT_PATH="/home/dsobral/Repos/qkd-kem-bench/qkd_certs/account-${ACCOUNT_ID}-server-ca-qukaydee-com.crt"

    export MASTER_SAE_ID="sae-1"
    export SLAVE_SAE_ID="sae-2"

    export QKD_MASTER_KME_HOSTNAME="kme-1.acct-${ACCOUNT_ID}.etsi-qkd-api.qukaydee.com"
    export QKD_SLAVE_KME_HOSTNAME="kme-2.acct-${ACCOUNT_ID}.etsi-qkd-api.qukaydee.com"

    export QKD_MASTER_CERT_PATH="/home/dsobral/Repos/qkd-kem-bench/qkd_certs/sae-1.crt"
    export QKD_MASTER_KEY_PATH="/home/dsobral/Repos/qkd-kem-bench/qkd_certs/sae-1.key"

    export QKD_SLAVE_CERT_PATH="/home/dsobral/Repos/qkd-kem-bench/qkd_certs/sae-2.crt"
    export QKD_SLAVE_KEY_PATH="/home/dsobral/Repos/qkd-kem-bench/qkd_certs/sae-2.key"

elif [ "${QKD_BACKEND}" = "cerberis-xgr" ]; then
    log_info "Setting up Cerberis-XGR environment:"
    export QKD_CA_CERT_PATH="/home/dsobral/Repos/qkd-kem-bench/qkd_certs/ChrisCA.pem"

    export MASTER_SAE_ID="CONSA"
    export SLAVE_SAE_ID="CONSB"

    export QKD_MASTER_KME_HOSTNAME="castor.det.uvigo.es:444"
    export QKD_SLAVE_KME_HOSTNAME="castor.det.uvigo.es:442"

    export QKD_MASTER_CERT_PATH="/home/dsobral/Repos/qkd-kem-bench/qkd_certs/ETSIA.pem"
    export QKD_MASTER_KEY_PATH="/home/dsobral/Repos/qkd-kem-bench/qkd_certs/ETSIA-key.pem"

    export QKD_SLAVE_CERT_PATH="/home/dsobral/Repos/qkd-kem-bench/qkd_certs/ETSIB.pem"
    export QKD_SLAVE_KEY_PATH="/home/dsobral/Repos/qkd-kem-bench/qkd_certs/ETSIB-key.pem"
else
    log_error "Unknown QKD_BACKEND: ${QKD_BACKEND}"
    exit 1
fi

# Map certificate variables for curl calls
CACERT="${QKD_CA_CERT_PATH}"
MASTER_CERT="${QKD_MASTER_CERT_PATH}"
MASTER_KEY="${QKD_MASTER_KEY_PATH}"
SLAVE_CERT="${QKD_SLAVE_CERT_PATH}"
SLAVE_KEY="${QKD_SLAVE_KEY_PATH}"

# ------------------------------------------------------------------
# Main Script Execution
# ------------------------------------------------------------------

log_section "ETSI014 API Testing Script"

# Pre-flight checks
log_section "Pre-flight Checks"
log_info "Verifying required certificates and keys...\N"

check_file_exists "${CACERT}" "CA certificate"   || exit 1
check_file_exists "${MASTER_CERT}" "master certificate" || exit 1
check_file_exists "${MASTER_KEY}" "master key"      || exit 1
check_file_exists "${SLAVE_CERT}" "slave certificate"   || exit 1
check_file_exists "${SLAVE_KEY}" "slave key"        || exit 1

echo ""
log_success "All pre-flight checks passed"

# Execute API tests
if ! get_status; then
    log_error "Status check failed. Aborting further tests."
    exit 1
fi

# Get encryption keys
log_section "Retrieving Encryption Key"
log_info "Querying encryption keys for Slave SAE: ${SLAVE_SAE_ID}"
log_info "Using KME endpoint: ${QKD_MASTER_KME_HOSTNAME}"

key_id_output=$(get_enc_keys)
enc_keys_status=$?

if [ $enc_keys_status -ne 0 ]; then
    log_error "Failed to retrieve encryption keys. Aborting."
    exit 1
fi

log_success "Encryption key retrieved successfully"

# Extract just the last line which contains the key_ID
key_id=$(echo "$key_id_output" | tail -n 1)
if [[ -z "$key_id" || "$key_id" == "null" ]]; then
    log_error "Failed to extract valid encryption key ID. Aborting."
    exit 1
fi

# Get decryption key using the extracted key_ID
if ! get_dec_keys "$key_id"; then
    log_error "Failed to retrieve decryption key."
    exit 1
fi

log_section "Test Summary"
log_success "All API tests completed successfully\n"
