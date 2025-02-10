#!/usr/bin/env bash

###############################################################################
# This script tests a TLS 1.3 handshake using a QKD-based KEM provider.
#
# It:
#  - Sets environment variables (like QKD_BACKEND) for the KEM.
#  - Checks for necessary dependencies.
#  - Starts a packet capture on localhost:4433.
#  - Launches an OpenSSL server with a QKD KEM.
#  - Launches an OpenSSL client that attempts a TLS handshake.
#  - Kills everything and logs results.
#
# USAGE: ./improved_tls_test_script.sh
###############################################################################

# --- Logging Functions ---
log_info() {
    printf "%-80s\r\n" "[INFO] $1"
    #printf "\n"
}

log_debug() {
    printf "%-80s\r\n" "[DEBUG] $1"
    #printf "\n"
}

log_error() {
    printf "%-80s\r\n" "[ERROR] $1" >&2
    #printf "\n"
}

log_success() {
    printf "%-80s\r\n" "[SUCCESS] $1"
    #printf "\n"
}

log_warning() {
    printf "%-80s\r\n" "[WARNING] $1" >&2
    #printf "\n"
}

# --- CONFIGURATION ---
QKD_BACKEND="qukaydee"
ACCOUNT_ID="2507"
PORT=4433
INTERFACE="lo"
CERTS_DIR="$(pwd)/certs/rsa"
LOGS_DIR="$(pwd)/logs"

# Export required variables
export QKD_BACKEND ACCOUNT_ID

# Create logs directory with explicit permissions
sudo mkdir -p "$LOGS_DIR"
sudo chown $USER:$USER "$LOGS_DIR"
sudo chmod 755 "$LOGS_DIR"

# Set all log file paths and initialize them with proper permissions
TEMP_CAPTURE="/tmp/tls_capture.pcap"
FINAL_CAPTURE="$LOGS_DIR/tls_capture.pcap"
SERVER_LOG="$LOGS_DIR/server_log.txt"
CLIENT_LOG="$LOGS_DIR/client_log.txt"
CAPTURE_STRINGS="$LOGS_DIR/tls_capture_strings.txt"
PUBLIC_KEY_HEX="$LOGS_DIR/public_key_hex.txt"

# Initialize all log files with proper permissions
for logfile in "$SERVER_LOG" "$CLIENT_LOG" "$CAPTURE_STRINGS" "$PUBLIC_KEY_HEX"; do
    sudo touch "$logfile"
    sudo chown $USER:$USER "$logfile"
    sudo chmod 666 "$logfile"
done

# Source QKD environment
source "./scripts/oqs_env.sh"
echo

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    pkill -f "openssl s_server.*$PORT" 2>/dev/null || true
    if sudo pkill -f "tshark.*$PORT" 2>/dev/null; then
        sleep 1  # Give tshark time to flush its buffer
        # Move capture file to final location
        if [ -f "$TEMP_CAPTURE" ]; then
            sudo mv "$TEMP_CAPTURE" "$FINAL_CAPTURE"
            sudo chown $USER:$USER "$FINAL_CAPTURE"
            sudo chmod 644 "$FINAL_CAPTURE"
        fi
    fi
    rm -f /tmp/openssl* 2>/dev/null || true
    printf "\n"
    exit 0
}

# Check dependencies
for cmd in openssl tshark; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd not found. Please install it."
        exit 1
    fi
done

# Request sudo privileges upfront
log_info "Requesting sudo privileges for packet capture..."
sudo -v

# Verify interface exists
if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
    log_error "Interface $INTERFACE does not exist"
    exit 1
fi

# Start packet capture with temporary file
log_info "Starting packet capture..."
stdbuf -oL sudo tshark -i "$INTERFACE" -w "$TEMP_CAPTURE" -f "tcp port $PORT" >/dev/null 2>&1 &
TSHARK_PID=$!

# Verify capture started
sleep 2
log_debug "TShark PID: $TSHARK_PID"
if ! ps -p $TSHARK_PID > /dev/null 2>&1; then
    log_error "Failed to start tshark"
    exit 1
fi

# Start server
log_info "Starting OpenSSL server on port $PORT..."
(
    export IS_TLS_SERVER=1
    stdbuf -oL openssl s_server \
    -cert "${CERTS_DIR}/rsa_2048_entity_cert.pem" \
    -key "${CERTS_DIR}/rsa_2048_entity_key.pem" \
    -www \
    -tls1_3 \
    -groups qkd_mlkem512 \
    -port $PORT \
    -provider default \
    -provider qkdkemprovider \
    >> "$SERVER_LOG" 2>&1
) &

sleep 2

# Run client and capture output
log_info "Running client..."
CLIENT_OUTPUT=$(timeout 10s openssl s_client \
    -CAfile "${CERTS_DIR}/rsa_2048_root_cert.pem" \
    -connect localhost:$PORT \
    -groups qkd_mlkem512 \
    -provider default \
    -provider qkdkemprovider \
    2>&1)

# Save client output to log
echo "$CLIENT_OUTPUT" > "$CLIENT_LOG"

# Verify capture file
if [ -f "$FINAL_CAPTURE" ]; then
    log_info "Capture file created: $(ls -l "$FINAL_CAPTURE")"
else
    log_error "No capture file generated"
fi

# Check log files
for logfile in "$SERVER_LOG" "$CLIENT_LOG" "$FINAL_CAPTURE"; do
    if [ -s "$logfile" ]; then
        log_info "Successfully created and wrote to: $(basename "$logfile")"
        log_debug "File size: $(ls -lh "$logfile" | awk '{print $5}')"
    else
        log_warning "File empty or not created: $(basename "$logfile")"
    fi
done

# Check handshake success
if echo "$CLIENT_OUTPUT" | grep -q "Verify return code: 0 (ok)"; then
    log_success "TLS handshake completed successfully"
else
    log_error "TLS handshake failed"
fi

###############################################################################
# Parse ephemeral public key from the capture
###############################################################################

# Convert pcap to readable format
tshark -r "$FINAL_CAPTURE" -V > "$CAPTURE_STRINGS"

# Search for public key data
log_debug "Searching for 'public key', 'key share', or 'server key' in $CAPTURE_STRINGS"
{
    grep -i -A 15 "public key" "$CAPTURE_STRINGS" || true
    grep -i -A 15 "key share" "$CAPTURE_STRINGS" || true
    grep -i -A 15 "server key" "$CAPTURE_STRINGS" || true
} > "$PUBLIC_KEY_HEX"

log_info "Potential ephemeral key data saved to: $PUBLIC_KEY_HEX"
log_info "TLS handshake test complete."
log_info "Test complete. Logs are in: $LOGS_DIR"

trap cleanup SIGINT SIGTERM EXIT