if(NOT BUILD_TESTING)
  return()
endif()

include(GNUInstallDirs)

if (CMAKE_GENERATOR MATCHES "Visual Studio")
set(OQS_PROV_BINARY_DIR ${CMAKE_BINARY_DIR}/lib/${CMAKE_BUILD_TYPE})
else()
set(OQS_PROV_BINARY_DIR ${CMAKE_BINARY_DIR}/lib)
endif()


add_executable(oqs_bench_kems oqs_bench_kems.c test_common.c)
target_link_libraries(oqs_bench_kems PRIVATE ${OPENSSL_CRYPTO_LIBRARY} ${OQS_ADDL_SOCKET_LIBS})
add_dependencies(oqs_bench_kems qkdkemprovider)  # Add dependency here where the target exists

if (MSVC)
    set_target_properties(oqs_bench_kems 
    ENVIRONMENT "OPENSSL_MODULES=${OQS_PROV_BINARY_DIR};OPENSSL_CONF=${CMAKE_CURRENT_SOURCE_DIR}/openssl-ca.cnf"
    )
endif()

if (OQS_PROVIDER_BUILD_STATIC)
  targets_set_static_provider(oqs_bench_kems)
endif()
