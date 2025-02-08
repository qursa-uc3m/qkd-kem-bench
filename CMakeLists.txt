if (WIN32)
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)
else()
cmake_minimum_required(VERSION 3.5 FATAL_ERROR)
endif()

project(qkd-kem-provider LANGUAGES C)

set(OQSPROVIDER_VERSION_TEXT "0.1.0-dev")
set(CMAKE_C_STANDARD 11)
set_property(GLOBAL PROPERTY FIND_LIBRARY_USE_LIB64_PATHS ON)
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    message(STATUS "Creating Debug build with OQS-Debug env vars enabled")
else()
    message(STATUS "Creating Release build")
    add_definitions( -DNDEBUG )
endif()

if(MSVC)
  set(CMAKE_EXE_LINKER_FLAGS
      "${CMAKE_EXE_LINKER_FLAGS} /NODEFAULTLIB:LIBCMT")
  add_definitions(-DOQS_PROVIDER_NOATOMIC)
  add_definitions(-D_CRT_SECURE_NO_WARNINGS)
  set(OQS_ADDL_SOCKET_LIBS ws2_32.lib gdi32.lib crypt32.lib)
else()
  add_compile_options(-Wunused-function)
  set(OQS_ADDL_SOCKET_LIBS "")
endif()

option(OQS_KEM_ENCODERS "Provide encoders (and decoders) for KEM algorithms " OFF)
if(${OQS_KEM_ENCODERS})
    message(STATUS "Build provides support for encoding KEMs")
    add_compile_definitions( OQS_KEM_ENCODERS )
endif()

option(NOPUBKEY_IN_PRIVKEY "Do not include public keys in private key structures/PKCS#8 " OFF)
if(${NOPUBKEY_IN_PRIVKEY})
    message(STATUS "Build will not store public keys alongside private keys in PKCS#8 structures")
    add_compile_definitions( NOPUBKEY_IN_PRIVKEY )
else()
    message(STATUS "Build will store public keys in PKCS#8 structures")
endif()

option(OQS_PROVIDER_BUILD_STATIC "Build a static library instead of a shared library" OFF)
if(OQS_PROVIDER_BUILD_STATIC AND BUILD_SHARED_LIBS)
  message(FATAL_ERROR "`OQS_PROVIDER_BUILD_STATIC` is not compatible with `BUILD_SHARED_LIBS`.")
endif()

include(CheckLibraryExists)
include(CheckFunctionExists)

# Add required includes and install locations for openssl
find_package(OpenSSL 3.0 REQUIRED)
include_directories(${OPENSSL_INCLUDE_DIR})
if (WIN32)
# get_filename_component seems to fail when facing windows paths
# so use new(er) cmake_path instruction there
cmake_path(GET OPENSSL_CRYPTO_LIBRARY PARENT_PATH OQS_MODULES_PARENT_PATH)
cmake_path(APPEND OQS_MODULES_PARENT_PATH "ossl-modules" OUTPUT_VARIABLE OPENSSL_MODULES_PATH)
else()
get_filename_component(OPENSSL_LIB_DIR ${OPENSSL_CRYPTO_LIBRARY} DIRECTORY)
set(OPENSSL_MODULES_PATH ${OPENSSL_LIB_DIR}/ossl-modules)
endif()

# Add required include for liboqs
find_package(liboqs REQUIRED)
get_target_property(LIBOQS_INCLUDE_DIR OQS::oqs INTERFACE_INCLUDE_DIRECTORIES)
get_target_property(LIBOQS_LIBRARY_TYPE OQS::oqs TYPE)
message(STATUS "liboqs found: Include dir at ${LIBOQS_INCLUDE_DIR} (${LIBOQS_LIBRARY_TYPE})")
include_directories(${LIBOQS_INCLUDE_DIR})

# Add required include for qkd-etsi-api
find_library(QKD_ETSI_API_LIB NAMES qkd-etsi-api PATHS /usr/local/lib REQUIRED)
include_directories(/usr/local/include/qkd-etsi-api)
message(STATUS "QKD ETSI API found: ${QKD_ETSI_API_LIB}")

# Hints the compiler on the fact that the provider is being compiled into a static library.
#function(targets_set_static_provider)
#  foreach(target ${ARGN})
#    target_compile_definitions(${target} PRIVATE "OQS_PROVIDER_STATIC")
#    if(NOT target STREQUAL qkdkemprovider)
#      target_link_libraries(${target} PRIVATE qkdkemprovider)
#    endif()
#  endforeach()
#endfunction()

# Add the provider library
include(FetchContent)

# QDK-KEM-Provider
# Check build type from environment
if(DEFINED ENV{LOCAL_BUILD})
    message(STATUS "Using local QKD provider source")
    # Use existing source in _build/_deps
    set(OQSPROV_QKD_SOURCE "${CMAKE_BINARY_DIR}/_deps/oqsprov_qkd-src")
else()
    # Normal FetchContent build
    FetchContent_Declare(
        oqsprov_qkd
        GIT_REPOSITORY https://github.com/qursa-uc3m/qkd-kem-provider.git
        GIT_TAG qukaydee
    )
    # Make the QKD Provider content available
    FetchContent_GetProperties(oqsprov_qkd)
    if(NOT oqsprov_qkd_POPULATED)
        FetchContent_Populate(oqsprov_qkd)
    endif()
    set(OQSPROV_QKD_SOURCE ${oqsprov_qkd_SOURCE_DIR})
endif()

# OQS Provider (standard version)
FetchContent_Declare(
    oqsprov_base
    GIT_REPOSITORY https://github.com/open-quantum-safe/oqs-provider.git
    GIT_TAG 0.8.0  # Specific release version for stability
)

# Make the base OQS provider content available
FetchContent_GetProperties(oqsprov_base)
if(NOT oqsprov_base_POPULATED)
    FetchContent_Populate(oqsprov_base)
endif()

# Set output directories
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# QKD provider will generate qkdkemprovider.so
add_subdirectory(${OQSPROV_QKD_SOURCE}/oqsprov ${CMAKE_BINARY_DIR}/qkdprov)

# Base provider will generate oqsprovider.so
add_subdirectory(${oqsprov_base_SOURCE_DIR}/oqsprov ${CMAKE_BINARY_DIR}/oqsprov)

# Add testing - now the benchmark will be built after the provider
include(CTest)
enable_testing()
add_subdirectory(test)
