# qkd-kem-bench

# qkd-kem-bench

A comprehensive benchmarking suite for the [QKD-KEM Provider](https://github.com/qursa-uc3m/qkd-kem-provider), integrating quantum key distribution with post-quantum cryptography. This project combines:

- [QKD-KEM Provider](https://github.com/qursa-uc3m/qkd-kem-provider): A quantum-safe provider that integrates QKD with KEM operations
- [QKD ETSI API](https://github.com/qursa-uc3m/qkd-etsi-api): Implementation of the ETSI QKD API standards
- [liboqs](https://github.com/open-quantum-safe/liboqs): Open Quantum Safe library providing quantum-safe cryptographic algorithms
- [OpenSSL](https://github.com/openssl/openssl): Core cryptographic library (version 3.0 or higher)
- [oqs-provider](https://github.com/open-quantum-safe/oqs-provider): Standard OpenSSL provider for quantum-safe algorithms

The benchmarking utility is based on the testing framework developed by the Open Quantum Safe (OQS) project, modified to incorporate time measurements over KEM operations (Key generation, encapsulation and decapsulation). It enables performance evaluation of various quantum-safe key establishment methods, including pure QKD, pure KEM, and hybrid approaches. 

## About the Project

This work is part of the QURSA (Quantum-based Resistant Architectures and Techniques) project, developed through collaboration between:

- Information and Computing Laboratory (I&CLab), Department of Telematic Engineering, Universidade de Vigo (UVigo)
- Pervasive Computing Laboratory, Department of Telematic Engineering, Universidad Carlos III de Madrid (UC3M)

## Protocol Overview

For detailed information about the protocol specification, including the key generation, encapsulation, and decapsulation processes, please see our [Protocol Documentation](docs/protocol.md).

## Dependencies

This project requires our [QKD ETSI API](https://github.com/qursa-uc3m/qkd-etsi-api) implementation, which provides the interface for quantum key distribution operations according to ETSI standards.

Moreover, this project also requires [liboqs](https://github.com/open-quantum-safe/liboqs) and [OpenSSL](https://github.com/openssl/openssl).

This project has been successfully tested with the following dependencies and environment:

- liboqs: 0.12.0
- OpenSSL: 3.4.0
- Ubuntu: 24.04.1 LTS (Noble) and Ubuntu 22.04.5 LTS both with kernel 6.8.0-51-generic.

## Installation

### Installing the QKD ETSI API

```bash
git clone https://github.com/qursa-uc3m/qkd-etsi-api
cd qkd-etsi-api
mkdir build
cd build
cmake -DENABLE_ETSI004=OFF -DENABLE_ETSI014=ON -DQKD_BACKE
ND=simulated -DBUILD_TESTS=ON ..
make
sudo make install
```

### Building the QKD-KEM Benchmarks utility

We support three approaches to build the project (work in progress):

#### 1. Using System OpenSSL installation

If you have OpenSSL > 3.0 installed in your system (typically in ```/usr/local```):

```
export OPENSSL_INSTALL=/usr/local
./scripts/fullbuild.sh -F  # For first build or full rebuild
./scripts/fullbuild.sh -f  # For subsequent builds
```

Or replace ```/usr/local``` by your local installation path. 

#### 2. Self-contained build

This approach builds OpenSSL locally within the project directory. You just need to specify the OpenSSL branch (>3.0):

```
export OPENSSL_BRANCH=openssl-3.4.0  # Or your preferred version
./scripts/fullbuild.sh -F            # This will download and build all dependencies
./scripts/fullbuild.sh -f            # For subsequent builds
```

#### 3. Manual Installation of Dependencies

First install OpenSSL and oqs-provider using the provided scripts:

```bash
# Install OpenSSL
./scripts/install_openssl3.sh

# Install oqs-provider
./scripts/install_oqsprovider.sh
```

The scripts install OpenSSL `openssl-3.4.0` and oqs-provider `0.8.0` to `/opt/oqs_openssl3`. Use `-p` flag to specify a different installation path.

Then build the QKD-KEM provider by cloning the repository and building the project:

```bash
git clone https://github.com/qursa-uc3m/qkd-kem-provider
cd qkd-kem-provider
```

To build the provider for the first time run

```bash
export LIBOQS_BRANCH="0.12.0"
./scripts/fullbuild.sh -F  # First build. Downloads and builds all
./scripts/fullbuild.sh -f  # Subsequent builds.
```

## Build Options and Environment Variables

The build process can be customized using various environment variables

```
# Specify liboqs version/branch
export LIBOQS_BRANCH="0.12.0"        # Use specific liboqs version
export LIBOQS_BRANCH="main"          # Use latest development version

# Control OpenSSL installation
export OPENSSL_BRANCH="openssl-3.4.0" # Use specific OpenSSL version
export OPENSSL_INSTALL="/custom/path" # Use existing OpenSSL installation

# Build parameters
export CMAKE_PARAMS="-DCMAKE_BUILD_TYPE=Debug"  # Enable debug build
export MAKE_PARAMS="-j4"                        # Parallel build with 4 cores
export OQSPROV_CMAKE_PARAMS="-DNOPUBKEY_IN_PRIVKEY=ON"  # Additional provider options

# Algorithm selection
export OQS_ALGS_ENABLED="STD"        # Only include NIST standardized algorithms
```

### Build Flags explained

- `-F`: Full clean build. Removes and rebuilds all dependencies including OpenSSL and liboqs. 
- `-f`: Soft clean build. Only rebuilds the providers while preserving dependencies. 

### Build Output and Dependencies Location

The build process creates:
- `_build/lib/qkdkemprovider.so`: The QKD-KEM provider
- `_build/lib/oqsprovider.so`: The standard OQS provider
- `_build/bin/oqs_bench_kems`: The benchmarking utility

Dependencies are located as follows:

1. Using System OpenSSL (Approach 1):
   - OpenSSL: Uses system installation from `/usr/local`
   - liboqs: Built and installed in `/.local`
   - QKD ETSI API: Uses system installation from `/usr/local`

2. Self-contained Build (Approach 2):
   - OpenSSL: Built and installed in `/.local`
   - liboqs: Built and installed in `/.local`
   - QKD ETSI API: Uses system installation from `/usr/local`

3. Manual Installation (Approach 3):
   - OpenSSL: Uses specified path (default: `/opt/oqs_openssl3`)
   - liboqs: Built and installed in `/.local`
   - QKD ETSI API: Uses system installation from `/usr/local`

Note: The QKD ETSI API is always required as a system installation in `/usr/local` 

## Testing and Benchmarking

### Running Benchmarks
The project includes a benchmarking utility that can evaluate both the QKD-KEM provider and the standard OQS provider. Run the benchmarks using the provided script:

```bash
./scripts/run_qkd_kem_bench.sh [OPTIONS]
```

Available options are
- `-b, --bench N`: Run bechmarks with N iterations (required).
- `-p, --provider P`: Choose provider to benchmark (`qkdkemprovider` or `oqs`, defaults to `qkdkemprovider`).
- `-h, --help`: Show help message.

Examples:

```bash
# Run 1000 iterations with QKD-KEM provider (default)
./scripts/run_qkd_kem_bench.sh -b 100

# Run 500 iterations with standard OQS provider
./scripts/run_qkd_kem_bench.sh -b 50 -p oqs
```

### Benchmark output

The benchmark utility generates CSV files in the `benchmarks/data` directory containing timing measurements for the KEM relevant operations:
- Key generation time
- Encapsulation time
- Decapsulation time

For visualization and analysis instructions, see the documentation in the `benchmarks` directory. 




