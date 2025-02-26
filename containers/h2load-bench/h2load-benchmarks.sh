#!/bin/bash

# Default values
ip="127.0.0.1"
port="4433"
requests="50"
mode="oqs"  # Changed default to "oqs" from "no-qrng"

# Use getopts for command line arguments
while getopts "n:i:p:m:" opt; do  # Removed 'c:' since only one client is allowed
  case $opt in
    n) requests="$OPTARG" ;;
    i) ip="$OPTARG" ;;
    p) port="$OPTARG" ;;
    m) mode="$OPTARG" ;;
    *) echo 'Error in command line parsing' >&2
       exit 1
  esac
done

# Validate mode
if [[ "$mode" != "oqs" && "$mode" != "qkd-kem" ]]; then
  echo "Error: mode must be either 'oqs' or 'qkd-kem'" >&2
  exit 1
fi

# List of algorithms to test
kems=("mlkem512" "mlkem768" "mlkem1024" 
      "bikel1" 
      "hqc128" "hqc192" 
      "frodo640aes" "frodo640shake" "frodo976shake")

# Create QKD-KEM algorithms by adding 'qkd_' prefix to each KEM
qkdkems=()
for kem in "${kems[@]}"; do
  qkdkems+=("qkd_$kem")
done

# Set the output directory (two levels above)
output_base_dir="../../benchmarks/data"

for (( run=1; run<=50; run++ ))
do
    echo "Running iteration $run"

    output_dir="${output_base_dir}/${requests}_requests/${mode}/run_${run}"
    mkdir -p $output_dir
    output_raw_dir="${output_dir}/raw"
    mkdir -p $output_raw_dir

    # Select algorithm list based on mode
    if [[ "$mode" == "oqs" ]]; then
        algorithms=("${kems[@]}")
    else
        algorithms=("${qkdkems[@]}")
    fi

    # Convert array into a list separated by newline, shuffle it and convert it back to an array
    order_file="${output_base_dir}/${requests}_requests/${mode}/order_${run}.txt"
    mkdir -p "$(dirname "$order_file")"
    printf "%s\n" "${algorithms[@]}" | shuf > "$order_file"
    readarray -t shuffled_algorithms < "$order_file"

    # Loop through the shuffled algorithms and run the tests
    for algorithm in "${shuffled_algorithms[@]}"; do
        output_raw_file="${output_raw_dir}/${algorithm}.txt"
        processed_output_dir="${output_dir}/processed/${algorithm}"
        mkdir -p $processed_output_dir
        
        # Fixed client count to 1
        #docker run --rm --network=host --name h2load-bench -it h2load-bench h2load -n $requests -c 1 https://$ip:$port --groups $algorithm > $output_raw_file
        docker run --rm --network=containers_default --name h2load containers_h2load-bench -n $requests -c 1 https://$ip:$port --groups $algorithm > $output_raw_file
        
        # Parse the results and save them in a separate file
        python3 benchmark_results_parser.py --file $output_raw_file --output $processed_output_dir
        
        echo -e "Test completed for algorithm $algorithm with 1 client and $requests requests."
        
        # Introduce a delay between tests to avoid overloading the server
        sleep 5
    done
    sleep 1
done