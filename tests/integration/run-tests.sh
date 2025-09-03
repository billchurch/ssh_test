#!/bin/bash

# SSH Test Server - Integration Test Suite
# Comprehensive integration tests for SSH test server

set -e

# Default configuration
DOCKER_IMAGE="ssh-test-server:test"
TEST_TIMEOUT="30"
VERBOSE="false"
PARALLEL="false"
CLEANUP="true"
REPORT_FILE=""

# Test results tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run integration tests for SSH test server.

OPTIONS:
    -i, --image IMAGE         Docker image to test (default: ssh-test-server:test)
    -t, --timeout SECONDS     Test timeout (default: 30)
    -p, --parallel            Run tests in parallel
    -v, --verbose             Enable verbose output
    -n, --no-cleanup          Don't cleanup containers after tests
    -r, --report FILE         Generate test report to file
    --help                    Show this help message

EXAMPLES:
    # Run basic tests
    $0

    # Run tests with custom image
    $0 --image ssh-test-server:latest

    # Run tests in parallel with verbose output
    $0 --parallel --verbose

    # Generate test report
    $0 --report test-results.txt

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

log_test_start() {
    echo -e "${BLUE}[TEST]${NC} Starting: $1"
}

log_test_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_test_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
    FAILED_TESTS+=("$1")
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--image)
                DOCKER_IMAGE="$2"
                shift 2
                ;;
            -t|--timeout)
                TEST_TIMEOUT="$2"
                shift 2
                ;;
            -p|--parallel)
                PARALLEL="true"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -n|--no-cleanup)
                CLEANUP="false"
                shift
                ;;
            -r|--report)
                REPORT_FILE="$2"
                shift 2
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
    
    for cmd in docker ssh ssh-keygen sshpass nc; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Please install missing dependencies and try again"
        exit 1
    fi
    
    # Check if Docker image exists
    if ! docker image inspect "${DOCKER_IMAGE}" >/dev/null 2>&1; then
        log_error "Docker image '${DOCKER_IMAGE}' not found"
        log_error "Build the image first or specify a different image with --image"
        exit 1
    fi
    
    log_debug "Dependencies check passed"
}

# Cleanup function
cleanup_container() {
    local container_name="$1"
    
    if [[ "${CLEANUP}" == "true" ]]; then
        log_debug "Cleaning up container: ${container_name}"
        # Skip docker stop completely and go straight to forceful removal
        # since --rm flag with docker stop can hang
        docker rm -f "${container_name}" >/dev/null 2>&1 || true
    fi
}

# Pre-test cleanup to remove any stale containers
cleanup_stale_containers() {
    log_info "Cleaning up any stale SSH test containers..."
    
    # Find and remove containers with ssh-test prefix
    local stale_containers
    stale_containers=$(docker ps -aq --filter="name=ssh-test-" 2>/dev/null || true)
    
    if [[ -n "${stale_containers}" ]]; then
        log_debug "Found stale containers: ${stale_containers}"
        # Remove all stale containers forcefully
        echo "${stale_containers}" | xargs docker rm -f >/dev/null 2>&1 || true
        log_info "Cleaned up stale containers"
    else
        log_debug "No stale containers found"
    fi
}

# Wait for container to be ready
wait_for_container() {
    local container_name="$1"
    local port="$2"
    local max_wait="$3"
    
    log_debug "Waiting for container ${container_name} to be ready on port ${port}..."
    
    local count=0
    while [[ $count -lt $max_wait ]]; do
        if nc -z localhost "${port}" 2>/dev/null; then
            log_debug "Container ready after ${count} seconds"
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    log_error "Container failed to become ready within ${max_wait} seconds"
    return 1
}

# Helper function for SSH connections with retry logic
ssh_test_connection() {
    local password="$1"
    local port="$2"
    local user="$3"
    local command="$4"
    shift 4
    local ssh_args=("$@")
    
    local retry_count=0
    local max_retries=3
    
    while [[ $retry_count -lt $max_retries ]]; do
        if sshpass -p "${password}" ssh \
            -o ConnectTimeout=5 \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            "${ssh_args[@]}" \
            -p "${port}" "${user}@localhost" \
            "${command}" >/dev/null 2>&1; then
            return 0
        fi
        ((retry_count++))
        [[ $retry_count -lt $max_retries ]] && sleep 1
    done
    
    return 1
}

