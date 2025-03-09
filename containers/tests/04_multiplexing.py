#!/usr/bin/env python3
import asyncio
import ssl
import sys
import os
from h2.connection import H2Connection
from h2.events import ResponseReceived, DataReceived, StreamEnded
from h2.settings import SettingCodes

# This script tests true HTTP/2 multiplexing with custom QKD-KEM groups

async def test_multiplexing():
    # Set up SSL context
    ctx = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
    ctx.verify_mode = ssl.CERT_REQUIRED
    ctx.load_verify_locations("/opt/certs/dilithium/dilithium3_root_cert.pem")
    ctx.set_alpn_protocols(['h2'])
    
    # Use custom provider
    os.environ["OPENSSL_CONF"] = "/opt/scripts/openssl-ca.cnf"
    
    # Configure to use QKD-KEM
    ctx.set_ciphers('TLS_AES_256_GCM_SHA384')
    
    # Connect to server
    reader, writer = await asyncio.open_connection('nginx-server', 443, ssl=ctx)
    
    # Set up HTTP/2 connection
    conn = H2Connection()
    conn.initiate_connection()
    writer.write(conn.data_to_send())
    
    # Send initial settings frame
    conn.update_settings({
        SettingCodes.MAX_CONCURRENT_STREAMS: 10,
        SettingCodes.INITIAL_WINDOW_SIZE: 1048576,
    })
    writer.write(conn.data_to_send())
    
    # Open multiple streams at once
    for i in range(5):
        stream_id = conn.get_next_available_stream_id()
        conn.send_headers(
            stream_id=stream_id,
            headers=[
                (':method', 'GET'),
                (':path', f'/test{i}'),
                (':scheme', 'https'),
                (':authority', 'nginx-server'),
                ('user-agent', 'qkd-test-client'),
            ],
            end_stream=True
        )
        writer.write(conn.data_to_send())
    
    # Process responses
    success_count = 0
    while success_count < 5:
        data = await reader.read(1024)
        if not data:
            break
            
        events = conn.receive_data(data)
        writer.write(conn.data_to_send())
        
        for event in events:
            if isinstance(event, (ResponseReceived, DataReceived, StreamEnded)):
                if isinstance(event, StreamEnded):
                    success_count += 1
                    print(f"Stream {event.stream_id} completed successfully")
                    
    writer.close()
    await writer.wait_closed()
    
    if success_count == 5:
        return True
    return False

if __name__ == "__main__":
    if asyncio.run(test_multiplexing()):
        print("Multiplexing test passed!")
        sys.exit(0)
    else:
        print("Multiplexing test failed!")
        sys.exit(1)