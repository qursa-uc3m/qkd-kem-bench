# QKD-KEM Benchmarking Guide - Updated

## Overview

This guide describes the containerized benchmarking environment for testing and comparing QKD-KEM (Quantum Key Distribution - Key Encapsulation Mechanism) provider with OpenSSL and Open Quantum Safe (OQS) integration. The setup consists of two main Docker containers:

1. **nginx-server**: A TLS server with QKD-KEM and OQS provider integration
2. **h2load-bench**: A client for benchmarking HTTPS connections with different KEM algorithms

## Directory Structure

```
qkd-kem-bench/
├── containers/
│   ├── nginx-server/
│   │   ├── Dockerfile
│   │   └── config/
│   │       └── nginx.conf
│   │       └── start.sh
│   ├── h2load-bench/
│   │   ├── Dockerfile
│   │   ├── config/
│   │   │   └── wrapper.sh
│   │   │   └── start.sh  
│   │   ├── h2load-benchmarks.sh
│   │   ├── check_algorithms.sh
│   │   └── benchmark_results_parser.py
│   ├── docker-compose.yml
│   └── .env
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

### h2load-bench

This container provides HTTP/2 load testing tools for benchmarking the TLS handshake performance with different KEMs.

**Key Features:**
- H2load HTTP/2 benchmarking tool
- QKD-ETSI API integration
- OQS and QKD-KEM provider integration
- Automated benchmarking scripts
- Results parsing and analysis tools
- Support for testing various KEM algorithms
- Persistent container design for consistent benchmarking

## Environment Variables and OpenSSL Configuration

### Environment Variable Persistence in Docker

Docker containers have two types of environment variables:

1. **Persistent Environment Variables**:
   - Variables defined in the Dockerfile with `ENV` statements
   - Variables defined in the `environment` section of docker-compose.yml
   - These are available to all processes in the container

2. **Non-Persistent Environment Variables**:
   - Variables set by sourcing scripts during runtime (like `oqs_env.sh`)
   - These are only available in the shell session where they were sourced

The OpenSSL provider system requires specific environment variables that are set by the `oqs_env.sh` script, including:
- `OPENSSL_MODULES`
- `OPENSSL_CONF`
- Path updates for OpenSSL binaries
- `LD_LIBRARY_PATH` updates for shared libraries

### Sourcing the Environment Script

When executing commands with `docker-compose exec`, you need to source the environment script first:

```bash
docker-compose exec h2load-bench bash -c '. /opt/scripts/oqs_env.sh && command'
```

This ensures all OpenSSL-related environment variables are properly set for each command.

## Running the Benchmarking Environment

### Prerequisites

- Docker installed and configured
- Docker Compose installed
- If using actual QKD hardware backends, appropriate certificates in the `qkd_certs` directory

### Building the Containers

Navigate to the `containers` directory and run:

```bash
# Build both containers with progress output
docker-compose build --progress=plain --no-cache

# Build containers individually
docker-compose build --progress=plain --no-cache nginx-server
docker-compose build --progress=plain --no-cache h2load-bench
```

### Starting the Environment

Both containers now run as persistent services, with fixed names and a dedicated network:

```bash
# Start both containers in detached mode
docker-compose up -d

# Verify containers are running
docker ps
```

You should see two containers running:
- `nginx-server`: The HTTPS server
- `h2load-bench`: The benchmarking client

They communicate over a dedicated network named `qkd-network` and share a volume named `certs_data` for certificate access.

### Running Benchmarks

The improved setup uses a persistent h2load-bench container. When running commands, always source the environment script first:

```bash
# Run a single benchmark manually (with environment script sourcing)
docker-compose exec h2load-bench bash -c '. /opt/scripts/oqs_env.sh && h2load -n 50 -c 1 https://nginx-server:443 --groups mlkem512'

# Check provider loading in the container
docker-compose exec h2load-bench bash -c '. /opt/scripts/oqs_env.sh && openssl list -providers'
```

#### Using the Benchmarking Script

Update your h2load-benchmarks.sh script to source the environment first:

```bash
# Change this line:
docker-compose exec -T h2load-bench h2load -n $requests -c 1 https://$ip:$port --groups $algorithm > $output_raw_file

# To this:
docker-compose exec -T h2load-bench bash -c '. /opt/scripts/oqs_env.sh && h2load -n '$requests' -c 1 https://'$ip':'$port' --groups '$algorithm'' > $output_raw_file
```

Then run benchmarks:

```bash
# Navigate to the h2load-bench directory
cd containers/h2load-bench/

