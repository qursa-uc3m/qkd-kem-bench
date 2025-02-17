#!/bin/bash
# run_tls_bench.sh
# Benchmark TLS performance with various KEM and certificate combinations

# set -e

# ------------------------------------------------------------------
# Source common utilities and environment
# ------------------------------------------------------------------
SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/oqs_env.sh"
echo ""

# ------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------
usage() {
    log_info "Usage: $0 [OPTIONS]"
    msg_info "Run TLS benchmarks using test_qkd_kem_tls.py"
    msg_info ""
    msg_info "Options:"
    msg_info "  -i, --iterations N    Number of iterations per combination (default: 10)"
    msg_info "  -p, --provider P      Provider to use (qkd or oqs) [default: oqs]"
    msg_info "  -d, --delay D         Delay between combinations in seconds (default: 0)"
    msg_info "  -h, --help            Show this help message"
    msg_info ""
    msg_info "Example: $0 --iterations 100 --provider qkd"
    exit 1
}

check_key_status() {
    local response
    local stored_keys
    
    response=$(curl -Ss --silent --show-error -i \
        --cacert "${QKD_MASTER_CA_CERT_PATH}" \
        --cert "${QKD_MASTER_CERT_PATH}" \
        --key "${QKD_MASTER_KEY_PATH}" \
        --header "Accept: application/json" \
        -k "${QKD_MASTER_KME_HOSTNAME}/api/v1/keys/${QKD_SLAVE_SAE}/status")
    
    local http_code=$(echo "$response" | grep HTTP | awk '{print $2}')
    
    if [[ "$http_code" -eq 200 ]]; then
        stored_keys=$(echo "$response" | sed -n '/^\r$/,$p' | tail -n +2 | jq -r '.stored_key_count')
        
        if [[ $stored_keys -lt 100 ]]; then
            msg_info "Low key count detected (${stored_keys}). Waiting ${DELAY}s for replenishment..."
            sleep $DELAY
            return 1
        fi
        msg_info "Current key count: ${stored_keys}\n"
        return 0
    else
        msg_error "Failed to check key status (HTTP ${http_code})"
        return 2
    fi
}

# ------------------------------------------------------------------
# Main Script Setup
# ------------------------------------------------------------------

# Set default parameters
ITERATIONS=10
PROVIDER="oqs"
DELAY=0

# Key Check Parameters
KEYS_CHECK_INTERVAL=100 # Check every 100 iterations
total_iterations=0

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--iterations)
            shift
            if [[ $# -gt 0 && $1 =~ ^[0-9]+$ ]]; then
                ITERATIONS=$1
                shift
            else
                log_error "Error: --iterations requires a non-negative integer"
                usage
            fi
            ;;
        -p|--provider)
            shift
            if [[ $# -gt 0 ]]; then
                PROVIDER=$1
                shift
            else
                log_error "Error: --provider requires a provider name (qkd or oqs)"
                usage
            fi
            ;;
        -d|--delay)
            shift
            if [[ $# -gt 0 && $1 =~ ^[0-9]+$ ]]; then
                DELAY=$1
                shift
            else
                log_error "Error: --delay requires a non-negative integer"
                usage
            fi
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

BASE_DIR=$(pwd)
BENCH_DIR="${BASE_DIR}/benchmarks/data"
ensure_dir "$BENCH_DIR"

if [ "$ITERATIONS" -eq 0 ]; then
        usage
fi

# Setup OpenSSL environment using common.sh function
if ! setup_openssl_env "$BASE_DIR"; then
    log_error "OpenSSL environment setup failed"
    exit 1
fi

# Check OpenSSL providers using common.sh function
if ! check_openssl_providers "${OPENSSL_MODULES}"; then
    log_error "Provider check failed"
    exit 1
fi

if [[ "$PROVIDER" != "oqs" && "$PROVIDER" != "qkd" ]]; then
    log_error "Error: provider must be 'oqs' or 'qkd'"
    usage
fi


OUTPUT_FILE="${BENCH_DIR}/tls_bench_${PROVIDER}_${ITERATIONS}_iter_$(date +%Y%m%d).csv"
echo "KEM,Cert,Iteration,Time" > "$OUTPUT_FILE"

# Define KEM and CERT arrays
KEMS=(
    "mlkem512" "mlkem768" "mlkem1024" 
    "bikel1" "bikel3" "bikel5" 
    "frodo640aes" "frodo640shake" "frodo976aes" "frodo976shake" "frodo1344aes" "frodo1344shake"
    "hqc128" "hqc192" "hqc256"
)

CERTS=(
    "rsa_2048" "rsa_3072" "rsa_4096" 
    "mldsa44" "mldsa65" "mldsa87" 
    "falcon512" "falcon1024"
    # Optionally, add more certificates as needed.
    # 'sphincssha2128fsimple', 'sphincssha2128ssimple', 'sphincssha2192fsimple'
    # 'sphincsshake128fsimple'
)

log_section "TLS Benchmarking Script"
log_info "Provider: ${PROVIDER}"
log_info "Iterations per combination: ${ITERATIONS}"
if [[ "$PROVIDER" == "qkd" ]]; then
    log_info "Key replenishment wait time: ${DELAY} seconds"
fi
log_info "Results will be saved to: ${OUTPUT_FILE}\n"

failed_combinations=0

# Loop over each KEM and CERT combination
for kem in "${KEMS[@]}"; do
    for cert in "${CERTS[@]}"; do
        success=true
        combination="${PROVIDER}-${kem} x ${cert}"
        
        for i in $(seq 1 "$ITERATIONS"); do
            # Only check keys for QKD provider
            if [[ "$PROVIDER" == "qkd" && $((total_iterations % KEYS_CHECK_INTERVAL)) -eq 0 ]]; then
                echo ""
                msg_info "Checking key availability at iteration ${total_iterations}..."
                check_key_status
                echo ""
            fi
            
            prefix=$(printf "%-50s" "Benchmarking ${combination}")
            show_progress "$i" "$ITERATIONS" "$prefix"
            result=$(python3 "${SCRIPT_DIR}/test_qkd_kem_tls.py" -k "$kem" -c "$cert" -p "$PROVIDER" | grep "Success")
            
            if [ -z "$result" ]; then
                success=false
                break
            fi
            
            time_val=$(echo "$result" | awk '{print $9}')
            echo "${PROVIDER},${kem},${cert},${i},${time_val}" >> "$OUTPUT_FILE"
            
            ((total_iterations++))
        done
        
        # End the progress bar line.
        printf "\n"
        
        if $success; then
            msg_success "  Benchmark completed: ${combination}"
        else
            msg_error "  Benchmark failed: ${combination}"
        fi

        if ! $success; then
            ((failed_combinations++))
        fi
    done
done

# Compute total_combinations as number of KEMS * number of CERTS
total_combinations=$(( ${#KEMS[@]} * ${#CERTS[@]} ))

echo ""
log_section "Benchmark Summary"
echo -e "Total KEM algorithms tested: ${#KEMS[@]}"
echo -e "Total Certificate algorithms tested: ${#CERTS[@]}"
echo -e "Total combinations tested: ${total_combinations}"
echo -e "Combinations with failed benchmarks: ${failed_combinations}"
echo -e "Results saved to: ${OUTPUT_FILE}"
echo ""
if [ "$failed_combinations" -eq 0 ]; then
    msg_success "Test passed"
else
    msg_error "Some combinations failed"
fi
log_success "TLS benchmarks completed"
