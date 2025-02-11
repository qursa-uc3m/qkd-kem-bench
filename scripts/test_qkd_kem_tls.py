import common
import sys
import os
import subprocess
import time
import pathlib
import argparse

#OQS_DIR = "/opt/oqs_openssl3"
CERTS_DIR = "./certs"

SUPPORTED_KEMS = {
    # MLKEM family
    'mlkem512': {'oqs': 'mlkem512', 'qkd': 'qkd_mlkem512'},
    'mlkem768': {'oqs': 'mlkem768', 'qkd': 'qkd_mlkem768'},
    'mlkem1024': {'oqs': 'mlkem1024', 'qkd': 'qkd_mlkem1024'},
    # BIKE family
    'bikel1': {'oqs': 'bikel1', 'qkd': 'qkd_bikel1'},
    'bikel3': {'oqs': 'bikel3', 'qkd': 'qkd_bikel3'},
    'bikel5': {'oqs': 'bikel5', 'qkd': 'qkd_bikel5'},
    # Frodo family
    'frodo640aes': {'oqs': 'frodo640aes', 'qkd': 'qkd_frodo640aes'},
    'frodo640shake': {'oqs': 'frodo640shake', 'qkd': 'qkd_frodo640shake'},
    'frodo976aes': {'oqs': 'frodo976aes', 'qkd': 'qkd_frodo976aes'},
    'frodo976shake': {'oqs': 'frodo976shake', 'qkd': 'qkd_frodo976shake'},
    'frodo1344aes': {'oqs': 'frodo1344aes', 'qkd': 'qkd_frodo1344aes'},
    'frodo1344shake': {'oqs': 'frodo1344shake', 'qkd': 'qkd_frodo1344shake'},
    # HQC family
    'hqc128': {'oqs': 'hqc128', 'qkd': 'qkd_hqc128'},
    'hqc192': {'oqs': 'hqc192', 'qkd': 'qkd_hqc192'},
    'hqc256': {'oqs': 'hqc256', 'qkd': 'qkd_hqc256'}
}

SUPPORTED_CERTS = {
    'rsa': {'rsa_2048', 'rsa_3072', 'rsa_4096'},
    'mldsa': {'mldsa44', 'mldsa65', 'mldsa87'},
    'falcon': {'falcon512', 'falcon1024'},
    'sphincssha2' : {'sphincssha2128fsimple', 'sphincssha2128ssimple', 'sphincssha2192fsimple'},
    'sphincsshake' : {'sphincsshake128fsimple'},

}

# Create a mapping from certificate variant to its type
CERT_VARIANT_TO_TYPE = {}
for cert_type, variants in SUPPORTED_CERTS.items():
    for variant in variants:
        CERT_VARIANT_TO_TYPE[variant] = cert_type

# All possible certificate variants for argument choices
ALL_CERT_VARIANTS = list(CERT_VARIANT_TO_TYPE.keys())

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

def run_tls_test(kem_type='kyber768', cert_variant='rsa_2048', provider='qkd', verbose=False):
    """Run TLS test with QKD-KEM
    provider: 'oqs' for OQS KEMs, 'qkd' for QKD-KEMs
    """
    # Get environment and paths
    env = get_test_env()
    paths = setup_test_environment()
    
    # Get KEM variant
    kem_variants = SUPPORTED_KEMS.get(kem_type)
    if not kem_variants:
        raise ValueError("Unsupported KEM type")
    kex_name = kem_variants.get(provider)
    if not kex_name:
        raise ValueError("Unsupported provider")
    
    # Get the cert_type for the given variant
    cert_type = CERT_VARIANT_TO_TYPE.get(cert_variant)
    if not cert_type:
        raise ValueError(f"Unsupported certificate variant: {cert_variant}")
    
    cert_path = f"{CERTS_DIR}/{cert_type}/{cert_variant}"
    server_port = 4433
    
    try:
        # Start server
        server_cmd = [
            paths['ossl'], 's_server',
            '-cert', os.path.join(paths['project_dir'], f'{cert_path}_entity_cert.pem'),
            '-key', os.path.join(paths['project_dir'], f'{cert_path}_entity_key.pem'),
            '-www',
            '-tls1_3',
            '-groups', kex_name,
            '-port', str(server_port),
            '-provider', 'oqs',
            '-provider', 'qkdkemprovider'
        ]
        
        if verbose:
            print("Starting server...")
            print("Server command:", ' '.join(server_cmd))

        server_env = env.copy()
        server_env['IS_TLS_SERVER'] = '1'    

        server = subprocess.Popen(server_cmd, env=server_env, 
                                stdout=subprocess.DEVNULL if not verbose else None,
                                stderr=subprocess.DEVNULL if not verbose else None)
        
        # Give the server a moment to start
        time.sleep(0.05) # You might have to increase this value if running non-local server.
        
        # Run client
        
        client_cmd = [
            paths['ossl'], 's_client',
            '-connect', f'localhost:{server_port}',
            '-groups', kex_name,
            '-CAfile', os.path.join(paths['project_dir'], f'{cert_path}_root_cert.pem'),
            '-provider', 'oqs',
            '-provider', 'qkdkemprovider'
        ]

        if verbose:
            print(f"\nRunning client with {kex_name}...")
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
            if verbose:
                print("\nClient output:")
                print(client_output)
            return True, handshake_time
        else:
            print(f"\nError: TLS handshake failed with {kex_name}. Time elapsed: {handshake_time:.2f} ms")
            if verbose:
                print("\nClient output:")
                print(client_output)
            return False, handshake_time
                
    except Exception as e:
        print(f"\nError during test execution: {str(e)}")
        return False, None
    finally:
        # Cleanup
        if 'server' in locals():
            server.kill()
            if verbose:
                print("\nShutting down server...")
    
def main():
    # Set up argument parser
    parser = argparse.ArgumentParser(description='Run TLS test with QKD-KEM')
    
    # KEM type argument
    parser.add_argument('-k', '--kem', 
                        choices=list(SUPPORTED_KEMS.keys()), 
                        default='kyber768', 
                        help='Key Encapsulation Method (KEM) type')
    
    # Certificate variant argument
    parser.add_argument('-c', '--cert', 
                        choices=ALL_CERT_VARIANTS, 
                        default='rsa_2048', 
                        help='Certificate variant')
    
    # Provider type argument
    parser.add_argument('-p', '--provider', 
                        choices=['oqs', 'qkd'], 
                        default='qkd', 
                        help='OpenSSL Provider type')
    
    # Verbose mode argument
    parser.add_argument('-v', '--verbose', 
                        action='store_true', 
                        help='Enable verbose output')
    
    # Parse arguments
    args = parser.parse_args()
    
    # Run the test with parsed arguments
    success, handshake_time = run_tls_test(
        kem_type=args.kem, 
        cert_variant=args.cert, 
        provider=args.provider,
        verbose=args.verbose
    )
    
    # Output result for the shell script to capture
    if success:
        print(f"Success: TLS handshake completed successfully in {handshake_time:.2f} ms")
    else:
        print("Failure: TLS handshake failed")
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()