# Run benchmarks with OQS algorithms
./h2load-benchmarks.sh -n 100 -i nginx-server -p 443 -m oqs

# Run benchmarks with QKD-KEM algorithms 
./h2load-benchmarks.sh -n 100 -i nginx-server -p 443 -m qkd-kem
```

### Interactive Shell Sessions

For interactive work, you can start a shell and source the environment once:

```bash
# Access h2load-bench shell
docker-compose exec h2load-bench bash

# Source the environment script once inside the shell
. /opt/scripts/oqs_env.sh

# Now run commands without needing to source again
h2load -n 10 -c 1 https://nginx-server:443 --groups mlkem512
openssl list -providers
```

### Setting QKD Backend

Change the QKD backend by modifying the environment variables:

```bash
QKD_BACKEND=cerberis-xgr docker-compose up -d
```

Or for QuKayDee:

```bash
QKD_BACKEND=qukaydee ACCOUNT_ID=2507 docker-compose up -d
```

### Shutting Down

```bash
# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

## Configuration Options

### Environment Variables

- `DEFAULT_GROUPS`: Comma-separated list of KEM algorithms to enable
- `QKD_BACKEND`: QKD backend type (simulated, cerberis-xgr, qukaydee)
- `ACCOUNT_ID`: Account ID for QuKayDee backend (if applicable)
- `SSL_CERT_DIR`: Certificate directory to use (dilithium, mldsa, falcon, etc.)
- `SSL_CERT_TYPE`: Specific certificate type (dilithium3, mldsa44, falcon512, etc.)

### Build Arguments

- `OPENSSL_BRANCH`: OpenSSL version to build (default: openssl-3.4.0)
- `LIBOQS_BRANCH`: liboqs branch to use (default: main)
- `OQSPROV_BRANCH`: OQS provider branch (default: 0.8.0)
- `QKDKEMPROV_BRANCH`: QKD-KEM provider branch (default: main)
- `QKD_ETSI_API_BRANCH`: QKD ETSI API branch (default: main)

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

## Volume and Network Details

The updated configuration uses named volumes and networks for consistency:

- **Network**: `qkd-network` (custom bridge network for container communication)
- **Volume**: `certs_data` (shared volume for certificates)
- **Container Names**: Fixed as `nginx-server` and `h2load-bench`

This ensures resources have consistent names regardless of project directory, making scripts and commands more reliable.

## Expected Outputs

### Certificate Generation

During container build, the `generate_certs.sh` script creates certificates for multiple signature algorithms in `/opt/certs/`:

- Dilithium (dilithium2, dilithium3, dilithium5)
- ML-DSA (mldsa44, mldsa65, mldsa87)
- Falcon (falcon512, falcon1024)
- SPHINCS+ with SHA2 and SHAKE variants
- RSA (2048, 3072, 4096 bits)

These certificates are shared between containers via the `certs_data` volume.

### Benchmark Results

Benchmark results are stored in:
- Raw logs in `/benchmarks/data/{requests}_requests/{mode}/run_{run}/raw/`
- Processed CSV files in `/benchmarks/data/{requests}_requests/{mode}/run_{run}/processed/{algorithm}/`

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

Remember to source the environment script for OpenSSL-related commands:

```bash
# View logs
docker-compose logs -f nginx-server
docker-compose logs -f h2load-bench

# Execute commands in containers with environment sourcing
docker-compose exec h2load-bench bash -c '. /opt/scripts/oqs_env.sh && openssl list -providers'

# Test TLS connection manually
docker-compose exec h2load-bench bash -c '. /opt/scripts/oqs_env.sh && openssl s_client -connect nginx-server:443'

# Check certificate volume contents
docker-compose exec h2load-bench ls -la /opt/certs

# Inspect the Docker network
docker network inspect qkd-network
```

### Debugging Environment Issues

If commands fail with errors like "provider not found" or "unable to load provider", the environment variables likely aren't set properly. Make sure to source the environment script:

```bash
# Debug environment variables
docker-compose exec h2load-bench bash -c '. /opt/scripts/oqs_env.sh && env | grep OPENSSL'

# Check if environment script is working
docker-compose exec h2load-bench bash -c 'cat /opt/scripts/oqs_env.sh'
```

### Troubleshooting Certificates