# Test basic functionality
test_basic_functionality() {
    local test_name="Basic Functionality"
    log_test_start "${test_name}"
    ((TESTS_RUN++))
    
    local container_name="ssh-test-basic-$$"
    local port=2224
    
    # Start container
    if ! docker run -d --rm --name "${container_name}" \
        -e SSH_USER=testuser \
        -e SSH_PASSWORD=testpass123 \
        -e SSH_DEBUG_LEVEL=1 \
        -p "${port}:22" \
        "${DOCKER_IMAGE}" >/dev/null 2>&1; then
        log_test_fail "${test_name}: Failed to start container"
        return 1
    fi
    
    # Wait for container to be ready
    if ! wait_for_container "${container_name}" "${port}" 10; then
        cleanup_container "${container_name}"
        log_test_fail "${test_name}: Container not ready"
        return 1
    fi
    
    # Test SSH connection
    if ssh_test_connection "testpass123" "${port}" "testuser" "echo 'Basic test successful'"; then
        log_test_pass "${test_name}"
        cleanup_container "${container_name}"
        return 0
    else
        cleanup_container "${container_name}"
        log_test_fail "${test_name}: SSH connection failed"
        return 1
    fi
}

# Test password authentication
test_password_authentication() {
    local test_name="Password Authentication"
    log_test_start "${test_name}"
    ((TESTS_RUN++))
    
    local container_name="ssh-test-password-$$"
    local port=2223
    
    # Start container with password auth only
    if ! docker run -d --rm --name "${container_name}" \
        -e SSH_USER=passuser \
        -e SSH_PASSWORD=securepass456 \
        -e SSH_PERMIT_PASSWORD_AUTH=yes \
        -e SSH_PERMIT_PUBKEY_AUTH=no \
        -e SSH_DEBUG_LEVEL=1 \
        -p "${port}:22" \
        "${DOCKER_IMAGE}" >/dev/null 2>&1; then
        log_test_fail "${test_name}: Failed to start container"
        return 1
    fi
    
    if ! wait_for_container "${container_name}" "${port}" 10; then
        cleanup_container "${container_name}"
        log_test_fail "${test_name}: Container not ready"
        return 1
    fi
    
    # Test correct password
    if ! sshpass -p "securepass456" ssh \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o PasswordAuthentication=yes \
        -o PubkeyAuthentication=no \
        -p "${port}" passuser@localhost \
        "echo 'Password auth successful'" >/dev/null 2>&1; then
        cleanup_container "${container_name}"
        log_test_fail "${test_name}: Valid password rejected"
        return 1
    fi
    
    # Test incorrect password (should fail)
    if sshpass -p "wrongpassword" ssh \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o PasswordAuthentication=yes \
        -o PubkeyAuthentication=no \
        -o NumberOfPasswordPrompts=1 \
        -p "${port}" passuser@localhost \
        "echo 'Should not work'" >/dev/null 2>&1; then
        cleanup_container "${container_name}"
        log_test_fail "${test_name}: Invalid password accepted"
        return 1
    fi
    
    log_test_pass "${test_name}"
    cleanup_container "${container_name}"
    return 0
}

