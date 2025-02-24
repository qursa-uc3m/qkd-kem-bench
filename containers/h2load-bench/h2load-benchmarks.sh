#!/bin/bash

# Default values
ip="127.0.0.1"
port="4433"
clients="10"
requests="100"
mode="no-qrng"

# Use getopts for command line arguments
while getopts "c:n:i:p:m:" opt; do
  case $opt in
    c) clients="$OPTARG" ;;
    n) requests="$OPTARG" ;;
    i) ip="$OPTARG" ;;
    p) port="$OPTARG" ;;
    m) mode="$OPTARG" ;;
    *) echo 'Error in command line parsing' >&2
       exit 1
  esac
done

# List of algorithms to test
kems=("P-256" "P-384" "P-521" "X448" "X25519")
pqkems=("kyber512" "kyber768" "kyber1024")
hybrid_kems=("p256_kyber512" "p384_kyber768" "p521_kyber1024")

for (( run=1; run<=100; run++ ))
do
    echo "Running iteration $run"

    output_dir="./results/${clients}_clients_${requests}_requests/${mode}/run_${run}"
    mkdir -p $output_dir
    output_raw_dir="${output_dir}/raw"
    mkdir -p $output_raw_dir

    # Convert array into a list separated by newline, shuffle it and convert it back to an array
    combined_algorithms=("${kems[@]}" "${pqkems[@]}" "${hybrid_kems[@]}")
    order_file="./results/${clients}_clients_${requests}_requests/${mode}/order_${run}.txt"
    printf "%s\n" "${combined_algorithms[@]}" | shuf > "$order_file"
    readarray -t shuffled_algorithms < "$order_file"

    # Loop through the shuffled algorithms and run the tests
    for algorithm in "${shuffled_algorithms[@]}"; do
        output_raw_file="${output_raw_dir}/${algorithm}.txt"
        processed_output_dir="${output_dir}/processed/${algorithm}"
        mkdir -p $processed_output_dir
        docker run --rm --network=host --name h2load -it h2load h2load -n $requests -c $clients https://$ip:$port --groups $algorithm > $output_raw_file
        # Parse the results and save them in a separate file
        python3 benchmark_results_parser.py --file $output_raw_file --output $processed_output_dir
        echo "Test completed for algorithm $algorithm with $clients clients and $requests requests."
        # Introduce a delay between tests to avoid overloading the server
        sleep 20
    done
    sleep 1
done