#!/bin/bash
# run_tls_bench.sh
# Benchmark TLS performance with various KEM and certificate combinations

set -e

# ------------------------------------------------------------------
# Source common utilities and environment
# ------------------------------------------------------------------
SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/common.sh"

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

# ------------------------------------------------------------------
# Main Script Setup
# ------------------------------------------------------------------

# Set default parameters
ITERATIONS=10
PROVIDER="oqs"
DELAY=0

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
    #"frodo640aes" "frodo640shake" "frodo976aes" "frodo976shake" "frodo1344aes" "frodo1344shake"
    #"hqc128" "hqc192" "hqc256"
)

CERTS=(
    "rsa_2048" "rsa_3072" "rsa_4096" 
    #"mldsa44" "mldsa65" "mldsa87" 
    #"falcon512" "falcon1024"
    # Optionally, add more certificates as needed.
)

log_section "TLS Benchmarking Script"
log_info "Provider: ${PROVIDER}"
log_info "Iterations per combination: ${ITERATIONS}"
if [ "$DELAY" -gt 0 ]; then
    log_info "Delay between combinations: ${DELAY} seconds"
fi
log_info "Results will be saved to: ${OUTPUT_FILE}\n"

failed_combinations=0

# Loop over each KEM and CERT combination
for kem in "${KEMS[@]}"; do
    for cert in "${CERTS[@]}"; do
        success=true
        combination="${PROVIDER}-${kem} x ${cert}"
        
        for i in $(seq 1 "$ITERATIONS"); do
            # Use fixed-width prefix (60 characters) for uniform progress bars.
            prefix=$(printf "%-60s" "Benchmarking ${combination}")
            show_progress "$i" "$ITERATIONS" "$prefix"
            result=$(python3 "${SCRIPT_DIR}/test_qkd_kem_tls.py" -k "$kem" -c "$cert" -p "$PROVIDER" | grep "Success")
            if [ -z "$result" ]; then
                success=false
                break
            fi
            time_val=$(echo "$result" | awk '{print $9}')
            echo "${PROVIDER},${kem},${cert},${i},${time_val}" >> "$OUTPUT_FILE"
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
        
        # If delay is specified and this is not the last combination, show a temporary pause message.
        kem_index=0
        cert_index=0
        for index in "${!KEMS[@]}"; do
            if [ "${KEMS[$index]}" = "$kem" ]; then
                kem_index=$index
                break
            fi
        done
        for index in "${!CERTS[@]}"; do
            if [ "${CERTS[$index]}" = "$cert" ]; then
                cert_index=$index
                break
            fi
        done
        last_kem_index=$((${#KEMS[@]} - 1))
        last_cert_index=$((${#CERTS[@]} - 1))
        
        if [ "$DELAY" -gt 0 ] && { [ "$kem_index" -ne "$last_kem_index" ] || [ "$cert_index" -ne "$last_cert_index" ]; }; then
            printf "Pausing for %s seconds..." "$DELAY"
            sleep "$DELAY"
            printf "\r\033[2K"
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
