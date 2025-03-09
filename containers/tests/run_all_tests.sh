#!/bin/bash

set -e
mkdir -p /opt/tests/logs

echo "===================== QKD-KEM HTTP/2 Testing Framework ====================="
echo "Starting tests with QKD backend: $QKD_BACKEND"

# Wait for NGINX to be fully ready
echo "Waiting for NGINX server to be ready..."
timeout 30 bash -c 'until ping -c1 nginx-server &>/dev/null; do sleep 1; done'
sleep 5  # Additional wait for TLS setup

# Run tests in sequence
echo ""
echo "==== Stage 1: Basic Connectivity Tests ===="
/opt/tests/01_basic_conn.sh

echo ""
echo "==== Stage 2: Single HTTP/2 Request Tests ===="
/opt/tests/02_http2_single.sh

echo ""
echo "==== Stage 3: Session Management Tests ===="
/opt/tests/03_session_reuse.py

echo ""
echo "==== Stage 4: HTTP/2 Multiplexing Tests ===="
/opt/tests/04_multiplexing.py

echo ""
echo "==== Stage 5: End-to-End Application Tests ===="
# Add your application-specific tests here

echo ""
echo "All tests completed successfully!"
echo "Check logs at /opt/tests/logs/ for detailed results."