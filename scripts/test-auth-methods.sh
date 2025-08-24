#!/bin/bash

# SSH Test Server - Authentication Methods Test Script
# Comprehensive testing of different SSH authentication methods

set -e

# Default values
SSH_HOST="localhost"
SSH_PORT="2224"
SSH_USER="testuser"
CONTAINER_NAME=""
TIMEOUT="10"
VERBOSE="false"
GENERATE_KEYS="false"
CLEANUP_KEYS="false"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Temporary files
TEMP_DIR=$(mktemp -d)
TEST_KEY="${TEMP_DIR}/test_key"
TEST_KEY_PUB="${TEST_KEY}.pub"

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Test different SSH authentication methods against SSH test server.

OPTIONS:
    -h, --host HOST           SSH server hostname or IP (default: localhost)
    -p, --port PORT           SSH server port (default: 2224)
    -u, --user USER           SSH username (default: testuser)
    -c, --container NAME      Docker container name to test against
    -t, --timeout SECONDS     Connection timeout (default: 10)
    -g, --generate-keys       Generate temporary SSH keys for testing
    -C, --cleanup-keys        Cleanup temporary keys after testing
    -v, --verbose             Enable verbose output
    --help                    Show this help message

EXAMPLES:
    # Test against running container
    $0 --container ssh-test-server --user testuser

    # Test with key generation
    $0 --host localhost --port 2224 --user testuser --generate-keys

    # Test with verbose output
    $0 --container ssh-test-server --user testuser --verbose

    # Full test with cleanup
    $0 --container ssh-test-server --user testuser --generate-keys --cleanup-keys

EOF
}

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [[ "${VERBOSE}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Cleanup function
cleanup() {
    if [[ "${CLEANUP_KEYS}" == "true" ]] && [[ -d "${TEMP_DIR}" ]]; then
        log_debug "Cleaning up temporary files..."
        rm -rf "${TEMP_DIR}"
    fi
}

# Set up cleanup trap
trap cleanup EXIT

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--host)
                SSH_HOST="$2"
                shift 2
                ;;
            -p|--port)
                SSH_PORT="$2"
                shift 2
                ;;
            -u|--user)
                SSH_USER="$2"
                shift 2
                ;;
            -c|--container)
                CONTAINER_NAME="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -g|--generate-keys)
                GENERATE_KEYS="true"
                shift
                ;;
            -C|--cleanup-keys)
                CLEANUP_KEYS="true"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Check dependencies
check_dependencies() {
    log_debug "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v ssh >/dev/null 2>&1; then
        missing_deps+=("ssh")
    fi
    
    if ! command -v ssh-keygen >/dev/null 2>&1; then
        missing_deps+=("ssh-keygen")
    fi
    
    if ! command -v sshpass >/dev/null 2>&1; then
        log_warn "sshpass not found - password authentication tests will be limited"
    fi
    
    if [[ -n "${CONTAINER_NAME}" ]] && ! command -v docker >/dev/null 2>&1; then
        missing_deps+=("docker")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
    
    log_debug "Dependencies check completed"
}

# Generate test SSH keys
generate_test_keys() {
    if [[ "${GENERATE_KEYS}" != "true" ]]; then
        return 0
    fi
    
    log_info "Generating test SSH keys..."
    
    # Generate different types of keys
    local key_types=(
        "rsa:2048:RSA 2048-bit"
        "rsa:4096:RSA 4096-bit"
        "ed25519::Ed25519"
        "ecdsa:256:ECDSA 256-bit"
    )
    
    for key_type_info in "${key_types[@]}"; do
        local key_type="${key_type_info%%:*}"
        local key_size="${key_type_info#*:}"
        key_size="${key_size%%:*}"
        local key_desc="${key_type_info##*:}"
        
        local key_file="${TEMP_DIR}/test_${key_type}${key_size:+_${key_size}}_key"
        
        log_debug "Generating ${key_desc} key: ${key_file}"
        
        local ssh_keygen_args=(-t "${key_type}" -f "${key_file}" -N "" -C "test-${key_type}@ssh-test-server")
        
        if [[ -n "${key_size}" ]]; then
            ssh_keygen_args+=(-b "${key_size}")
        fi
        
        if ssh-keygen "${ssh_keygen_args[@]}" >/dev/null 2>&1; then
            log_debug "  ✅ Generated ${key_desc} key"
        else
            log_warn "  ⚠️  Failed to generate ${key_desc} key"
        fi
    done
    
    log_info "Test key generation completed"
}

