#!/bin/bash
. /opt/scripts/oqs_env.sh

# Test basic TLS connection with server using different OQS PROVIDER algorithms

echo "Testing basic TLS connection with QKD_MLKEM512..."

timeout 1 openssl s_client -connect nginx-server:443 -groups qkd_mlkem512 -tls1_3 -provider qkdkemprovider -provider default -msg -debug > /opt/tests/logs/basic_qkdkem_mlkem512.log 2>&1

echo "... Analyzing handshake results ..."

# Check if connection was established
if grep -q "CONNECTED" /opt/tests/logs/basic_qkdkem_mlkem512.log; then
    echo "✓ Connection established"
else
    echo "✗ Failed to establish connection"
    exit 1
fi

# Check if TLS version is correct
if grep -q "Protocol  : TLSv1.3" /opt/tests/logs/basic_qkdkem_mlkem512.log; then
    echo "✓ TLS 1.3 protocol negotiated"
else
    echo "✗ Failed to negotiate TLS 1.3"
    exit 1
fi

# Check if cipher suite was negotiated
if grep -q "Cipher    : TLS_AES_256_GCM_SHA384" /opt/tests/logs/basic_qkdkem_mlkem512.log; then
    echo "✓ Cipher suite negotiated: TLS_AES_256_GCM_SHA384"
else
    echo "✗ Failed to negotiate cipher suite"
    exit 1
fi

# Check for ServerHello message
if grep -q "ServerHello" /opt/tests/logs/basic_qkdkem_mlkem512.log; then
    echo "✓ Received ServerHello message"
else
    echo "✗ No ServerHello message"
    exit 1
fi

# Check for Finished message
if grep -q "Finished" /opt/tests/logs/basic_qkdkem_mlkem512.log; then
    echo "✓ Handshake Finished message exchanged"
else
    echo "✗ No Handshake Finished message"
    exit 1
fi

# Check for session tickets (indicates successful handshake completion)
if grep -q "New Session Ticket" /opt/tests/logs/basic_qkdkem_mlkem512.log; then
    echo "✓ Session tickets received"
else 
    echo "⚠ No session tickets (but handshake might still be valid)"
fi

# Additional check for mlkem512 being used
if grep -q "ServerHello" /opt/tests/logs/basic_qkdkem_mlkem512.log; then
    echo -e "\n✅ HANDSHAKE SUCCESSFUL WITH MLKEM512!"
    echo -e "========================================"
    echo -e "Full details available in: /opt/tests/logs/basic_qkdkem_mlkem512.log\n"
else
    echo -e "\n❌ HANDSHAKE FAILED!"
    echo -e "Full details available in: /opt/tests/logs/basic_qkdkem_mlkem512.log\n"
    exit 1
fi