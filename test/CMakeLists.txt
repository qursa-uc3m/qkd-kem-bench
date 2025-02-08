if(NOT BUILD_TESTING)
  return()
endif()

include(GNUInstallDirs)
include(FindPkgConfig)

# Find QKD ETSI API
find_library(QKD_ETSI_API_LIB 
    NAMES qkd-etsi-api
    PATHS /usr/local/lib
    REQUIRED
)

# Check for local build
if(DEFINED ENV{LOCAL_BUILD})
    # Use local headers
    include_directories(
        ${CMAKE_BINARY_DIR}/_deps/oqsprov_qkd-src/oqsprov
    )
endif()

if (CMAKE_GENERATOR MATCHES "Visual Studio")
set(OQS_PROV_BINARY_DIR ${CMAKE_BINARY_DIR}/lib/${CMAKE_BUILD_TYPE})
else()
set(OQS_PROV_BINARY_DIR ${CMAKE_BINARY_DIR}/lib)
endif()

# KEM Benchmark test
add_executable(oqs_bench_kems oqs_bench_kems.c test_common.c)
target_link_libraries(oqs_bench_kems 
  PRIVATE 
  ${OPENSSL_CRYPTO_LIBRARY} 
  ${OQS_ADDL_SOCKET_LIBS}
  )
add_dependencies(oqs_bench_kems qkdkemprovider)  # Add dependency here where the target exists

# QKD ETSI API test
# add_executable(test_oqs_qkd_etsi_wrapper test_oqs_qkd_etsi_wrapper.c test_common.c)
# target_link_libraries(test_oqs_qkd_etsi_wrapper 
#  PRIVATE 
#  ${QKD_ETSI_API_LIB}
#  ${OPENSSL_CRYPTO_LIBRARY}
#  json-c
#  curl
#  ${OQS_ADDL_SOCKET_LIBS}
#)
# add_dependencies(test_oqs_qkd_etsi_wrapper qkdkemprovider)

if (MSVC)
    set_target_properties(oqs_bench_kems 
    ENVIRONMENT "OPENSSL_MODULES=${OQS_PROV_BINARY_DIR};OPENSSL_CONF=${CMAKE_CURRENT_SOURCE_DIR}/openssl-ca.cnf"
    )
    #set_target_properties(test_oqs_qkd_etsi_wrapper
    #ENVIRONMENT "OPENSSL_MODULES=${OQS_PROV_BINARY_DIR};OPENSSL_CONF=${CMAKE_CURRENT_SOURCE_DIR}/openssl-ca.cnf"
    #)
endif()

if (OQS_PROVIDER_BUILD_STATIC)
  targets_set_static_provider(oqs_bench_kems)
  #targets_set_static_provider(test_oqs_qkd_etsi_wrapper)
endif()