If you experience certificate issues:

```bash
# Check if certificates exist in the shared volume from nginx-server
docker-compose exec nginx-server ls -la /opt/certs

# Check if h2load-bench can access the certificates
docker-compose exec h2load-bench ls -la /opt/certs

# Verify container connectivity
docker-compose exec h2load-bench ping nginx-server
```

## Supported Algorithms

### Classical KEMs
- X25519, X448
- P-256, P-384, P-521

### Post-Quantum KEMs
- Kyber/MLKEM (mlkem512, mlkem768, mlkem1024)
- BIKE (bikel1, bikel3)
- Frodo (various variants)
- HQC (hqc128, hqc192)

### Hybrid KEMs
- p256_kyber512
- p384_kyber768
- p521_kyber1024
- p256_bikel1
- p384_bikel3
- Others as specified in the .env file

### QKD-enabled KEMs
- qkd_mlkem512
- qkd_mlkem768
- qkd_mlkem1024
- qkd_bikel1
- qkd_frodo640aes
- qkd_hqc128
- Other QKD variants prefixed with qkd_

## Notes and Limitations

1. **Environment Management**: OpenSSL-related commands require sourcing the `oqs_env.sh` script for each new exec session
2. **Container Persistence**: Both containers now run persistently, enabling more reliable benchmarking
3. **Named Resources**: Fixed names for containers, networks, and volumes improve script reliability
4. **QKD Backend**: QKD backend requires appropriate certificates and configuration in `qkd_certs/`
5. **Algorithm Performance**: Some signature algorithms may have significant performance impact on TLS handshakes
6. **Image Compatibility**: Alpine-based images might have compatibility issues with some libraries
7. **Benchmarking Methodology**: Benchmarking should be performed multiple times for statistical significance
8. **Container Composition**: The nginx-server container uses Ubuntu while h2load-bench uses Alpine Linux

## Customization

### Adding New Algorithms

To test new algorithms, add them to the DEFAULT_GROUPS environment variable in docker-compose.yml or .env file.

### Modifying NGINX Configuration

To change the NGINX configuration, edit `containers/nginx-server/config/nginx.conf` before building the container.

### Using Different Certificate Types

By default, the server uses dilithium3 certificates. To use a different certificate:

1. Modify the environment variables when starting the container:
```bash
SSL_CERT_DIR=falcon SSL_CERT_TYPE=falcon1024 docker-compose up -d
```

2. Or modify the nginx.conf file directly to point to a different certificate path:
```
ssl_certificate      /opt/certs/falcon/falcon1024_entity_cert.pem;
ssl_certificate_key  /opt/certs/falcon/falcon1024_entity_key.pem;
```

### Using Direct Docker Commands

If you prefer using Docker directly instead of Docker Compose, you can use these commands:

```bash
# Start nginx-server
docker run -d --name nginx-server \
  --network qkd-network \
  -p 443:443 \
  -v "$(pwd)/../qkd_certs:/opt/qkd_certs" \
  -v certs_data:/opt/certs \
  -e DEFAULT_GROUPS="mlkem512:mlkem768:mlkem1024" \
  -e QKD_BACKEND="qukaydee" \
  -e SSL_CERT_DIR="mldsa" \
  -e SSL_CERT_TYPE="mldsa44" \
  -e ACCOUNT_ID="2507" \
  containers_nginx-server

# Start h2load-bench
docker run -d --name h2load-bench \
  --network qkd-network \
  -v "$(pwd)/../qkd_certs:/opt/qkd_certs" \
  -v certs_data:/opt/certs \
  -e QKD_BACKEND="qukaydee" \
  -e ACCOUNT_ID="2507" \
  containers_h2load-bench

# Run benchmarks (with environment sourcing)
docker exec -T h2load-bench bash -c '. /opt/scripts/oqs_env.sh && h2load -n 50 -c 1 https://nginx-server:443 --groups mlkem512'
```

However, using Docker Compose is recommended for simpler management of the environment.

### Optional: Automating Environment Variable Sourcing

If you frequently run commands and find the environment sourcing tedious, you could modify the h2load-bench Dockerfile to add the environment sourcing to .bashrc:

```dockerfile
# Add to the end of the Dockerfile
RUN echo '. /opt/scripts/oqs_env.sh' >> /root/.bashrc
```

This would automatically source the environment for interactive bash sessions, though you would still need to explicitly source for non-interactive commands.