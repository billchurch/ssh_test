#!/bin/bash

# SSH Test Server - Basic Connection Test Script
# Tests basic connectivity and authentication methods

set -e

# Default values
SSH_HOST="localhost"
SSH_PORT="2224"
SSH_USER="testuser"
SSH_PASSWORD=""
SSH_KEY_FILE=""
TIMEOUT="10"
VERBOSE="false"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Test SSH connection to SSH test server.

OPTIONS:
    -h, --host HOST        SSH server hostname or IP (default: localhost)
    -p, --port PORT        SSH server port (default: 2224)
    -u, --user USER        SSH username (default: testuser)
    -P, --password PASS    SSH password for password authentication
    -k, --key FILE         SSH private key file for public key authentication
    -t, --timeout SECONDS  Connection timeout (default: 10)
    -v, --verbose          Enable verbose output
    --help                 Show this help message

EXAMPLES:
    # Test password authentication
    $0 --host localhost --port 2224 --user testuser --password testpass123

    # Test public key authentication
    $0 --host localhost --port 2224 --user testuser --key ~/.ssh/id_rsa

    # Test with custom timeout
    $0 --host example.com --port 22 --user testuser --password secret --timeout 30

    # Verbose mode
    $0 --host localhost --port 2224 --user testuser --password testpass123 --verbose

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
            -P|--password)
                SSH_PASSWORD="$2"
                shift 2
                ;;
            -k|--key)
                SSH_KEY_FILE="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
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
    
    if ! command -v nc >/dev/null 2>&1 && ! command -v netcat >/dev/null 2>&1; then
        missing_deps+=("netcat or nc")
    fi
    
    if [[ -n "${SSH_PASSWORD}" ]] && ! command -v sshpass >/dev/null 2>&1; then
        log_warn "sshpass not found - password authentication tests will be skipped"
        log_warn "Install sshpass: apt-get install sshpass (Ubuntu/Debian) or brew install sshpass (macOS)"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
    
    log_debug "All dependencies satisfied"
}

# Test basic network connectivity
test_connectivity() {
    log_info "Testing basic connectivity to ${SSH_HOST}:${SSH_PORT}..."
    
    if command -v nc >/dev/null 2>&1; then
        NC_CMD="nc"
    elif command -v netcat >/dev/null 2>&1; then
        NC_CMD="netcat"
    else
        log_error "Neither nc nor netcat found"
        return 1
    fi
    
    if timeout "${TIMEOUT}" "${NC_CMD}" -z "${SSH_HOST}" "${SSH_PORT}"; then
        log_info "✅ Port ${SSH_PORT} is open on ${SSH_HOST}"
        return 0
    else
        log_error "❌ Cannot connect to ${SSH_HOST}:${SSH_PORT}"
        return 1
    fi
}

# Test SSH protocol handshake
test_ssh_handshake() {
    log_info "Testing SSH protocol handshake..."
    
    local ssh_version
    ssh_version=$(timeout "${TIMEOUT}" ssh -o ConnectTimeout="${TIMEOUT}" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o BatchMode=yes \
        -p "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}" \
        "exit" 2>&1 | grep -i "permission denied\|authentication" || true)
    
    if [[ -n "${ssh_version}" ]]; then
        log_info "✅ SSH protocol handshake successful"
        log_debug "SSH response: ${ssh_version}"
        return 0
    else
        log_warn "⚠️  SSH handshake may have issues"
        return 1
    fi
}

# Test password authentication
test_password_auth() {
    if [[ -z "${SSH_PASSWORD}" ]]; then
        log_debug "No password provided, skipping password authentication test"
        return 0
    fi
    
    if ! command -v sshpass >/dev/null 2>&1; then
        log_warn "sshpass not available, skipping password authentication test"
        return 0
    fi
    
    log_info "Testing password authentication..."
    
    local ssh_opts=(
        -o ConnectTimeout="${TIMEOUT}"
        -o StrictHostKeyChecking=no
        -o UserKnownHostsFile=/dev/null
        -o PasswordAuthentication=yes
        -o PubkeyAuthentication=no
        -o PreferredAuthentications=password
    )
    
    if [[ "${VERBOSE}" == "true" ]]; then
        ssh_opts+=(-v)
    fi
    
    if sshpass -p "${SSH_PASSWORD}" ssh "${ssh_opts[@]}" \
        -p "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}" \
        "echo 'Password authentication successful'" 2>/dev/null; then
        log_info "✅ Password authentication successful"
        return 0
    else
        log_error "❌ Password authentication failed"
        return 1
    fi
}

# Test public key authentication
test_pubkey_auth() {
    if [[ -z "${SSH_KEY_FILE}" ]]; then
        log_debug "No SSH key file provided, skipping public key authentication test"
        return 0
    fi
    
    if [[ ! -f "${SSH_KEY_FILE}" ]]; then
        log_error "SSH key file not found: ${SSH_KEY_FILE}"
        return 1
    fi
    
    log_info "Testing public key authentication with ${SSH_KEY_FILE}..."
    
    local ssh_opts=(
        -o ConnectTimeout="${TIMEOUT}"
        -o StrictHostKeyChecking=no
        -o UserKnownHostsFile=/dev/null
        -o PasswordAuthentication=no
        -o PubkeyAuthentication=yes
        -o PreferredAuthentications=publickey
        -i "${SSH_KEY_FILE}"
    )
    
    if [[ "${VERBOSE}" == "true" ]]; then
        ssh_opts+=(-v)
    fi
    
    if ssh "${ssh_opts[@]}" \
        -p "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}" \
        "echo 'Public key authentication successful'" 2>/dev/null; then
        log_info "✅ Public key authentication successful"
        return 0
    else
        log_error "❌ Public key authentication failed"
        return 1
    fi
}