# Test public key authentication
test_pubkey_authentication() {
    local test_name="Public Key Authentication"
    log_test_start "${test_name}"
    ((TESTS_RUN++))
    
    local container_name="ssh-test-pubkey-$$"
    local port=2229
    
    # Generate test key
    local temp_key_dir
    temp_key_dir=$(mktemp -d)
    local test_key="${temp_key_dir}/test_key"
    
    if ! ssh-keygen -t ed25519 -f "${test_key}" -N "" -C "test@integration" >/dev/null 2>&1; then
        log_test_fail "${test_name}: Failed to generate test key"
        rm -rf "${temp_key_dir}"
        return 1
    fi
    
    local public_key
    public_key=$(cat "${test_key}.pub")
    
    # Start container with public key auth only
    if ! docker run -d --rm --name "${container_name}" \
        -e SSH_USER=keyuser \
        -e "SSH_AUTHORIZED_KEYS=${public_key}" \
        -e SSH_PERMIT_PASSWORD_AUTH=no \
        -e SSH_PERMIT_PUBKEY_AUTH=yes \
        -e SSH_DEBUG_LEVEL=1 \
        -p "${port}:22" \
        "${DOCKER_IMAGE}" >/dev/null 2>&1; then
        log_test_fail "${test_name}: Failed to start container"
        rm -rf "${temp_key_dir}"
        return 1
    fi
    
    if ! wait_for_container "${container_name}" "${port}" 10; then
        cleanup_container "${container_name}"
        log_test_fail "${test_name}: Container not ready"
        rm -rf "${temp_key_dir}"
        return 1
    fi
    
    # Test with correct key
    if ! ssh \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o PasswordAuthentication=no \
        -o PubkeyAuthentication=yes \
        -i "${test_key}" \
        -p "${port}" keyuser@localhost \
        "echo 'Pubkey auth successful'" >/dev/null 2>&1; then
        cleanup_container "${container_name}"
        log_test_fail "${test_name}: Valid key rejected"
        rm -rf "${temp_key_dir}"
        return 1
    fi
    
    log_test_pass "${test_name}"
    cleanup_container "${container_name}"
    rm -rf "${temp_key_dir}"
    return 0
}

# Test custom port configuration
test_custom_port() {
    local test_name="Custom Port Configuration"
    log_test_start "${test_name}"
    ((TESTS_RUN++))
    
    local container_name="ssh-test-port-$$"
    local host_port=2225
    local ssh_port=2224
    
    # Start container with custom SSH port
    if ! docker run -d --rm --name "${container_name}" \
        -e SSH_USER=portuser \
        -e SSH_PASSWORD=portpass789 \
        -e SSH_PORT="${ssh_port}" \
        -e SSH_DEBUG_LEVEL=1 \
        -p "${host_port}:${ssh_port}" \
        "${DOCKER_IMAGE}" >/dev/null 2>&1; then
        log_test_fail "${test_name}: Failed to start container"
        return 1
    fi
    
    if ! wait_for_container "${container_name}" "${host_port}" 10; then
        cleanup_container "${container_name}"
        log_test_fail "${test_name}: Container not ready"
        return 1
    fi
    
    # Test SSH connection on custom port
    if sshpass -p "portpass789" ssh \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -p "${host_port}" portuser@localhost \
        "echo 'Custom port test successful'" >/dev/null 2>&1; then
        log_test_pass "${test_name}"
        cleanup_container "${container_name}"
        return 0
    else
        cleanup_container "${container_name}"
        log_test_fail "${test_name}: SSH connection failed on custom port"
        return 1
    fi
}

# Test security hardening
test_security_hardening() {
    local test_name="Security Hardening"
    log_test_start "${test_name}"
    ((TESTS_RUN++))
    
    local container_name="ssh-test-security-$$"
    local port=2226
    
    # Start container with security hardening
    if ! docker run -d --rm --name "${container_name}" \
        -e SSH_USER=secureuser \
        -e SSH_PASSWORD=securepass \
        -e SSH_PERMIT_ROOT_LOGIN=no \
        -e SSH_PERMIT_EMPTY_PASSWORDS=no \
        -e SSH_MAX_AUTH_TRIES=2 \
        -e SSH_USE_DNS=no \
        -e SSH_X11_FORWARDING=no \
        -e SSH_AGENT_FORWARDING=no \
        -e SSH_TCP_FORWARDING=no \
        -e SSH_DEBUG_LEVEL=1 \
        -p "${port}:22" \
        "${DOCKER_IMAGE}" >/dev/null 2>&1; then
        log_test_fail "${test_name}: Failed to start container"
        return 1
    fi
    
    if ! wait_for_container "${container_name}" "${port}" 10; then
        cleanup_container "${container_name}"
        log_test_fail "${test_name}: Container not ready"
        return 1
    fi
    
    # Test that root login is denied
    if sshpass -p "securepass" ssh \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -p "${port}" root@localhost \
        "echo 'Root login should fail'" >/dev/null 2>&1; then
        cleanup_container "${container_name}"
        log_test_fail "${test_name}: Root login was allowed"
        return 1
    fi
    
    # Test that regular user can still login (force password auth to avoid MaxAuthTries exhaustion)
    if ! sshpass -p "securepass" ssh \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o PasswordAuthentication=yes \
        -o PubkeyAuthentication=no \
        -o NumberOfPasswordPrompts=1 \
        -p "${port}" secureuser@localhost \
        "echo 'Regular user login successful'" >/dev/null 2>&1; then
        cleanup_container "${container_name}"
        log_test_fail "${test_name}: Regular user login failed"
        return 1
    fi
    
    log_test_pass "${test_name}"
    cleanup_container "${container_name}"
    return 0
}

