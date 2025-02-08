#!/bin/bash

BASE_DIR="$(pwd)"

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Run OQS KEM benchmarks"
    echo ""
    echo "Options:"
    echo "  -b, --bench N    Run benchmarks with N iterations"
    echo "  -p, --provider P Choose provider (qkdkemprovider or oqs)"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "Example: $0 --bench 1000"
}

# Set up environment variables
setup_environment() {
    export OPENSSL_APP=openssl
    export OPENSSL_MODULES="${BASE_DIR}/_build/lib"
    export OPENSSL_CONF="${BASE_DIR}/scripts/openssl-ca.cnf"

    # Set up library paths
    if [ -d "${BASE_DIR}/.local/lib64" ]; then
        export LD_LIBRARY_PATH="${BASE_DIR}/.local/lib64"
    elif [ -d "${BASE_DIR}/.local/lib" ]; then
        export LD_LIBRARY_PATH="${BASE_DIR}/.local/lib"
    else
        echo "❌ Neither lib64 nor lib directory found in .local/"
        return 1
    fi

    # Set OSX specific library path if needed
    if [ -z "${DYLD_LIBRARY_PATH}" ]; then
        export DYLD_LIBRARY_PATH="${LD_LIBRARY_PATH}"
    fi

    return 0
}

# Check if OpenSSL providers are available
check_providers() {
    # Map provider names to their corresponding .so files
    declare -A provider_files=(
        ["qkdkemprovider"]="qkdkemprovider.so"
        ["oqs"]="oqsprovider.so"
    )
    local missing_providers=()
    local has_error=0

    echo "Checking OpenSSL providers..."
    echo "Provider modules status:"
    for provs in "${!provider_files[@]}"; do
        printf "  %-20s: " "${provider_files[$provs]}"
        if [ -f "${OPENSSL_MODULES}/${provider_files[$provs]}" ]; then
            if [ -r "${OPENSSL_MODULES}/${provider_files[$provs]}" ]; then
                echo "✅ Found and readable"
            else
                echo "❌ Found but not readable"
                has_error=1
            fi
        else
            echo "❌ Not found"
            missing_providers+=("$provs")
            has_error=1
        fi
    done

    # Final status check
    if [ $has_error -eq 1 ]; then
        echo "❌ Provider check failed:"
        if [ ${#missing_providers[@]} -gt 0 ]; then
            echo "   Missing providers: ${missing_providers[*]}"
        fi
        return 1
    else
        echo "✅ All providers found and accessible"
        return 0
    fi
}

# Run KEM benchmarks
run_kem_bench() {
    local iterations=$1
    local provider=$2

    case $provider in 
        qkdkemprovider)
            echo "Running QKD KEM benchmarks with $iterations iterations..."
            ;;
        oqs)
            echo "Running OQS KEM benchmarks with $iterations iterations..."
            ;;
        *)
            echo "❌ Invalid provider: $provider"
            echo "Valid options are: qkdkemprovider, oqs"
            return 1
            ;;
    esac
    
    if [ ! -f "_build/bin/oqs_bench_kems" ]; then
        echo "❌ Benchmark binary not found"
        return 1
    fi

    cd _build/bin
    echo "Running from directory: $(pwd)"

    ./oqs_bench_kems "$provider" "${OPENSSL_CONF}" "$iterations" 
    local result=$?
    
    cd "${BASE_DIR}"
    
    if [ $result -eq 0 ]; then
        echo "✅ KEM benchmarks completed"
    else
        echo "❌ KEM benchmarks failed"
        echo "Return code: $result"
    fi
    
    return $result
}

main() {
    local bench_iterations=0
    local provider="qkdkemprovider" # Default provider

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--bench)
                shift
                if [[ $# -gt 0 && $1 =~ ^[0-9]+$ ]]; then
                    bench_iterations=$1
                    shift
                else
                    echo "Error: --bench requires a number of iterations"
                    show_help
                    exit 1
                fi
                ;;
            -p|--provider)
                shift
                if [[ $# -gt 0 ]]; then
                    provider=$1
                    shift
                else
                    echo "Error: --provider requires a provider name (qkdkemprovider or oqs)"
                    show_help
                    exit 1
                fi
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # If no iterations specified, show help
    if [ $bench_iterations -eq 0 ]; then
        show_help
        exit 1
    fi

    # Setup environment
    setup_environment

    # Providers check
    if ! check_providers; then
        echo "Fatal: Provider check failed"
        exit 1
    fi


    # Run benchmarks
    run_kem_bench $bench_iterations $provider
    exit $?
}

# Execute main with all arguments
main "$@"