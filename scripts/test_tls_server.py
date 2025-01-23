import common
import sys
import os
import subprocess
import time
import socket
import argparse
from pathlib import Path

CERTS_DIR = "./certs"

def get_test_env():
    env = os.environ.copy()
    required_vars = ['OPENSSL_CONF', 'OPENSSL_MODULES', 'PATH', 'LD_LIBRARY_PATH']
    missing_vars = [var for var in required_vars if var not in env]
    if missing_vars:
        raise EnvironmentError(f"Missing required environment variables: {', '.join(missing_vars)}")
    return env

def setup_test_environment():
    env = os.environ
    path_dirs = env['PATH'].split(os.pathsep)
    ossl_dir = next((d for d in path_dirs if os.path.exists(os.path.join(d, 'openssl'))), None)
    if not ossl_dir:
        raise FileNotFoundError("OpenSSL binary not found in PATH")
    return {
        'ossl': os.path.join(ossl_dir, 'openssl'),
        'ossl_config': env['OPENSSL_CONF'],
        'project_dir': os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    }

def measure_server_startup():
    env = get_test_env()
    paths = setup_test_environment()
    server_port = 4433
    
    server_cmd = [
        paths['ossl'], 's_server',
        '-cert', os.path.join(paths['project_dir'], f'{CERTS_DIR}/rsa/rsa_2048_entity_cert.pem'),
        '-key', os.path.join(paths['project_dir'], f'{CERTS_DIR}/rsa/rsa_2048_entity_key.pem'),
        '-www', '-tls1_3',
        '-groups', 'qkd_kyber768',
        '-port', str(server_port),
        '-provider', 'default',
        '-provider', 'qkdkemprovider'
    ]
    
    start = time.perf_counter()
    server = subprocess.Popen(server_cmd, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        while True:
            try:
                socket.create_connection(('localhost', server_port), timeout=0.1)
                break
            except:
                pass
        return (time.perf_counter() - start) * 1000
    finally:
        server.kill()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-n', type=int, default=10, help='Number of iterations')
    args = parser.parse_args()

    times = []
    for i in range(args.n):
        time_ms = measure_server_startup()
        times.append(time_ms)
        print(f"Iteration {i+1}: {time_ms:.2f} ms")

    print(f"\nAverage startup time: {sum(times)/len(times):.2f} ms")
    print(f"Min: {min(times):.2f} ms")
    print(f"Max: {max(times):.2f} ms")

if __name__ == "__main__":
    main()