#!/bin/bash

BASE_DIR="$(pwd)"

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Run OQS KEM benchmarks"
    echo ""
    echo "Options:"
    echo "  -b, --bench N    Run benchmarks with N iterations"
    echo "  -p, --provider P Choose provider (qkdkem or oqs)"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "Example: $0 --bench 1000"
}

# Set up environment variables
setup_environment() {
    export OPENSSL_APP=openssl
    export OPENSSL_MODULES="${BASE_DIR}/_build/lib"
    export OPENSSL_CONF="${BASE_DIR}/test/openssl-ca.cnf"

    # Set up library paths
    if [ -d "${BASE_DIR}/.local/lib64" ]; then
        export LD_LIBRARY_PATH="${BASE_DIR}/.local/lib64"
    elif [ -d "${BASE_DIR}/.local/lib" ]; then
        export LD_LIBRARY_PATH="${BASE_DIR}/.local/lib"
    fi

    # Set OSX specific library path if needed
    if [ -z "${DYLD_LIBRARY_PATH}" ]; then
        export DYLD_LIBRARY_PATH="${LD_LIBRARY_PATH}"
    fi
}

# Run KEM benchmarks
run_kem_bench() {
    local iterations=$1
    local provider=$2

    case $provider in 
        qkdkem)
            echo "Running QKD KEM benchmarks with $iterations iterations..."
            ;;
        oqs)
            echo "Running OQS KEM benchmarks with $iterations iterations..."
            ;;
        *)
            echo "❌ Invalid provider: $provider"
            echo "Valid options are: qkdkem, oqs"
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
    local provider="qkdkem" # Default provider

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
                    echo "Error: --provider requires a provider name (qkdkem or oqs)"
                    show_help
                    exit 1
                fi
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

    # Run benchmarks
    run_kem_bench $bench_iterations
    exit $?
}

# Execute main with all arguments
main "$@"