#!/usr/bin/env python3
import sys
import re
import json
from collections import defaultdict

def analyze_tls_log(logfile):
    """Analyze TLS handshake from OpenSSL s_client debug output"""
    analysis = {
        "key_exchange": [],
        "shared_key": False,
        "handshake_time_ms": None,
        "errors": [],
        "qkd_operations": []
    }
    
    with open(logfile, 'r') as f:
        content = f.read()
    
    # Look for QKD operations
    qkd_ops = re.findall(r"QKD DEBUG:.*", content)
    for op in qkd_ops:
        analysis["qkd_operations"].append(op.strip())
    
    # Identify key exchange messages
    key_msgs = re.findall(r"ClientKeyExchange|ServerKeyExchange", content)
    analysis["key_exchange"] = key_msgs
    
    # Check if shared key was established
    if "Shared Secret" in content or "ENCAPS" in content:
        analysis["shared_key"] = True
    
    # Calculate handshake time if available
    time_match = re.search(r"handshake:\s+(\d+\.\d+)s", content)
    if time_match:
        analysis["handshake_time_ms"] = float(time_match.group(1)) * 1000
    
    # Capture errors
    errors = re.findall(r"error.*", content, re.IGNORECASE)
    analysis["errors"] = [e.strip() for e in errors]
    
    return analysis

def main():
    if len(sys.argv) < 2:
        print("Usage: ./analyze_tls_handshake.py <logfile>")
        return 1
    
    results = analyze_tls_log(sys.argv[1])
    print(json.dumps(results, indent=2))
    
    if results["errors"]:
        print("\nPotential issues detected:")
        for error in results["errors"]:
            print(f"  - {error}")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())