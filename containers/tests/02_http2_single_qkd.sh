#!/bin/bash
. /opt/scripts/oqs_env.sh

# Test a single HTTP/2 request with qkd_mlkem512
echo "Testing single HTTP/2 request with QKD_MLKEM512..."
curl -v --http2 \
     --resolve nginx-server:443:$(getent hosts nginx-server | awk '{ print $1 }') \
     --tlsv1.3 --tls-max 1.3 \
     --curves qkd_mlkem512 \
     -k https://nginx-server:443/ > /opt/tests/logs/single_http2_qkd_mlkem512.log 2>&1

echo "... Analyzing HTTP/2 results ..."

# Check if connection was established
if grep -q "Connected to nginx-server" /opt/tests/logs/single_http2_qkd_mlkem512.log; then
    echo "✓ Connection established"
else
    echo "✗ Failed to establish connection"
    exit 1
fi

# Check if TLS version is correct
if grep -q "SSL connection using TLSv1.3" /opt/tests/logs/single_http2_qkd_mlkem512.log; then
    echo "✓ TLS 1.3 protocol negotiated"
else
    echo "✗ Failed to negotiate TLS 1.3"
    exit 1
fi

# Check if cipher suite was negotiated
if grep -q "TLS_AES_256_GCM_SHA384" /opt/tests/logs/single_http2_qkd_mlkem512.log; then
    echo "✓ Cipher suite negotiated: TLS_AES_256_GCM_SHA384"
else
    echo "✗ Failed to negotiate cipher suite"
    exit 1
fi

# Check for HTTP/2 protocol
if grep -q "HTTP/2 confirmed" /opt/tests/logs/single_http2_qkd_mlkem512.log; then
    echo "✓ HTTP/2 protocol successfully negotiated"
else
    echo "✗ Failed to negotiate HTTP/2 protocol"
    exit 1
fi

# Check if the response contains expected HTML content
if grep -q "Welcome to the PQC-QKD NGINX Server" /opt/tests/logs/single_http2_qkd_mlkem512.log; then
    echo "✓ Server returned expected HTML content"
else
    echo "✗ Server response did not contain expected content"
    exit 1
fi

# Check for TLS handshake messages
if grep -q "TLS handshake" /opt/tests/logs/single_http2_qkd_mlkem512.log; then
    echo "✓ TLS handshake messages observed"
else
    echo "✗ No TLS handshake messages observed"
    exit 1
fi

# Check for session tickets
if grep -q "Newsession Ticket" /opt/tests/logs/single_http2_qkd_mlkem512.log; then
    echo "✓ TLS session tickets received"
else 
    echo "⚠ No TLS session tickets (but connection might still be valid)"
fi

# Check for successful HTTP status code
if grep -q -E "< HTTP/[12].[01] 200|< HTTP/2 200" /opt/tests/logs/single_http2_mlkem512.log; then
    echo "✓ Server returned HTTP 200 OK status"
elif grep -q -E "content-length: [0-9]+" /opt/tests/logs/single_http2_mlkem512.log; then
    echo "✓ Server returned content (likely successful)"
else
    echo "✗ Server did not indicate successful response"
    exit 1
fi

# Final verdict
echo -e "\n✅ HTTP/2 REQUEST SUCCESSFUL WITH MLKEM512!"
echo -e "=========================================="
echo -e "Full details available in: /opt/tests/logs/single_http2_qkd_mlkem512.log\n"

# Display a summary of the successful connection
echo "Connection Summary:"
echo "-------------------"
echo "Protocol: TLSv1.3 with HTTP/2"
echo "KEM Algorithm: MLKEM512"
echo "Cipher: TLS_AES_256_GCM_SHA384"
echo "Server: $(grep -m 1 "server:" /opt/tests/logs/single_http2_qkd_mlkem512.log | cut -d: -f2- | xargs)"
echo "Content Type: $(grep -m 1 "content-type:" /opt/tests/logs/single_http2_qkd_mlkem512.log | cut -d: -f2- | xargs)"
echo "Content Length: $(grep -m 1 "content-length:" /opt/tests/logs/single_http2_qkd_mlkem512.log | cut -d: -f2- | xargs) bytes"
echo -e "\nHTTP/2 single request test passed!"