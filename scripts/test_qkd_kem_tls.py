import common
import sys
import os
import subprocess
import time
import pathlib

#OQS_DIR = "/opt/oqs_openssl3"
CERTS_DIR = "./certs"

SUPPORTED_KEMS = {
    'kyber768': 'qkd_kyber768',
    'kyber1024': 'qkd_kyber1024'
}

SUPPORTED_CERTS = {
    'rsa': 'rsa_2048',
    'dilithium': 'dilithium3',
    'falcon': 'falcon512'
}

def get_test_env():
    """Set up the environment variables using existing OpenSSL environment"""
    env = os.environ.copy()
    
    # Verify required environment variables
    required_vars = ['OPENSSL_CONF', 'OPENSSL_MODULES', 'PATH', 'LD_LIBRARY_PATH']
    missing_vars = [var for var in required_vars if var not in env]
    if missing_vars:
        raise EnvironmentError(f"Missing required environment variables: {', '.join(missing_vars)}")
    
    return env
    
def setup_test_environment():
    """Setup paths using environment variables"""
    env = os.environ
    
    # Get OpenSSL path from PATH
    path_dirs = env['PATH'].split(os.pathsep)
    ossl_dir = next((d for d in path_dirs if os.path.exists(os.path.join(d, 'openssl'))), None)
    if not ossl_dir:
        raise FileNotFoundError("OpenSSL binary not found in PATH")
    
    return {
        'ossl': os.path.join(ossl_dir, 'openssl'),
        'ossl_config': env['OPENSSL_CONF'],
        'project_dir': os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    }

def run_tls_test(kem_type='kyber768', cert_type='rsa', verbose=False):
    """Run TLS test with QKD-KEM"""
    # Get environment and paths
    env = get_test_env()
    paths = setup_test_environment()
    
    kex_name = SUPPORTED_KEMS.get(kem_type)
    cert_base = SUPPORTED_CERTS.get(cert_type)
    
    if not kex_name or not cert_base:
        raise ValueError("Unsupported KEM or certificate type")
    
    cert_path = f"{CERTS_DIR}/{cert_type}/{cert_base}"
    
    server_port = 4433
    
    try:
        # Start server
        print("Starting server...")
        server_cmd = [
            paths['ossl'], 's_server',
            '-cert', os.path.join(paths['project_dir'], f'{cert_path}_entity_cert.pem'),
            '-key', os.path.join(paths['project_dir'], f'{cert_path}_entity_key.pem'),
            '-www',
            '-tls1_3',
            '-groups', kex_name,
            '-port', str(server_port),
            '-provider', 'default',
            '-provider', 'qkdkemprovider'
        ]
        
        print("Server command:", ' '.join(server_cmd))
        server = subprocess.Popen(server_cmd, env=env)
        
        # Give the server a moment to start
        time.sleep(2)
        
        # Run client
        print(f"\nRunning client with {kex_name}...")
        client_cmd = [
            paths['ossl'], 's_client',
            '-connect', f'localhost:{server_port}',
            '-groups', kex_name,
            '-CAfile', os.path.join(paths['project_dir'], f'{cert_path}_root_cert.pem'),
            '-provider', 'default',
            '-provider', 'qkdkemprovider'
        ]
        print("Client command:", ' '.join(client_cmd))
        
        # Time measurement - start
        start_time = time.perf_counter_ns()
        client_output = common.run_subprocess(
            client_cmd,
            input='Q'.encode(),
            env=env
        )
        end_time = time.perf_counter_ns() # Time measurement - end
    
        handshake_time = (end_time - start_time) / 1e6 # Convert to milliseconds
        
        # Check result
        if "SSL handshake has read" in client_output:
            print(f"\nSuccess: TLS handshake completed successfully with {kex_name} in {handshake_time:.2f} ms")
            print("\nClient output:")
            print(client_output)
            return True
        else:
            print(f"\nError: TLS handshake failed with {kex_name}. Time elapsed: {handshake_time:.2f} ms")
            print("\nClient output:")
            print(client_output)
            return False
            
    except Exception as e:
        print(f"\nError during test execution: {str(e)}")
        return False
    finally:
        # Cleanup
        if 'server' in locals():
            print("\nStopping server...")
            server.kill()

if __name__ == "__main__":
    success = run_tls_test()
    sys.exit(0 if success else 1)