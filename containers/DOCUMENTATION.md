# QKD-KEM Benchmarking Guide - Updated

## Overview

This guide describes the containerized benchmarking environment for testing and comparing QKD-KEM (Quantum Key Distribution - Key Encapsulation Mechanism) provider with OpenSSL and Open Quantum Safe (OQS) integration. The setup consists of two main Docker containers:

1. **nginx-server**: A TLS server with QKD-KEM and OQS provider integration
2. **h2load**: A client for benchmarking HTTPS connections with different KEM algorithms

## Directory Structure

```
qkd-kem-bench/
├── containers/
│   ├── nginx-server/
│   │   ├── Dockerfile
│   │   └── config/
│   │       └── nginx.conf
│   ├── h2load/
│   │   ├── Dockerfile
│   │   ├── h2load-benchmarks.sh
│   │   ├── check_algorithms.sh
│   │   └── benchmark_results_parser.py
│   └── docker-compose.yml
├── scripts/
│   ├── generate_certs.sh
│   ├── oqs_env.sh
│   └── openssl-ca.cnf
├── qkd_certs/
└── benchmarks/
    └── data/
```

## Build Process Overview

The container build follows this sequence:

1. Install build dependencies
2. Clone required repositories (liboqs, OpenSSL, oqs-provider, qkd-kem-provider)
3. Build liboqs
4. Build OpenSSL 3.4.0
5. Install qkd-etsi-api (critical for QKD backend integration)
6. Build OQS provider
7. Build QKD-KEM provider
8. Generate quantum-resistant certificates
9. Build the application (NGINX or h2load)

## Container Details

### nginx-server

This container runs an NGINX server with TLS 1.3 support, integrated with both the QKD-KEM provider and the OQS provider for post-quantum cryptography.

**Key Features:**
- OpenSSL 3.4.0 integration
- QKD-ETSI API for backend connectivity
- QKD-KEM provider support
- OQS provider for post-quantum algorithms
- Certificate generation for multiple quantum-resistant signature algorithms
- Configurable KEM groups via environment variables
- Support for different QKD backends (simulated, cerberis-xgr, qukaydee)

### h2load

This container provides HTTP/2 load testing tools for benchmarking the TLS handshake performance with different KEMs.

**Key Features:**
- H2load HTTP/2 benchmarking tool
- QKD-ETSI API integration
- OQS and QKD-KEM provider integration
- Automated benchmarking scripts
- Results parsing and analysis tools
- Support for testing various KEM algorithms

## Building and Running the Containers

### Prerequisites

- Docker installed and configured
- Docker Compose installed
- If using actual QKD hardware backends, appropriate certificates in the `qkd_certs` directory

### Building the Containers

Navigate to the `containers` directory and run:

```bash
docker-compose build
```

This builds both the nginx-server and h2load containers with default settings.

### Running the NGINX Server

Start the NGINX server with:

```bash
docker-compose up -d nginx-server
```

The server will be accessible at https://localhost:4433.

### Running Benchmarks

Run benchmarks with specific algorithms:

```bash
docker-compose run h2load /usr/local/bin/h2load-benchmarks.sh -c 10 -n 100 -i localhost -p 4433 -m qkd-kem
```

Or test a specific algorithm:

```bash
docker-compose run h2load --groups kyber512 https://localhost:4433
```

### Setting QKD Backend

Change the QKD backend by modifying the environment variables:

```bash
QKD_BACKEND=cerberis-xgr docker-compose up -d nginx-server
QKD_BACKEND=cerberis-xgr docker-compose run h2load --groups kyber512 https://localhost:4433
```

## Configuration Options

### Environment Variables

- `DEFAULT_GROUPS`: Comma-separated list of KEM algorithms to enable
- `QKD_BACKEND`: QKD backend type (simulated, cerberis-xgr, qukaydee)
- `ACCOUNT_ID`: Account ID for QuKayDee backend (if applicable)

### Build Arguments