# Test debug mode
test_debug_mode() {
    local test_name="Debug Mode"
    log_test_start "${test_name}"
    ((TESTS_RUN++))
    
    local container_name="ssh-test-debug-$$"
    local port=2227
    
    # Start container with debug mode
    if ! docker run -d --rm --name "${container_name}" \
        -e SSH_USER=debuguser \
        -e SSH_PASSWORD=debugpass \
        -e SSH_DEBUG_LEVEL=3 \
        -p "${port}:22" \
        "${DOCKER_IMAGE}" >/dev/null 2>&1; then
        log_test_fail "${test_name}: Failed to start container"
        return 1
    fi
    
    if ! wait_for_container "${container_name}" "${port}" 10; then
        cleanup_container "${container_name}"
        log_test_fail "${test_name}: Container not ready"
        return 1
    fi
    
    # Test SSH connection and check for debug output in logs
    sshpass -p "debugpass" ssh \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -p "${port}" debuguser@localhost \
        "echo 'Debug test'" >/dev/null 2>&1
    
    # Check container logs for debug output
    local logs
    logs=$(docker logs "${container_name}" 2>&1)
    
    if echo "${logs}" | grep -q "debug"; then
        log_test_pass "${test_name}"
        cleanup_container "${container_name}"
        return 0
    else
        cleanup_container "${container_name}"
        log_test_fail "${test_name}: No debug output found in logs"
        return 1
    fi
}

# Test environment variable validation
test_env_validation() {
    local test_name="Environment Variable Validation"
    log_test_start "${test_name}"
    ((TESTS_RUN++))
    
    local container_name="ssh-test-env-$$"
    
    # Start container with invalid port (should use default)
    if ! docker run -d --rm --name "${container_name}" \
        -e SSH_USER=envuser \
        -e SSH_PASSWORD=envpass \
        -e SSH_PORT=99999 \
        -e SSH_DEBUG_LEVEL=5 \
        -e SSH_MAX_AUTH_TRIES=abc \
        -p "2228:22" \
        "${DOCKER_IMAGE}" >/dev/null 2>&1; then
        log_test_fail "${test_name}: Container failed to start with invalid env vars"
        return 1
    fi
    
    if ! wait_for_container "${container_name}" "2228" 10; then
        cleanup_container "${container_name}"
        log_test_fail "${test_name}: Container not ready"
        return 1
    fi
    
    # Check that container is running and SSH works (validation should handle invalid values)
    if sshpass -p "envpass" ssh \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -p "2228" envuser@localhost \
        "echo 'Env validation test'" >/dev/null 2>&1; then
        log_test_pass "${test_name}"
        cleanup_container "${container_name}"
        return 0
    else
        cleanup_container "${container_name}"
        log_test_fail "${test_name}: SSH connection failed with invalid env vars"
        return 1
    fi
}

# Test SSH agent functionality
test_ssh_agent() {
    local test_name="SSH Agent Integration"
    log_test_start "${test_name}"
    ((TESTS_RUN++))
    
    # Get the directory of this script
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Path to agent test script
    local agent_test_script="${script_dir}/test-ssh-agent.sh"
    
    if [[ ! -f "${agent_test_script}" ]]; then
        log_test_fail "${test_name} - Agent test script not found at ${agent_test_script}"
        return
    fi
    
    if [[ ! -x "${agent_test_script}" ]]; then
        log_test_fail "${test_name} - Agent test script not executable"
        return
    fi
    
    # Run the agent test script
    local verbose_flag=""
    if [[ "${VERBOSE}" == "true" ]]; then
        verbose_flag="--verbose"
    fi
    
    local cleanup_flag=""
    if [[ "${CLEANUP}" == "false" ]]; then
        cleanup_flag="--no-cleanup"
    fi
    
    log_debug "Running SSH agent tests with image: ${DOCKER_IMAGE}"
    
    if "${agent_test_script}" --image "${DOCKER_IMAGE}" --timeout "${TEST_TIMEOUT}" ${verbose_flag} ${cleanup_flag}; then
        log_test_pass "${test_name}"
    else
        log_test_fail "${test_name} - SSH agent tests failed"
    fi
}

