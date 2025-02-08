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

# --- CONFIGURATION ---

QKD_BACKEND="qukaydee"
export QKD_BACKEND

ACCOUNT_ID="2507"
export ACCOUNT_ID

# Source your environment for the QKD KEM
source "./scripts/oqs_env.sh"

# Where are the RSA certificates stored?
CERTS_DIR="$(pwd)/certs/rsa"

# Logs directory
LOGS_DIR="$(pwd)/logs"
mkdir -p "$LOGS_DIR"

# Our logs
SERVER_LOG="$LOGS_DIR/server_log.txt"
CLIENT_LOG="$LOGS_DIR/client_log.txt"
CAPTURE_FILE="$LOGS_DIR/tls_capture.txt"
CAPTURE_STRINGS="$LOGS_DIR/tls_capture_strings.txt"
PUBLIC_KEY_HEX="$LOGS_DIR/public_key_hex.txt"

# Required ports
PORT=4433
INTERFACE="lo"  # Use 'lo' for localhost captures

###############################################################################
# Helper functions
###############################################################################

function check_dependency() {
  local dep="$1"
  echo "[DEBUG] Checking dependency: $dep"
  if ! command -v "$dep" &> /dev/null; then
      echo "[WARNING] The command '$dep' is not found on your system."
      echo "Please install '$dep' (e.g., using your package manager)."
  else
      echo "[DEBUG] Found dependency: $dep"
  fi
}

# We'll define a cleanup function to handle termination.
# This ensures we always kill background processes and remove leftover states.
function cleanup {
    echo "[DEBUG] Cleanup function triggered."

    # Kill the background processes (server & tshark)
    echo "[DEBUG] Attempting to kill all background jobs..."
    jobs -p | xargs -r kill -9 2>/dev/null || true

    # Alternatively, we can kill with stored PIDs if we track them globally.
    # kill -9 $TSHARK_PID $SERVER_PID 2>/dev/null || true

    # Attempt to free the port. This might require sudo.
    # We'll try without sudo first, or detect if we must.
    if command -v fuser &>/dev/null; then
        echo "[DEBUG] Attempting to free port $PORT via fuser..."
        fuser -k ${PORT}/tcp 2>/dev/null || true
    fi

    echo "[DEBUG] Cleanup function completed."
}

# We bind the EXIT signal to call our cleanup no matter how we exit.
trap cleanup EXIT

###############################################################################
# Check dependencies
###############################################################################
check_dependency openssl
check_dependency tshark

###############################################################################
# Start the packet capture in the background
###############################################################################
echo "[INFO] Starting packet capture with tshark on interface '$INTERFACE' (port $PORT)."
(
  # Run tshark with line-buffered output. We'll use sudo here but not for the entire script.
  sudo tshark -i "$INTERFACE" -Y "tcp.port == $PORT" -V -l -s 0 > "$CAPTURE_FILE" 2>/dev/null
) &
TSHARK_PID=$!

echo "[DEBUG] tshark started with PID: $TSHARK_PID"

###############################################################################
# Prepare environment for the OpenSSL server
###############################################################################

echo "[INFO] Starting OpenSSL server on port $PORT..."

echo "[DEBUG] Using cert: ${CERTS_DIR}/rsa_2048_entity_cert.pem"
echo "[DEBUG] Using key:  ${CERTS_DIR}/rsa_2048_entity_key.pem"

(
  export IS_TLS_SERVER=1
  openssl s_server \
    -cert "${CERTS_DIR}/rsa_2048_entity_cert.pem" \
    -key  "${CERTS_DIR}/rsa_2048_entity_key.pem" \
    -www \
    -tls1_3 \
    -groups qkd_kyber768 \
    -port $PORT \
    -provider default \
    -provider qkdkemprovider \
    > "$SERVER_LOG" 2>&1
) &
SERVER_PID=$!

echo "[DEBUG] OpenSSL server started with PID: $SERVER_PID"
echo "[DEBUG] Giving the server a moment to start..."
sleep 2

###############################################################################
# Now run the client
###############################################################################
echo "[DEBUG] Running the OpenSSL client to connect to the server on localhost:$PORT"

# We'll pass 'Q' to close the connection once done.
echo "Q" | openssl s_client \
    -CAfile "${CERTS_DIR}/rsa_2048_root_cert.pem" \
    -connect localhost:$PORT \
    -groups qkd_kyber768 \
    -provider default \
    -provider qkdkemprovider 2>&1 | tee "$CLIENT_LOG"

###############################################################################
# Check handshake success
###############################################################################

if grep -q "Verify return code: 0 (ok)" "$CLIENT_LOG"; then
  echo "[INFO] TLS handshake succeeded (return code 0)."
else
  echo "[ERROR] TLS handshake failed or certificate not verified."
  echo "[DEBUG] Client log tail:"; tail -n 20 "$CLIENT_LOG"
  echo "[DEBUG] Server log tail:"; tail -n 20 "$SERVER_LOG"
fi

###############################################################################
# Attempt to parse ephemeral public key from the capture
###############################################################################

# Just for demonstration, we do 'strings' on the capture file,
# then grep for relevant lines.

strings "$CAPTURE_FILE" > "$CAPTURE_STRINGS"

echo "[DEBUG] Searching for 'public key', 'key share', or 'server key' in $CAPTURE_STRINGS"
{
  grep -i -A 15 "public key" "$CAPTURE_STRINGS" || true
  grep -i -A 15 "key share"  "$CAPTURE_STRINGS" || true
  grep -i -A 15 "server key" "$CAPTURE_STRINGS" || true
} > "$PUBLIC_KEY_HEX"

echo "[INFO] Potential ephemeral key data saved to: $PUBLIC_KEY_HEX"

echo "[INFO] TLS handshake test complete."
echo "[INFO] Logs located in: $LOGS_DIR"

exit 0
