FROM ubuntu:22.04 as intermediate

# Build arguments
ARG BASEDIR="/opt"
ARG INSTALLDIR="${BASEDIR}/nginx"
ARG NGINX_VERSION="1.23.3"
ARG DEFAULT_GROUPS="x25519:x448:kyber512:p256_kyber512:kyber768:p384_kyber768:kyber1024:p521_kyber1024"
ARG MAKE_DEFINES="-j 18"
ARG OSSLDIR="${BASEDIR}/openssl/.openssl"
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
RUN apt-get update && apt-get install -y \
    build-essential libcurl4-openssl-dev pkg-config libjansson-dev\
    libtool automake autoconf cmake ninja-build \
    make \
    openssl libssl-dev \
    git wget libpcre3-dev uuid-dev 

# Clone required repositories
WORKDIR ${BASEDIR}
RUN git clone --depth 1 --branch ${LIBOQS_BRANCH} https://github.com/open-quantum-safe/liboqs.git && \
    git clone --depth 1 --branch ${OPENSSL_BRANCH} https://github.com/openssl/openssl.git && \
    git clone --depth 1 --branch ${OQSPROV_BRANCH} https://github.com/open-quantum-safe/oqs-provider.git && \
    git clone --depth 1 --branch ${QKDKEMPROV_BRANCH} https://github.com/qursa-uc3m/qkd-kem-provider.git && \
    git clone --depth 1 --branch ${QKD_ETSI_API_BRANCH} https://github.com/qursa-uc3m/qkd-etsi-api.git

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
          -DCMAKE_PREFIX_PATH=${OPENSSL_INSTALL}\
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

# Source the environment script to ensure consistent environment
WORKDIR ${BASEDIR}
RUN chmod +x ${BASEDIR}/scripts/oqs_env.sh && \
    bash -c '. ${BASEDIR}/scripts/oqs_env.sh'

# Build NGINX with OpenSSL support
WORKDIR ${BASEDIR}
RUN wget nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar -zxf nginx-${NGINX_VERSION}.tar.gz && \
    cd nginx-${NGINX_VERSION} && \
    ./configure --prefix=${INSTALLDIR} \
                --with-debug \
                --with-http_ssl_module \ 
                --with-http_v2_module \
                --without-http_gzip_module \
                --with-cc-opt="-I${OPENSSL_INSTALL}/include" \
                --with-ld-opt="-L${OPENSSL_INSTALL}/lib64 -Wl,-rpath,${OPENSSL_INSTALL}/lib64" && \
    make ${MAKE_DEFINES} && make install

# Generate certificates
RUN chmod +x ${BASEDIR}/scripts/generate_certs.sh && \
    bash -c '. ${BASEDIR}/scripts/oqs_env.sh && \
    ${BASEDIR}/scripts/generate_certs.sh'

FROM ubuntu:22.04

ARG BASEDIR="/opt"
ARG INSTALLDIR="${BASEDIR}/nginx"
ARG DEFAULT_GROUPS=x25519:x448:kyber512:p256_kyber512:kyber768:p384_kyber768:kyber1024:p521_kyber1024
ARG QKD_BACKEND="cerberis-xgr"
ARG SSL_CERT_DIR="dilithium"
ARG SSL_CERT_TYPE="dilithium3"
ARG OPENSSL_INSTALL="${BASEDIR}/.local"
ARG PROJECT_DIR="/opt"
ARG OPENSSL_CONF="${PROJECT_DIR}/scripts/openssl-ca.cnf"
ARG OPENSSL_MODULES="${BASEDIR}/_build/lib"
ARG PATH="${OPENSSL_INSTALL}/bin:$PATH"
ARG LD_LIBRARY_PATH="${OPENSSL_INSTALL}/lib64:${OPENSSL_INSTALL}/lib:$LD_LIBRARY_PATH"
    
# Install runtime dependencies
RUN apt-get update && apt-get install -y libpcre3 libcurl4 libjansson4 && rm -rf /var/lib/apt/lists/*
    
# Copy built files from intermediate stage
COPY --from=intermediate ${INSTALLDIR} ${INSTALLDIR}
COPY --from=intermediate ${BASEDIR}/.local ${BASEDIR}/.local
COPY --from=intermediate ${BASEDIR}/scripts ${BASEDIR}/scripts
COPY --from=intermediate ${BASEDIR}/_build ${BASEDIR}/_build
COPY --from=intermediate ${BASEDIR}/qkd-etsi-api/build/libqkd-etsi-api.so ${BASEDIR}/.local/lib64/
COPY --from=intermediate ${BASEDIR}/certs ${BASEDIR}/certs
COPY --from=intermediate ${BASEDIR}/qkd_certs ${BASEDIR}/qkd_certs
    
# Copy external nginx config
COPY containers/nginx-server/config/nginx.conf ${INSTALLDIR}/conf/nginx.conf
COPY containers/nginx-server/config/start.sh /opt/start.sh

# Set environment variables for runtime
ENV DEFAULT_GROUPS=${DEFAULT_GROUPS}
ENV QKD_BACKEND=${QKD_BACKEND}
ENV SSL_CERT_DIR=${SSL_CERT_DIR}
ENV SSL_CERT_TYPE=${SSL_CERT_TYPE}
ENV OPENSSL_INSTALL=${OPENSSL_INSTALL}
ENV PROJECT_DIR=${PROJECT_DIR}
ENV OPENSSL_CONF=${OPENSSL_CONF}
ENV OPENSSL_MODULES=${OPENSSL_MODULES}
ENV PATH=${PATH}
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}

RUN chmod +x /opt/start.sh
    
EXPOSE 4433
    
CMD ["/opt/start.sh"]