- `OPENSSL_BRANCH`: OpenSSL version to build (default: openssl-3.4.0)
- `LIBOQS_BRANCH`: liboqs branch to use (default: main)
- `OQSPROV_BRANCH`: OQS provider branch (default: 0.8.0)
- `QKDKEMPROV_BRANCH`: QKD-KEM provider branch (default: main)

## QKD Backend Integration

The containers include qkd-etsi-api which provides:
1. An ETSI 014 interface for QKD key management
2. Backend-specific adapters (simulated, cerberis-xgr, qukaydee)
3. Integration with the QKD-KEM provider for TLS key exchange

### Backend Configuration

Each backend requires specific configuration:

#### Simulated Backend
- No additional configuration needed

#### Cerberis-XGR Backend
- Requires certificates in `qkd_certs/` (ChrisCA.pem, ETSIA.pem, ETSIA-key.pem, etc.)
- Sets KME hostnames automatically

#### QuKayDee Backend
- Requires ACCOUNT_ID to be set
- Requires specific certificates in `qkd_certs/`

## Expected Outputs

### Certificate Generation

During container build, the `generate_certs.sh` script creates certificates for multiple signature algorithms in `/opt/certs/`:

- Dilithium (dilithium2, dilithium3, dilithium5)
- ML-DSA (mldsa44, mldsa65, mldsa87)
- Falcon (falcon512, falcon1024)
- SPHINCS+ with SHA2 and SHAKE variants
- RSA (2048, 3072, 4096 bits)

### Benchmark Results

Benchmark results are stored in:
- Raw logs in `/benchmarks/data/raw/`
- Processed CSV files in `/benchmarks/data/processed/`

The processed results include:
- Summary statistics (TPS, latency percentiles)
- Detailed timing information
- CSV files for further analysis

## Debugging

### Build Debugging

```bash
# Verbose build output
docker-compose build --progress=plain

# Force rebuild without cache
docker-compose build --no-cache
```

### Runtime Debugging

```bash
# View logs
docker-compose logs -f nginx-server

# Execute commands in containers
docker-compose exec nginx-server bash

# Test if providers are loaded
docker-compose exec nginx-server bash -c '. /opt/scripts/oqs_env.sh && openssl list -providers'

# Test TLS connection manually
docker-compose exec h2load bash -c '. /opt/scripts/oqs_env.sh && openssl s_client -connect localhost:4433'

# Check QKD-ETSI API connectivity
docker-compose exec nginx-server bash -c 'ls -la /usr/local/lib/libqkd-etsi-api*'
```

## Supported Algorithms

### Classical KEMs
- X25519, X448
- P-256, P-384, P-521

### Post-Quantum KEMs
- Kyber (kyber512, kyber768, kyber1024)
- BIKE (bikel1, bikel3)
- Frodo (various variants)
- HQC (hqc128, hqc192)

### Hybrid KEMs
- p256_kyber512
- p384_kyber768
- p521_kyber1024
- p256_bikel1
- p384_bikel3
- Others as specified in the env.list file

## Notes and Limitations

1. The QKD backend requires appropriate certificates and configuration in `qkd_certs/`.
2. Some signature algorithms may have significant performance impact on TLS handshakes.
3. Alpine-based images might have compatibility issues with some libraries.
4. Benchmarking should be performed multiple times for statistical significance.
5. Certificate path validation might need adjustment for certain applications.

## Customization

### Adding New Algorithms

To test new algorithms, add them to the DEFAULT_GROUPS environment variable in docker-compose.yml or env.list.

### Modifying NGINX Configuration

To change the NGINX configuration, edit `containers/nginx-server/config/nginx.conf` before building the container.

### Using Different Certificate Types

By default, the server uses dilithium3 certificates. To use a different certificate:

1. Modify the nginx.conf file to point to a different certificate path:
```
ssl_certificate      /opt/certs/falcon/falcon1024_entity_cert.pem;
ssl_certificate_key  /opt/certs/falcon/falcon1024_entity_key.pem;
```

2. Rebuild and restart the container.