# Get container environment variable
get_container_env() {
    local var_name="$1"
    
    if [[ -z "${CONTAINER_NAME}" ]]; then
        return 1
    fi
    
    docker inspect "${CONTAINER_NAME}" --format '{{range .Config.Env}}{{println .}}{{end}}' | \
        grep "^${var_name}=" | cut -d'=' -f2- || true
}

# Test password authentication scenarios
test_password_authentication() {
    log_info "Testing password authentication scenarios..."
    
    local password
    if [[ -n "${CONTAINER_NAME}" ]]; then
        password=$(get_container_env "SSH_PASSWORD")
    fi
    
    if [[ -z "${password}" ]]; then
        log_warn "No password available for testing"
        return 0
    fi
    
    local scenarios=(
        "valid-password:${password}:Valid password"
        "invalid-password:wrongpassword:Invalid password (should fail)"
        "empty-password::Empty password (should fail)"
    )
    
    for scenario in "${scenarios[@]}"; do
        local test_name="${scenario%%:*}"
        local test_password="${scenario#*:}"
        test_password="${test_password%%:*}"
        local test_desc="${scenario##*:}"
        
        log_debug "Testing: ${test_desc}"
        
        if [[ ! command -v sshpass >/dev/null 2>&1 ]]; then
            log_warn "  ⏭️  Skipping ${test_name} (sshpass not available)"
            continue
        fi
        
        local ssh_opts=(
            -o ConnectTimeout="${TIMEOUT}"
            -o StrictHostKeyChecking=no
            -o UserKnownHostsFile=/dev/null
            -o PasswordAuthentication=yes
            -o PubkeyAuthentication=no
            -o PreferredAuthentications=password
            -o NumberOfPasswordPrompts=1
        )
        
        if [[ "${VERBOSE}" == "true" ]]; then
            ssh_opts+=(-v)
        fi
        
        local expected_result="fail"
        if [[ "${test_name}" == "valid-password" ]]; then
            expected_result="pass"
        fi
        
        if [[ -n "${test_password}" ]]; then
            sshpass -p "${test_password}" ssh "${ssh_opts[@]}" \
                -p "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}" \
                "echo 'Auth successful'" >/dev/null 2>&1
        else
            # For empty password, we can't really test this properly with sshpass
            log_debug "  ⏭️  Skipping empty password test (not feasible with sshpass)"
            continue
        fi
        
        local result=$?
        
        if [[ "${expected_result}" == "pass" ]] && [[ $result -eq 0 ]]; then
            log_debug "  ✅ ${test_desc}: PASS (as expected)"
        elif [[ "${expected_result}" == "fail" ]] && [[ $result -ne 0 ]]; then
            log_debug "  ✅ ${test_desc}: FAIL (as expected)"
        elif [[ "${expected_result}" == "pass" ]] && [[ $result -ne 0 ]]; then
            log_warn "  ❌ ${test_desc}: FAIL (unexpected)"
        else
            log_warn "  ⚠️  ${test_desc}: PASS (unexpected)"
        fi
    done
}