# Test basic SSH functionality
test_ssh_functionality() {
    log_info "Testing basic SSH functionality..."
    
    local auth_method=""
    local ssh_opts=(
        -o ConnectTimeout="${TIMEOUT}"
        -o StrictHostKeyChecking=no
        -o UserKnownHostsFile=/dev/null
    )
    
    # Determine authentication method to use
    if [[ -n "${SSH_PASSWORD}" ]] && command -v sshpass >/dev/null 2>&1; then
        auth_method="password"
        ssh_opts+=(
            -o PasswordAuthentication=yes
            -o PubkeyAuthentication=no
            -o PreferredAuthentications=password
        )
    elif [[ -n "${SSH_KEY_FILE}" ]] && [[ -f "${SSH_KEY_FILE}" ]]; then
        auth_method="pubkey"
        ssh_opts+=(
            -o PasswordAuthentication=no
            -o PubkeyAuthentication=yes
            -o PreferredAuthentications=publickey
            -i "${SSH_KEY_FILE}"
        )
    else
        log_warn "No valid authentication method available for functionality test"
        return 0
    fi
    
    if [[ "${VERBOSE}" == "true" ]]; then
        ssh_opts+=(-v)
    fi
    
    # Test basic commands
    local tests=(
        "whoami:Testing user identification"
        "pwd:Testing working directory"
        "echo 'Hello SSH':Testing echo command"
        "date:Testing date command"
    )
    
    for test in "${tests[@]}"; do
        local cmd="${test%%:*}"
        local desc="${test##*:}"
        
        log_debug "${desc}..."
        
        local result
        if [[ "${auth_method}" == "password" ]]; then
            result=$(sshpass -p "${SSH_PASSWORD}" ssh "${ssh_opts[@]}" \
                -p "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}" \
                "${cmd}" 2>/dev/null)
        else
            result=$(ssh "${ssh_opts[@]}" \
                -p "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}" \
                "${cmd}" 2>/dev/null)
        fi
        
        if [[ $? -eq 0 ]] && [[ -n "${result}" ]]; then
            log_debug "  ✅ ${cmd}: ${result}"
        else
            log_warn "  ⚠️  ${cmd}: Failed or no output"
        fi
    done
    
    log_info "✅ Basic SSH functionality test completed"
}

# Main function
main() {
    echo ""
    log_info "SSH Test Server - Connection Test"
    log_info "=================================="
    echo ""
    
    # Parse command line arguments
    parse_args "$@"
    
    # Validate inputs
    if [[ -z "${SSH_PASSWORD}" ]] && [[ -z "${SSH_KEY_FILE}" ]]; then
        log_error "Either password (-P) or SSH key file (-k) must be provided"
        exit 1
    fi
    
    log_info "Test Configuration:"
    log_info "  Host: ${SSH_HOST}"
    log_info "  Port: ${SSH_PORT}"
    log_info "  User: ${SSH_USER}"
    log_info "  Password: ${SSH_PASSWORD:+[provided]}"
    log_info "  SSH Key: ${SSH_KEY_FILE:-[not provided]}"
    log_info "  Timeout: ${TIMEOUT} seconds"
    log_info "  Verbose: ${VERBOSE}"
    echo ""
    
    # Check dependencies
    check_dependencies
    
    # Run tests
    local test_results=()
    
    # Test 1: Basic connectivity
    if test_connectivity; then
        test_results+=("Connectivity: PASS")
    else
        test_results+=("Connectivity: FAIL")
        log_error "Basic connectivity failed, aborting further tests"
        exit 1
    fi
    
    # Test 2: SSH handshake
    if test_ssh_handshake; then
        test_results+=("SSH Handshake: PASS")
    else
        test_results+=("SSH Handshake: WARN")
    fi
    
    # Test 3: Password authentication
    if test_password_auth; then
        test_results+=("Password Auth: PASS")
    elif [[ -n "${SSH_PASSWORD}" ]]; then
        test_results+=("Password Auth: FAIL")
    else
        test_results+=("Password Auth: SKIPPED")
    fi
    
    # Test 4: Public key authentication
    if test_pubkey_auth; then
        test_results+=("Pubkey Auth: PASS")
    elif [[ -n "${SSH_KEY_FILE}" ]]; then
        test_results+=("Pubkey Auth: FAIL")
    else
        test_results+=("Pubkey Auth: SKIPPED")
    fi
    
    # Test 5: SSH functionality
    test_ssh_functionality
    test_results+=("SSH Functionality: PASS")
    
    # Print summary
    echo ""
    log_info "Test Results Summary:"
    log_info "===================="
    for result in "${test_results[@]}"; do
        if [[ "${result}" == *"PASS" ]]; then
            echo -e "  ${GREEN}✅ ${result}${NC}"
        elif [[ "${result}" == *"FAIL" ]]; then
            echo -e "  ${RED}❌ ${result}${NC}"
        elif [[ "${result}" == *"WARN" ]]; then
            echo -e "  ${YELLOW}⚠️  ${result}${NC}"
        else
            echo -e "  ${BLUE}⏭️  ${result}${NC}"
        fi
    done
    echo ""
    
    # Check for failures
    if echo "${test_results[@]}" | grep -q "FAIL"; then
        log_error "Some tests failed. Check the logs above for details."
        exit 1
    else
        log_info "All tests passed successfully! 🎉"
        exit 0
    fi
}

# Run main function
main "$@"