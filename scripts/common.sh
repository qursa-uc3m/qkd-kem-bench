#!/bin/bash

# =======================
# Color and Symbol Definitions
# =======================
readonly GREEN='\033[1;32m'
readonly RED='\033[1;31m'
readonly BLUE='\033[1;34m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[1;36m'
readonly NC='\033[0m'  # No Color

readonly SUCCESS="✅"
readonly ERROR="❌"
readonly INFO="ℹ️"
readonly WARN="⚠️"
readonly TICK="✓"
readonly CROSS="✗"

# =======================
# Logging Functions
# =======================

log_info() {
    echo -e "${BLUE}${INFO}  $1${NC}"
}

log_success() {
    echo -e "${GREEN}${SUCCESS} $1${NC}"
}

log_error() {
    echo -e "${RED}${ERROR} $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}${WARN} $1${NC}"
}

log_section() {
    echo -e "\n${CYAN}=== $1 ===${NC}\n"
}

# Messages with NO icons
msg_info() {
    echo -e "${BLUE}$1${NC}"
}

msg_success() {
    echo -e "${GREEN}$1${NC}"
}
msg_error() {
    echo -e "${RED}$1${NC}" >&2
}

# =======================
# Progress Bar Functions
# =======================

# Show progress bar for a single operation
show_progress() {
    local current="$1"
    local total="$2"
    local prefix="$3"
    local is_complete="${4:-0}"  # Optional: 0=in-progress, 1=success, 2=failure
    
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\r%s [%s%s] %3d%%" \
        "$prefix" \
        "$(printf "%${completed}s" | tr ' ' '=')" \
        "$(printf "%${remaining}s" | tr ' ' ' ')" \
        "$percentage"
}

# Show hierarchical progress for nested operations
show_nested_progress() {
    local current_main=$1
    local total_main=$2
    local current_sub=$3
    local total_sub=$4
    local main_desc=$5
    local sub_desc=$6
    
    # Clear previous lines
    printf "\033[2K"  # Clear current line
    
    # Main progress
    printf "\r%s: [%-20s] %3d%%" \
        "$main_desc" \
        "$(printf "%${main_percent}s" | tr ' ' '#')" \
        "$((current_main * 100 / total_main))"
    
    # Sub-progress
    printf "\n%s: [%-50s] %3d%%" \
        "$sub_desc" \
        "$(printf "%${sub_percent}s" | tr ' ' '=')" \
        "$((current_sub * 100 / total_sub))"
    
    printf "\033[1A"  # Move cursor up one line
}

# =======================
# File and Path Functions
# =======================

ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || {
            log_error "Failed to create directory: $dir"
            return 1
        }
        log_success "Created directory: $dir"
    fi
    return 0
}

check_file() {
    local file="$1"
    local desc="$2"
    
    if [ ! -f "$file" ]; then
        log_error "Required ${desc} not found: $file"
        return 1
    elif [ ! -r "$file" ]; then
        log_error "Required ${desc} not readable: $file"
        return 1
    fi
    return 0
}

get_script_dir() {
    local source=${BASH_SOURCE[0]}
    while [ -L "$source" ]; do
        local dir=$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )
        source=$(readlink "$source")
        [[ $source != /* ]] && source=$dir/$source
    done
    echo $( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )
}

# Pretty–print JSON using jq
log_json() {
    # If no color (i.e. -C) is desired in jq output you can remove the -C flag.
    echo "$1" | jq -C '.'
}

# Check if a file exists and is readable.
# Uses common.sh's check_file; if successful, log a success message.
check_file_exists() {
    local file="$1"
    local desc="$2"

    if check_file "$file" "$desc"; then
        log_success "Found ${desc}: $file"
        return 0
    fi
    return 1
}

# =======================
# Validation Functions
# =======================

is_positive_integer() {
    local value="$1"
    if [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 0 ]; then
        return 0
    fi
    return 1
}

is_valid_option() {
    local value="$1"
    shift
    local valid_options=("$@")
    
    for option in "${valid_options[@]}"; do
        if [ "$value" = "$option" ]; then
            return 0
        fi
    done
    return 1
}

# =======================
# OpenSSL Environment Functions
# =======================

setup_openssl_env() {
    local base_dir="$1"
    
    export OPENSSL_APP=openssl
    export OPENSSL_MODULES="${base_dir}/_build/lib"
    export OPENSSL_CONF="${base_dir}/scripts/openssl-ca.cnf"

    # Set up library paths
    if [ -d "${base_dir}/.local/lib64" ]; then
        export LD_LIBRARY_PATH="${base_dir}/.local/lib64"
    elif [ -d "${base_dir}/.local/lib" ]; then
        export LD_LIBRARY_PATH="${base_dir}/.local/lib"
    else
        log_error "Neither lib64 nor lib directory found in .local/"
        return 1
    fi

    # Set OSX specific library path if needed
    if [ -z "${DYLD_LIBRARY_PATH}" ]; then
        export DYLD_LIBRARY_PATH="${LD_LIBRARY_PATH}"
    fi

    return 0
}

check_openssl_providers() {
    local modules_dir="$1"
    declare -A provider_files=(
        ["qkdkemprovider"]="qkdkemprovider.so"
        ["oqs"]="oqsprovider.so"
    )
    local missing_providers=()
    local has_error=0

    log_info "Checking OpenSSL providers..."
    for provs in "${!provider_files[@]}"; do
        printf "  %-20s: " "${provider_files[$provs]}"
        if [ -f "${modules_dir}/${provider_files[$provs]}" ]; then
            if [ -r "${modules_dir}/${provider_files[$provs]}" ]; then
                log_success "Found and readable"
            else
                log_error "Found but not readable"
                has_error=1
            fi
        else
            log_error "Not found"
            missing_providers+=("$provs")
            has_error=1
        fi
    done

    if [ $has_error -eq 1 ]; then
        if [ ${#missing_providers[@]} -gt 0 ]; then
            log_error "Missing providers: ${missing_providers[*]}"
        fi
        return 1
    fi
    return 0
}

# =======================
# Cleanup Functions
# =======================

cleanup_temp_files() {
    local pattern="$1"
    find /tmp -name "$pattern" -type f -mtime +1 -delete 2>/dev/null || true
}

trap_cleanup() {
    local trapped_signal="$1"
    echo -e "\n${RED}Caught signal ${trapped_signal}${NC}"
    cleanup_temp_files "benchmark_*"
    exit 1
}

# Set up trap for cleanup
trap 'trap_cleanup INT' INT
trap 'trap_cleanup TERM' TERM