# Test public key authentication scenarios
test_pubkey_authentication() {
    log_info "Testing public key authentication scenarios..."
    
    if [[ "${GENERATE_KEYS}" != "true" ]]; then
        log_warn "Key generation disabled, skipping public key authentication tests"
        return 0
    fi
    
    # Get authorized keys from container if available
    local container_authorized_keys=""
    if [[ -n "${CONTAINER_NAME}" ]]; then
        container_authorized_keys=$(get_container_env "SSH_AUTHORIZED_KEYS")
    fi
    
    # Find generated key files
    local key_files=()
    while IFS= read -r -d '' key_file; do
        if [[ "${key_file}" == *.pub ]]; then
            continue  # Skip public key files
        fi
        key_files+=("${key_file}")
    done < <(find "${TEMP_DIR}" -name "*_key" -type f -print0 2>/dev/null || true)
    
    if [[ ${#key_files[@]} -eq 0 ]]; then
        log_warn "No private key files found for testing"
        return 0
    fi
    
    for key_file in "${key_files[@]}"; do
        local key_name
        key_name=$(basename "${key_file}")
        
        log_debug "Testing key: ${key_name}"
        
        local ssh_opts=(
            -o ConnectTimeout="${TIMEOUT}"
            -o StrictHostKeyChecking=no
            -o UserKnownHostsFile=/dev/null
            -o PasswordAuthentication=no
            -o PubkeyAuthentication=yes
            -o PreferredAuthentications=publickey
            -i "${key_file}"
        )
        
        if [[ "${VERBOSE}" == "true" ]]; then
            ssh_opts+=(-v)
        fi
        
        if ssh "${ssh_opts[@]}" \
            -p "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}" \
            "echo 'Pubkey auth successful'" >/dev/null 2>&1; then
            log_debug "  ✅ ${key_name}: Authentication successful"
        else
            log_debug "  ❌ ${key_name}: Authentication failed (expected if key not authorized)"
        fi
    done
}

# Test authentication method restrictions
test_auth_method_restrictions() {
    log_info "Testing authentication method restrictions..."
    
    if [[ -z "${CONTAINER_NAME}" ]]; then
        log_warn "No container specified, skipping auth method restriction tests"
        return 0
    fi
    
    local permit_password
    local permit_pubkey
    local permit_keyboard_interactive
    
    permit_password=$(get_container_env "SSH_PERMIT_PASSWORD_AUTH")
    permit_pubkey=$(get_container_env "SSH_PERMIT_PUBKEY_AUTH")
    permit_keyboard_interactive=$(get_container_env "SSH_CHALLENGE_RESPONSE_AUTH")
    
    log_debug "Auth method configuration:"
    log_debug "  Password: ${permit_password:-unknown}"
    log_debug "  Public Key: ${permit_pubkey:-unknown}"
    log_debug "  Keyboard-Interactive: ${permit_keyboard_interactive:-unknown}"
    
    # Test password authentication when disabled
    if [[ "${permit_password}" == "no" ]]; then
        log_debug "Testing password auth when disabled..."
        local password
        password=$(get_container_env "SSH_PASSWORD")
        
        if [[ -n "${password}" ]] && command -v sshpass >/dev/null 2>&1; then
            if sshpass -p "${password}" ssh \
                -o ConnectTimeout="${TIMEOUT}" \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -o PasswordAuthentication=yes \
                -o PubkeyAuthentication=no \
                -o PreferredAuthentications=password \
                -p "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}" \
                "echo 'Should not work'" >/dev/null 2>&1; then
                log_warn "  ⚠️  Password auth succeeded when it should be disabled"
            else
                log_debug "  ✅ Password auth correctly rejected when disabled"
            fi
        fi
    fi
    
    # Test public key authentication when disabled
    if [[ "${permit_pubkey}" == "no" ]] && [[ "${GENERATE_KEYS}" == "true" ]]; then
        log_debug "Testing pubkey auth when disabled..."
        
        local test_key_file="${TEMP_DIR}/test_rsa_key"
        if [[ -f "${test_key_file}" ]]; then
            if ssh \
                -o ConnectTimeout="${TIMEOUT}" \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -o PasswordAuthentication=no \
                -o PubkeyAuthentication=yes \
                -o PreferredAuthentications=publickey \
                -i "${test_key_file}" \
                -p "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}" \
                "echo 'Should not work'" >/dev/null 2>&1; then
                log_warn "  ⚠️  Pubkey auth succeeded when it should be disabled"
            else
                log_debug "  ✅ Pubkey auth correctly rejected when disabled"
            fi
        fi
    fi
}

# Test SSH server security configuration
test_security_configuration() {
    log_info "Testing SSH server security configuration..."
    
    if [[ -z "${CONTAINER_NAME}" ]]; then
        log_warn "No container specified, skipping security configuration tests"
        return 0
    fi
    
    local permit_root_login
    local max_auth_tries
    local permit_empty_passwords
    
    permit_root_login=$(get_container_env "SSH_PERMIT_ROOT_LOGIN")
    max_auth_tries=$(get_container_env "SSH_MAX_AUTH_TRIES")
    permit_empty_passwords=$(get_container_env "SSH_PERMIT_EMPTY_PASSWORDS")
    
    log_debug "Security configuration:"
    log_debug "  Root Login: ${permit_root_login:-unknown}"
    log_debug "  Max Auth Tries: ${max_auth_tries:-unknown}"
    log_debug "  Empty Passwords: ${permit_empty_passwords:-unknown}"
    
    # Test root login restriction
    if [[ "${permit_root_login}" == "no" ]]; then
        log_debug "Testing root login restriction..."
        
        local password
        password=$(get_container_env "SSH_PASSWORD")
        
        if [[ -n "${password}" ]] && command -v sshpass >/dev/null 2>&1; then
            if sshpass -p "${password}" ssh \
                -o ConnectTimeout="${TIMEOUT}" \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -o PasswordAuthentication=yes \
                -o PreferredAuthentications=password \
                -p "${SSH_PORT}" "root@${SSH_HOST}" \
                "echo 'Root login should not work'" >/dev/null 2>&1; then
                log_warn "  ⚠️  Root login succeeded when it should be disabled"
            else
                log_debug "  ✅ Root login correctly rejected"
            fi
        fi
    fi
    
    # Test max auth tries (this is harder to test automatically)
    if [[ -n "${max_auth_tries}" ]] && [[ "${max_auth_tries}" != "6" ]]; then
        log_debug "Max auth tries set to ${max_auth_tries} (default is 6)"
        log_debug "  ℹ️  Manual testing recommended for auth attempt limits"
    fi
}

# Get SSH server information
get_server_info() {
    log_info "Gathering SSH server information..."
    
    if [[ -n "${CONTAINER_NAME}" ]]; then
        log_debug "Container environment variables:"
        docker inspect "${CONTAINER_NAME}" --format '{{range .Config.Env}}{{println .}}{{end}}' | \
            grep "^SSH_" | sort | while read -r env_var; do
            log_debug "  ${env_var}"
        done
    fi
    
    # Get SSH server version and supported methods
    local ssh_version
    ssh_version=$(ssh -o ConnectTimeout="${TIMEOUT}" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o BatchMode=yes \
        -p "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}" \
        "exit" 2>&1 | head -1 || true)
    
    if [[ -n "${ssh_version}" ]]; then
        log_debug "SSH server response: ${ssh_version}"
    fi
}

# Main function
main() {
    echo ""
    log_info "SSH Test Server - Authentication Methods Test"
    log_info "============================================="
    echo ""
    
    # Parse command line arguments
    parse_args "$@"
    
    log_info "Test Configuration:"
    log_info "  Host: ${SSH_HOST}"
    log_info "  Port: ${SSH_PORT}"
    log_info "  User: ${SSH_USER}"
    log_info "  Container: ${CONTAINER_NAME:-[not specified]}"
    log_info "  Generate Keys: ${GENERATE_KEYS}"
    log_info "  Cleanup Keys: ${CLEANUP_KEYS}"
    log_info "  Timeout: ${TIMEOUT} seconds"
    log_info "  Verbose: ${VERBOSE}"
    echo ""
    
    # Check dependencies
    check_dependencies
    
    # Generate test keys if requested
    generate_test_keys
    
    # Get server information
    get_server_info
    
    echo ""
    log_info "Running Authentication Tests..."
    echo ""
    
    # Run authentication tests
    test_password_authentication
    echo ""
    
    test_pubkey_authentication
    echo ""
    
    test_auth_method_restrictions
    echo ""
    
    test_security_configuration
    echo ""
    
    log_info "Authentication methods testing completed!"
    log_info "Check the logs above for detailed test results."
}

# Run main function
main "$@"