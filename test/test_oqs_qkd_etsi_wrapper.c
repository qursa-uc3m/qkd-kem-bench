/*
 * Copyright (C) 2025 Daniel Sobral Blanco @dasobral (UC3M, QURSA project)
 */

/*
 * test_oqs_qkd_etsi_api_wrapper.c
 * Unit tests for QKD ETSI API wrapper functions
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <json-c/json.h>
#include "oqs_qkd_etsi_api_wrapper.h"
#include "test_common.h"

#include <qkd-etsi-api/qkd_etsi_api.h>
#ifdef ETSI_004_API
#include <qkd-etsi-api/etsi004/api.h>
#elif defined(ETSI_014_API)
#include <qkd-etsi-api/etsi014/api.h>
#endif

#include "oqs_qkd_etsi_api_wrapper.c"

// Mock responses for HTTPS requests
static const char *MOCK_STATUS_RESPONSE = 
    "{"
    "  \"stored_key_count\": 10,"
    "  \"max_key_count\": 100,"
    "  \"key_size\": 256"
    "}";

static const char *MOCK_KEY_RESPONSE = 
    "{"
    "  \"keys\": ["
    "    {"
    "      \"key_ID\": \"test-key-id-1\","
    "      \"key\": \"SGVsbG8gV29ybGQ=\"" // Base64 encoded test key
    "    }"
    "  ]"
    "}";

// Test fixture setup
static QKD_CTX *setup_test_ctx(bool is_initiator) {
    QKD_CTX *ctx = calloc(1, sizeof(QKD_CTX));
    assert(ctx != NULL);

    ctx->is_initiator = is_initiator;
    if (is_initiator) {
        ctx->source_uri = strdup(getenv("QKD_MASTER_KME_HOSTNAME"));
    } else {
        ctx->source_uri = strdup(getenv("QKD_SLAVE_KME_HOSTNAME"));
    }
    
    // Set mock environment variables for testing
    setenv("QKD_CA_CERT_PATH", "/tmp/ca.crt", 1);
    setenv("QKD_MASTER_CERT_PATH", "/tmp/master.crt", 1);
    setenv("QKD_MASTER_KEY_PATH", "/tmp/master.key", 1);
    setenv("QKD_SLAVE_CERT_PATH", "/tmp/slave.crt", 1);
    setenv("QKD_SLAVE_KEY_PATH", "/tmp/slave.key", 1);

    return ctx;
}

static void teardown_test_ctx(QKD_CTX *ctx) {
    if (ctx) {
        free(ctx->source_uri);
        free(ctx->dest_uri);
        if (ctx->key) EVP_PKEY_free(ctx->key);
        free(ctx);
    }
}

// Test cases
static void test_qkd_init_certificates(void) {
    printf("Testing qkd_init_certificates...\n");

    // Test initiator role
    QKD_CTX *ctx = setup_test_ctx(true);
    bool result = qkd_init_certificates(ctx);
    assert(result == true);
    assert(ctx->ca_cert_path != NULL);
    assert(ctx->client_cert_path != NULL);
    assert(ctx->client_key_path != NULL);
    teardown_test_ctx(ctx);

    // Test responder role
    ctx = setup_test_ctx(false);
    result = qkd_init_certificates(ctx);
    assert(result == true);
    assert(ctx->ca_cert_path != NULL);
    assert(ctx->client_cert_path != NULL);
    assert(ctx->client_key_path != NULL);
    teardown_test_ctx(ctx);

    printf("✓ qkd_init_certificates tests passed\n");
}

static void test_qkd_get_status(void) {
    printf("Testing qkd_get_status...\n");
    
    QKD_CTX *ctx = setup_test_ctx(true);
    ctx->master_kme_host = strdup("https://localhost:8080");
    ctx->slave_kme_host = strdup("https://localhost:8081");

    bool result = qkd_get_status(ctx);
    assert(result == true);
    assert(ctx->status.stored_key_count == 10);
    assert(ctx->status.max_key_count == 100);
    assert(ctx->status.key_size == 256);

    teardown_test_ctx(ctx);
    printf("✓ qkd_get_status tests passed\n");
}

static void test_qkd_get_key(void) {
    printf("Testing qkd_get_key...\n");

    // Test key retrieval via HTTPS
    QKD_CTX *ctx = setup_test_ctx(true);
    ctx->master_kme_host = strdup("https://localhost:8080");
    bool result = qkd_get_key(ctx);
    assert(result == true);
    assert(ctx->key != NULL);
    teardown_test_ctx(ctx);

    // Test key retrieval via URI
    ctx = setup_test_ctx(false);
    result = qkd_get_key(ctx);
    assert(result == true);
    assert(ctx->key != NULL);
    teardown_test_ctx(ctx);

    printf("✓ qkd_get_key tests passed\n");
}

static void test_qkd_get_key_with_ids(void) {
    printf("Testing qkd_get_key_with_ids...\n");

    QKD_CTX *ctx = setup_test_ctx(true);
    ctx->master_kme_host = strdup("https://localhost:8080");

    bool result = qkd_get_key_with_ids(ctx);
    assert(result == true);
    assert(ctx->key != NULL);

    teardown_test_ctx(ctx);
    printf("✓ qkd_get_key_with_ids tests passed\n");
}

#ifdef ETSI_004_API
static void test_qkd_open_close(void) {
    printf("Testing qkd_open/close...\n");

    QKD_CTX *ctx = setup_test_ctx(true);
    
    // Test connection open
    bool result = qkd_open(ctx);
    assert(result == true);
    assert(ctx->is_connected == true);

    // Test connection close
    result = qkd_close(ctx);
    assert(result == true);
    assert(ctx->is_connected == false);

    teardown_test_ctx(ctx);
    printf("✓ qkd_open/close tests passed\n");
}
#endif

// Error case tests
static void test_error_cases(void) {
    printf("Testing error cases...\n");

    // Test NULL context
    assert(qkd_get_status(NULL) == false);
    assert(qkd_get_key(NULL) == false);
    assert(qkd_get_key_with_ids(NULL) == false);
    assert(qkd_init_certificates(NULL) == false);

    // Test invalid URLs
    QKD_CTX *ctx = setup_test_ctx(true);
    ctx->master_kme_host = strdup("invalid://url");
    assert(qkd_get_key(ctx) == false);
    teardown_test_ctx(ctx);

    // Test missing certificates
    ctx = setup_test_ctx(true);
    unsetenv("QKD_CA_CERT_PATH");
    assert(qkd_init_certificates(ctx) == false);
    teardown_test_ctx(ctx);

    printf("✓ Error case tests passed\n");
}

// Main test runner
int main(void) {
    printf("\nRunning QKD ETSI API wrapper tests...\n\n");

    // Run test suite
    test_qkd_init_certificates();
    test_qkd_get_status();
    test_qkd_get_key();
    test_qkd_get_key_with_ids();
#ifdef ETSI_004_API
    test_qkd_open_close();
#endif
    test_error_cases();

    printf("\nAll tests completed successfully!\n");
    return 0;
}