# Run a single test
# Note: With 'set -e' enabled globally, a non-zero return from a test function
# would terminate the whole script. We explicitly swallow the exit status here
# so the harness can aggregate results and continue running subsequent tests.
run_single_test() {
    local test_func="$1"

    if [[ "${PARALLEL}" == "true" ]]; then
        { $test_func || true; } &
    else
        $test_func || true
    fi
}

# Generate test report
generate_report() {
    if [[ -z "${REPORT_FILE}" ]]; then
        return 0
    fi
    
    log_info "Generating test report: ${REPORT_FILE}"
    
    cat > "${REPORT_FILE}" << EOF
SSH Test Server - Integration Test Report
==========================================

Test Configuration:
- Docker Image: ${DOCKER_IMAGE}
- Test Timeout: ${TIMEOUT} seconds
- Parallel Execution: ${PARALLEL}
- Verbose Mode: ${VERBOSE}

Test Results:
- Tests Run: ${TESTS_RUN}
- Tests Passed: ${TESTS_PASSED}
- Tests Failed: ${TESTS_FAILED}

EOF

    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        echo "Failed Tests:" >> "${REPORT_FILE}"
        for failed_test in "${FAILED_TESTS[@]}"; do
            echo "- ${failed_test}" >> "${REPORT_FILE}"
        done
        echo "" >> "${REPORT_FILE}"
    fi
    
    echo "Generated at: $(date)" >> "${REPORT_FILE}"
    
    log_info "Test report saved to: ${REPORT_FILE}"
}

# Main function
main() {
    echo ""
    log_info "SSH Test Server - Integration Test Suite"
    log_info "========================================"
    echo ""
    
    # Parse arguments
    parse_args "$@"
    
    # Check dependencies
    check_dependencies
    
    # Clean up any stale containers
    cleanup_stale_containers
    
    log_info "Test Configuration:"
    log_info "  Docker Image: ${DOCKER_IMAGE}"
    log_info "  Test Timeout: ${TEST_TIMEOUT} seconds"
    log_info "  Parallel Execution: ${PARALLEL}"
    log_info "  Verbose Mode: ${VERBOSE}"
    log_info "  Cleanup Containers: ${CLEANUP}"
    log_info "  Report File: ${REPORT_FILE:-none}"
    echo ""
    
    log_info "Running Integration Tests..."
    echo ""
    
    # Define test functions
    local test_functions=(
        test_basic_functionality
        test_password_authentication
        test_pubkey_authentication
        test_custom_port
        test_security_hardening
        test_debug_mode
        test_env_validation
        test_ssh_agent
    )
    
    # Run tests
    for test_func in "${test_functions[@]}"; do
        run_single_test "$test_func"
    done
    
    # Wait for parallel tests to complete
    if [[ "${PARALLEL}" == "true" ]]; then
        wait
    fi
    
    echo ""
    log_info "Integration Test Summary"
    log_info "======================="
    log_info "  Tests Run: ${TESTS_RUN}"
    log_info "  Tests Passed: ${TESTS_PASSED}"
    log_info "  Tests Failed: ${TESTS_FAILED}"
    
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        echo ""
        log_error "Failed Tests:"
        for failed_test in "${FAILED_TESTS[@]}"; do
            log_error "  - ${failed_test}"
        done
    fi
    
    echo ""
    
    # Generate report
    generate_report
    
    # Exit with appropriate code
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        log_error "Integration tests failed!"
        exit 1
    else
        log_info "All integration tests passed! 🎉"
        exit 0
    fi
}

# Run main function
main "$@"
