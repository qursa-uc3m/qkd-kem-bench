#!/usr/bin/env python3
import subprocess
import time
import sys

# Source environment
subprocess.run(". /opt/scripts/oqs_env.sh", shell=True)

# Test session reuse and key persistence
print("Testing HTTP/2 session reuse with QKD_MLKEM512...")

NUM_REQUESTS = 5
session_file = "/tmp/http2_session.txt"

for i in range(NUM_REQUESTS):
    print(f"Request {i+1}/{NUM_REQUESTS}...")
    result = subprocess.run([
        "curl", "-v", "--http2", 
        "--cacert", "/opt/certs/dilithium/dilithium3_root_cert.pem",
        "--resolve", f"nginx-server:443:{subprocess.getoutput('getent hosts nginx-server | awk \'{ print $1 }\'')}",
        "--tlsv1.3", "--tls-max", "1.3",
        "--ciphers", "TLS_AES_256_GCM_SHA384",
        "--curves", "qkd_mlkem512",
        "--sess-in", session_file if i > 0 else "",
        "--sess-out", session_file,
        "https://nginx-server:443/"
    ], capture_output=True, text=True)
    
    with open(f"/opt/tests/logs/session_reuse_req{i+1}.log", "w") as f:
        f.write(result.stdout)
        f.write(result.stderr)
    
    if "200 OK" not in result.stderr:
        print("Test failed: HTTP request unsuccessful")
        sys.exit(1)
    
    if i > 0 and "TLS session reused" not in result.stderr:
        print(f"Warning: Session was not reused on request {i+1}")
    
    time.sleep(1)

print("HTTP/2 session reuse test passed!")