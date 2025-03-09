FROM ubuntu:22.04 as intermediate

# Build arguments
ARG BASEDIR="/opt"
ARG MAKE_DEFINES="-j 20"
ARG OPENSSL_BRANCH="openssl-3.4.0"
ARG LIBOQS_BRANCH="main"
ARG OQSPROV_BRANCH="0.8.0"
ARG QKDKEMPROV_BRANCH="main"
ARG QKD_ETSI_API_BRANCH="main"
ARG QKD_BACKEND=qukaydee

# Environment setup
ENV OPENSSL_INSTALL="${BASEDIR}/.local"
ENV QKD_BACKEND=${QKD_BACKEND}
ENV ACCOUNT_ID=${ACCOUNT_ID}
ENV PROJECT_DIR="${BASEDIR}"

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential libcurl4-openssl-dev pkg-config libjansson-dev \
    libtool automake autoconf cmake ninja-build \
    make curl net-tools iputils-ping python3 python3-pip \
    openssl libssl-dev \
    git wget libpcre3-dev uuid-dev

# Clone required repositories
WORKDIR ${BASEDIR}
RUN git clone --depth 1 --branch ${LIBOQS_BRANCH} https://github.com/open-quantum-safe/liboqs.git && \
    git clone --depth 1 --branch ${OPENSSL_BRANCH} https://github.com/openssl/openssl.git && \
    git clone --depth 1 --branch ${QKD_ETSI_API_BRANCH} https://github.com/qursa-uc3m/qkd-etsi-api.git && \
    git clone --depth 1 --branch ${OQSPROV_BRANCH} https://github.com/open-quantum-safe/oqs-provider.git && \
    git clone --depth 1 --branch ${QKDKEMPROV_BRANCH} https://github.com/qursa-uc3m/qkd-kem-provider.git && \
    git clone --depth 1 --branch v1.64.0 https://github.com/nghttp2/nghttp2.git 

# Set up directory structure exactly as expected by oqs_env.sh
RUN mkdir -p ${BASEDIR}/.local
RUN mkdir -p ${BASEDIR}/_build/lib
RUN mkdir -p ${BASEDIR}/scripts
RUN mkdir -p ${BASEDIR}/qkd_certs
RUN mkdir -p ${BASEDIR}/tests

# Copy scripts and configs
COPY scripts/openssl-ca.cnf ${BASEDIR}/scripts/
COPY scripts/oqs_env.sh ${BASEDIR}/scripts/

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
    bash -c '. ${BASEDIR}/scripts/oqs_env.sh'

# Build nghttp2 with h2load
WORKDIR ${BASEDIR}/nghttp2
RUN autoreconf -i && \
    automake && \
    autoconf && \
    . ${BASEDIR}/scripts/oqs_env.sh && \
    ./configure && \
    make ${MAKE_DEFINES} && \
    make install

FROM ubuntu:22.04

ARG BASEDIR="/opt"
ARG ACCOUNT_ID="2507"
ARG QKD_BACKEND="cerberis-xgr"
ARG OPENSSL_INSTALL="${BASEDIR}/.local"
ARG PROJECT_DIR="${BASEDIR}"
ARG OPENSSL_CONF="${PROJECT_DIR}/scripts/openssl-ca.cnf"
ARG OPENSSL_MODULES="${BASEDIR}/_build/lib"
ARG PATH="${OPENSSL_INSTALL}/bin:$PATH"
ARG LD_LIBRARY_PATH="${OPENSSL_INSTALL}/lib64:${OPENSSL_INSTALL}/lib:$LD_LIBRARY_PATH"

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash libstdc++6 libev-dev curl libcurl4-openssl-dev zlib1g-dev \
    libc-ares2 libjansson-dev util-linux && \
    rm -rf /var/lib/apt/lists/*


# Copy required files from intermediate stage
COPY --from=intermediate /usr/local/bin/h2load /usr/local/bin/
COPY --from=intermediate ${BASEDIR}/.local ${BASEDIR}/.local
COPY --from=intermediate ${BASEDIR}/scripts ${BASEDIR}/scripts
COPY --from=intermediate ${BASEDIR}/_build ${BASEDIR}/_build
COPY --from=intermediate ${BASEDIR}/qkd-etsi-api/build/libqkd-etsi-api.so ${BASEDIR}/.local/lib64/
COPY --from=intermediate ${BASEDIR}/tests ${BASEDIR}/tests

# Make certificates executable
# RUN chmod +x ${BASEDIR}/qkd_certs/*.pem ${BASEDIR}/qkd_certs/*.key ${BASEDIR}/qkd_certs/*.crt

# Set environment variables for runtime
ENV QKD_BACKEND=${QKD_BACKEND}
ENV ACCOUNT_ID=${ACCOUNT_ID}
ENV OPENSSL_INSTALL=${OPENSSL_INSTALL}
ENV PROJECT_DIR=${PROJECT_DIR}
ENV OPENSSL_CONF=${OPENSSL_CONF}
ENV OPENSSL_MODULES=${OPENSSL_MODULES}
ENV PATH=${PATH}
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}

RUN pip3 install flask requests h2

RUN mkdir -p /opt/webapp

COPY containers/qkd-web-client/webapp/ /opt/webapp/
WORKDIR /opt/webapp

CMD ["python3", "app.py"]