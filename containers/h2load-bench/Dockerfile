FROM alpine:latest as intermediate

# Build arguments
ARG BASEDIR="/opt"
ARG MAKE_DEFINES="-j 18"
ARG OPENSSL_BRANCH="openssl-3.4.0"
ARG LIBOQS_BRANCH="main"
ARG OQSPROV_BRANCH="0.8.0"
ARG QKDKEMPROV_BRANCH="main"
ARG QKD_ETSI_API_BRANCH="main"
ARG QKD_BACKEND=cerberis-xgr

# Environment setup
ENV DEBIAN_FRONTEND=noninteractive
ENV OPENSSL_INSTALL="${BASEDIR}/.local"
ENV QKD_BACKEND=${QKD_BACKEND}

# Install dependencies
RUN apk add --no-cache bash git g++ make cmake ninja autoconf automake libtool \
    libev-dev libevent-dev openssl-dev openssl zlib c-ares-dev pkgconfig \
    linux-headers zlib-dev jansson-dev util-linux-dev

# Clone required repositories
WORKDIR ${BASEDIR}
RUN git clone --depth 1 --branch ${LIBOQS_BRANCH} https://github.com/open-quantum-safe/liboqs.git && \
    git clone --depth 1 --branch ${OPENSSL_BRANCH} https://github.com/openssl/openssl.git && \
    git clone --depth 1 --branch ${QKD_ETSI_API_BRANCH} https://github.com/qursa-uc3m/qkd-etsi-api.git && \
    git clone --depth 1 --branch ${OQSPROV_BRANCH} https://github.com/open-quantum-safe/oqs-provider.git && \
    git clone --depth 1 --branch ${QKDKEMPROV_BRANCH} https://github.com/qursa-uc3m/qkd-kem-provider.git && \
    git clone --depth 1 --branch v1.56.0 https://github.com/nghttp2/nghttp2.git 
    

# Set up directory structure exactly as expected by oqs_env.sh
RUN mkdir -p ${BASEDIR}/.local
RUN mkdir -p ${BASEDIR}/_build/lib
RUN mkdir -p ${BASEDIR}/scripts
RUN mkdir -p ${BASEDIR}/qkd_certs

# Copy scripts and configs
COPY scripts/openssl-ca.cnf ${BASEDIR}/scripts/
COPY scripts/oqs_env.sh ${BASEDIR}/scripts/
COPY scripts/generate_certs.sh ${BASEDIR}/scripts/

# Build liboqs
WORKDIR ${BASEDIR}/liboqs
RUN mkdir build && cd build && \
    cmake -G"Ninja" -DCMAKE_INSTALL_PREFIX=${OPENSSL_INSTALL} .. && \
    ninja && ninja install

# Build OpenSSL
WORKDIR ${BASEDIR}/openssl
RUN LDFLAGS="-Wl,-rpath -Wl,${OPENSSL_INSTALL}/lib64" \
    ./config --prefix=${OPENSSL_INSTALL} && \
    make ${MAKE_DEFINES} && make install_sw install_ssldirs

# Build ETSI API
WORKDIR ${BASEDIR}/qkd-etsi-api
RUN mkdir -p build && \
    cd build && \
    cmake -DENABLE_ETSI004=OFF \
          -DENABLE_ETSI014=ON \
          -DQKD_BACKEND=${QKD_BACKEND} \
          -DBUILD_TESTS=OFF \
          -DOPENSSL_ROOT_DIR=${OPENSSL_INSTALL} \
          -DOPENSSL_LIBRARIES=${OPENSSL_INSTALL}/lib64 \
          .. && \
    make && \
    make install

# Build oqs-provider
WORKDIR ${BASEDIR}/oqs-provider
RUN mkdir build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DOPENSSL_ROOT_DIR=${OPENSSL_INSTALL} \
          -DCMAKE_PREFIX_PATH=${OPENSSL_INSTALL} \
          -S . -B build && \
    cmake --build build && \
    cp build/lib/oqsprovider.so ${BASEDIR}/_build/lib/

# Build qkd-kem-provider
WORKDIR /opt/qkd-kem-provider
RUN mkdir -p build && \
    cmake -DCMAKE_BUILD_TYPE=Release \ 
          -DOPENSSL_ROOT_DIR=${OPENSSL_INSTALL} \
          -DCMAKE_PREFIX_PATH=${OPENSSL_INSTALL} \ 
          -S . -B build && \
    cmake --build build && \
    cp build/lib/qkdkemprovider.so ${BASEDIR}/_build/lib/

# Source the environment script
WORKDIR ${BASEDIR}
RUN chmod +x ${BASEDIR}/scripts/oqs_env.sh && \
    . ${BASEDIR}/scripts/oqs_env.sh

# Generate certificates
RUN chmod +x ${BASEDIR}/scripts/generate_certs.sh && \
    . ${BASEDIR}/scripts/oqs_env.sh && \
    ${BASEDIR}/scripts/generate_certs.sh

# Build nghttp2 with h2load
WORKDIR ${BASEDIR}/nghttp2
RUN autoreconf -i && \
    automake && \
    autoconf && \
    . ${BASEDIR}/scripts/oqs_env.sh && \
    ./configure && \
    make ${MAKE_DEFINES} && \
    make install

FROM alpine:latest

ARG BASEDIR="/opt"
ARG QKD_BACKEND="simulated"

# Install runtime dependencies
RUN apk add --no-cache bash python3 py3-pandas py3-matplotlib py3-scipy libstdc++ libev curl-dev zlib c-ares jansson

# Copy required files from intermediate stage
COPY --from=intermediate /usr/local/bin/h2load /usr/local/bin/
COPY --from=intermediate ${BASEDIR}/.local ${BASEDIR}/.local
COPY --from=intermediate ${BASEDIR}/scripts ${BASEDIR}/scripts
COPY --from=intermediate ${BASEDIR}/_build ${BASEDIR}/_build
COPY --from=intermediate ${BASEDIR}/certs ${BASEDIR}/certs
COPY --from=intermediate ${BASEDIR}/qkd_certs ${BASEDIR}/qkd_certs

# Copy benchmarking scripts
COPY containers/h2load-bench/h2load-benchmarks.sh /usr/local/bin/
COPY containers/h2load-bench/check_algorithms.sh /usr/local/bin/
COPY containers/h2load-bench/benchmark_results_parser.py /usr/local/bin/
RUN chmod +x /usr/local/bin/h2load-benchmarks.sh /usr/local/bin/check_algorithms.sh

# Set environment variables for runtime
ENV QKD_BACKEND=${QKD_BACKEND}

# Create a wrapper script that sources the environment before running h2load
RUN echo '#!/bin/bash\n. /opt/scripts/oqs_env.sh\nexec h2load "$@"' > /usr/local/bin/h2load-wrapper && \
    chmod +x /usr/local/bin/h2load-wrapper

ENTRYPOINT ["/usr/local/bin/h2load-wrapper"]