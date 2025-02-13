#!/bin/bash
# run_qkd_kem_bench.sh
#
# Benchmark QKD KEM performance by running the benchmark binary for a given
# number of iterations. The provider can be "qkd" or "oqs" and an optional delay
# (in seconds) can be specified between iterations.
#
# Usage: $0 [OPTIONS]
#   -i, --iterations N    Run benchmarks with N iterations
#   -p, --provider P      Choose provider (qkd or oqs) [default: qkd]
#   -d, --delay D         Delay between iterations in seconds [default: 0]
#   -h, --help            Show this help message

set -e

# ------------------------------------------------------------------
# Source common utilities
# ------------------------------------------------------------------
SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/common.sh"

BASE_DIR="$(pwd)"

# ------------------------------------------------------------------
# Usage function
# ------------------------------------------------------------------
usage() {
    log_info "Usage: $0 [OPTIONS]"
    msg_info "Run QKD KEM benchmarks"
    msg_info ""
    msg_info "Options:"
    msg_info "  -i, --iterations N    Run benchmarks with N iterations"
    msg_info "  -p, --provider P      Choose provider (qkd or oqs)"
    msg_info "  -d, --delay D         Delay between iterations in seconds"
    msg_info "  -h, --help            Show this help message"
    msg_info ""
    msg_info "Example: $0 --iterations 1000 --provider qkd"
    exit 1
}

# ------------------------------------------------------------------
# run_kem_bench function
# ------------------------------------------------------------------
run_kem_bench() {
    local iterations=$1
    local provider=$2
    local delay=$3

    case $provider in 
        qkd)
            log_info "Running QKD KEM benchmarks with ${iterations} iterations..."
            ;;
        oqs)
            log_info "Running OQS KEM benchmarks with ${iterations} iterations..."
            ;;
        *)
            log_error "Invalid provider: ${provider}. Valid options are: qkd, oqs"
            return 1
            ;;
    esac
    
    local bench_bin="${BASE_DIR}/_build/bin/oqs_bench_kems"
    if ! check_file "$bench_bin" "Benchmark binary"; then
        return 1
    fi

    if [[ "$provider" == qkd ]]; then
        log_info "Using QKD provider"
        provider_name=qkdkemprovider
    else
        log_info "Using OQS provider"
        provider_name="$provider"
    fi

    pushd "${BASE_DIR}/_build/bin" > /dev/null
    log_info "Running benchmark binary from $(pwd)"
    ./oqs_bench_kems "$provider_name" "${OPENSSL_CONF}" "$iterations" "$delay"
    local result=$?
    popd > /dev/null

    if [ $result -eq 0 ]; then
        log_success "KEM benchmarks completed"
    else
        log_error "KEM benchmarks failed with return code: $result"
    fi

    return $result
}

# ------------------------------------------------------------------
# Main function
# ------------------------------------------------------------------
main() {
    local bench_iterations=0
    local provider="qkd"   # default provider is "qkd"
    local delay_seconds=0

    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--iterations)
                shift
                if [[ $# -gt 0 && $1 =~ ^[0-9]+$ ]]; then
                    bench_iterations=$1
                    shift
                else
                    log_error "Error: --iterations requires a non-negative integer"
                    usage
                fi
                ;;
            -p|--provider)
                shift
                if [[ $# -gt 0 ]]; then
                    provider=$1
                    shift
                else
                    log_error "Error: --provider requires a provider name (qkd or oqs)"
                    usage
                fi
                ;;
            -d|--delay)
                shift
                if [[ $# -gt 0 && $1 =~ ^[0-9]+$ ]]; then
                    delay_seconds=$1
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

    if [ "$bench_iterations" -eq 0 ]; then
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

    if [[ "$provider" != "oqs" && "$provider" != "qkd" ]]; then
        log_error "Error: provider must be 'oqs' or 'qkd'"
        usage
    fi

    run_kem_bench "$bench_iterations" "$provider" "$delay_seconds"
    exit $?
}

# Execute main with all provided arguments
main "$@"
