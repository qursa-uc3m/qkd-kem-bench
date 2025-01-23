#!/bin/bash

GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'  # No Color
TICK="✓"
CROSS="✗"

# Validate and create benchmark directory if needed
BASE_DIR=$(pwd)
BENCH_DIR=${BASE_DIR}/benchmarks/data
mkdir -p "$BENCH_DIR"

# Parse arguments
ITERATIONS=10
PROVIDER="oqs"  # default value

while getopts "n:p:" opt; do
   case $opt in
       n) ITERATIONS="$OPTARG" ;;
       p) PROVIDER="$OPTARG" ;;
       *) echo "Usage: $0 [-n iterations] [-p provider (standard/qkd)]" >&2; exit 1 ;;
   esac
done

# Validate provider argument
if [[ "$PROVIDER" != "standard" && "$PROVIDER" != "qkd" ]]; then
   echo "Error: provider must be 'standard' or 'qkd'" >&2
   exit 1
fi

OUTPUT_FILE="${BENCH_DIR}/tls_bench_${PROVIDER}_${ITERATIONS}_iter_$(date +%Y%m%d).csv"
KEMS=("kyber768" "kyber1024")
CERTS=("rsa" "dilithium" "falcon")

echo "KEM,Cert,Iteration,Time" > "$OUTPUT_FILE"

progress_bar() {
   local combination=$1
   local current=$2
   local total=$3
   local percent=$((100 * current / total))
   
   if [ $current -eq 1 ]; then
       echo -e "\nBenchmarking $combination"
   fi
   
   printf "\r[%-50s] %3d%%" $(head -c $(($percent/2)) < /dev/zero | tr '\0' '=') $percent
}

for kem in "${KEMS[@]}"; do
   for cert in "${CERTS[@]}"; do
       success=true
       combination="$kem with $cert"
       
       for i in $(seq 1 $ITERATIONS); do
           progress_bar "$combination" $i $ITERATIONS
           result=$(python3 scripts/test_qkd_kem_tls.py -k "$kem" -c "$cert" | grep "Success")
           if [ -z "$result" ]; then
               success=false
               break
           fi
           echo "$kem,$cert,$i,$(echo $result | awk '{print $9}')" >> "$OUTPUT_FILE"
       done
       
       if $success; then
           echo -e "\n${GREEN}${TICK} Success${NC}"
       else
           echo -e "\n${RED}${CROSS} Failed${NC}"
       fi
   done
done

echo -e "\nResults saved to $OUTPUT_FILE"