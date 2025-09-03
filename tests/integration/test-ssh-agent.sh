#!/bin/bash

# SSH Test Server - SSH Agent Integration Test Suite
# Tests for SSH agent functionality including internal agent and forwarding

# Do not use 'set -e' here: individual subtests are responsible for
# recording pass/fail and the suite should continue on errors to
# report a full summary back to the caller.

# Default configuration
DOCKER_IMAGE="ssh-test-server:test"
TEST_TIMEOUT="30"
VERBOSE="false"
CLEANUP="true"

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

Run SSH agent integration tests for SSH test server.

OPTIONS:
    -i, --image IMAGE         Docker image to test (default: ssh-test-server:test)
    -t, --timeout SECONDS     Test timeout (default: 30)
    -v, --verbose             Enable verbose output
    -n, --no-cleanup          Don't cleanup containers after tests
    --help                    Show this help message

EXAMPLES:
    # Run basic agent tests
    $0

    # Run tests with custom image and verbose output
    $0 --image ssh-test-server:latest --verbose

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
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -n|--no-cleanup)
                CLEANUP="false"
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
    
    for cmd in docker ssh ssh-keygen sshpass nc base64; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Please install missing dependencies and try again"
        exit 1
    fi
    
    # Check for Docker image
    if ! docker image inspect "${DOCKER_IMAGE}" >/dev/null 2>&1; then
        log_error "Docker image '${DOCKER_IMAGE}' not found"
        exit 1
    fi
    
    log_debug "Dependencies check passed"
}

# Cleanup function
cleanup_container() {
    local container_name="$1"
    if [[ "${CLEANUP}" == "true" ]]; then
        log_debug "Cleaning up container (force): ${container_name}"
        docker rm -f "${container_name}" >/dev/null 2>&1 || true
    fi
}

# Wait for container to be ready
wait_for_container() {
    local port="$1"
    local max_wait=30
    local count=0
    
    while [[ $count -lt $max_wait ]]; do
        if nc -z localhost "${port}" 2>/dev/null; then
            log_debug "Container ready after ${count} seconds"
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    log_error "Container did not become ready within ${max_wait} seconds"
    return 1
}

# Generate test SSH key
generate_test_key() {
    local key_type="$1"
    local key_path="$2"
    
    ssh-keygen -t "${key_type}" -f "${key_path}" -N "" -C "test-agent-key" >/dev/null 2>&1
    log_debug "Generated ${key_type} key: ${key_path}"
}

# Encode key for environment variable
encode_key() {
    local key_path="$1"
    base64 -i "${key_path}" | tr -d '\n'
}

# Test SSH agent startup
test_agent_startup() {
    local test_name="SSH Agent Startup"
    log_test_start "${test_name}"
    ((TESTS_RUN++))
    
    local container_name="ssh-agent-startup-test"
    local port=2300
    
    cleanup_container "${container_name}"
    
    # Run container with SSH agent enabled
    if docker run -d --name "${container_name}" \
        -p "${port}:22" \
        -e SSH_USER=testuser \
        -e SSH_PASSWORD=testpass123 \
        -e SSH_AGENT_START=yes \
        -e SSH_DEBUG_LEVEL=1 \
        "${DOCKER_IMAGE}" >/dev/null 2>&1; then
        
        if wait_for_container "${port}"; then
            # Check if agent is mentioned in logs
            sleep 2
            local logs
            logs=$(docker logs "${container_name}" 2>&1)
            
            if echo "${logs}" | grep -q "SSH agent started"; then
                log_test_pass "${test_name}"
            else
                log_test_fail "${test_name} - SSH agent startup not confirmed in logs"
                log_debug "Container logs: ${logs}"
            fi
        else
            log_test_fail "${test_name} - Container failed to start"
        fi
    else
        log_test_fail "${test_name} - Failed to start container"
    fi
    
    cleanup_container "${container_name}"
}

# Test SSH agent with keys
test_agent_with_keys() {
    local test_name="SSH Agent with Keys"
    log_test_start "${test_name}"
    ((TESTS_RUN++))
    
    local container_name="ssh-agent-keys-test"
    local port=2301
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # Generate test keys
    generate_test_key "ed25519" "${temp_dir}/test_ed25519"
    generate_test_key "rsa" "${temp_dir}/test_rsa"
    
    # Encode keys for environment
    local ed25519_key
    local rsa_key
    ed25519_key=$(encode_key "${temp_dir}/test_ed25519")
    rsa_key=$(encode_key "${temp_dir}/test_rsa")
    
    cleanup_container "${container_name}"
    
    # Run container with SSH agent and keys
    if docker run -d --name "${container_name}" \
        -p "${port}:22" \
        -e SSH_USER=testuser \
        -e SSH_PASSWORD=testpass123 \
        -e SSH_AGENT_START=yes \
        -e SSH_AGENT_KEYS="${ed25519_key}
${rsa_key}" \
        -e SSH_DEBUG_LEVEL=1 \
        "${DOCKER_IMAGE}" >/dev/null 2>&1; then
        
        if wait_for_container "${port}"; then
            sleep 3
            local logs
            logs=$(docker logs "${container_name}" 2>&1)
            
            if echo "${logs}" | grep -q "SSH agent key loading completed"; then
                log_test_pass "${test_name}"
            else
                log_test_fail "${test_name} - Key loading not confirmed in logs"
                log_debug "Container logs: ${logs}"
            fi
        else
            log_test_fail "${test_name} - Container failed to start"
        fi
    else
        log_test_fail "${test_name} - Failed to start container"
    fi
    
    cleanup_container "${container_name}"
    rm -rf "${temp_dir}"
}

# Test SSH agent forwarding configuration
test_agent_forwarding_config() {
    local test_name="SSH Agent Forwarding Configuration"
    log_test_start "${test_name}"
    ((TESTS_RUN++))
    
    local container_name="ssh-agent-forwarding-test"
    local port=2302
    
    cleanup_container "${container_name}"
    
    # Run container with agent forwarding enabled
    if docker run -d --name "${container_name}" \
        -p "${port}:22" \
        -e SSH_USER=testuser \
        -e SSH_PASSWORD=testpass123 \
        -e SSH_AGENT_FORWARDING=yes \
        -e SSH_DEBUG_LEVEL=1 \
        "${DOCKER_IMAGE}" >/dev/null 2>&1; then
        
        if wait_for_container "${port}"; then
            # Check SSH configuration
            local sshd_config
            sshd_config=$(docker exec "${container_name}" cat /etc/ssh/sshd_config 2>/dev/null || true)
            
            if echo "${sshd_config}" | grep -q "AllowAgentForwarding yes"; then
                log_test_pass "${test_name}"
            else
                log_test_fail "${test_name} - Agent forwarding not enabled in sshd_config"
                log_debug "sshd_config content: ${sshd_config}"
            fi
        else
            log_test_fail "${test_name} - Container failed to start"
        fi
    else
        log_test_fail "${test_name} - Failed to start container"
    fi
    
    cleanup_container "${container_name}"
}

# Test SSH agent environment setup
test_agent_environment() {
    local test_name="SSH Agent Environment Setup"
    log_test_start "${test_name}"
    ((TESTS_RUN++))
    
    local container_name="ssh-agent-env-test"
    local port=2303
    
    cleanup_container "${container_name}"
    
    # Run container with SSH agent enabled
    if docker run -d --name "${container_name}" \
        -p "${port}:22" \
        -e SSH_USER=testuser \
        -e SSH_PASSWORD=testpass123 \
        -e SSH_AGENT_START=yes \
        -e SSH_AGENT_SOCKET_PATH="/tmp/test-agent.sock" \
        "${DOCKER_IMAGE}" >/dev/null 2>&1; then
        
        if wait_for_container "${port}"; then
            sleep 2
            
            # Check if agent environment file exists
            local agent_env_exists
            agent_env_exists=$(docker exec "${container_name}" test -f /home/testuser/.ssh/agent_env && echo "yes" || echo "no")
            
            if [[ "${agent_env_exists}" == "yes" ]]; then
                # Check agent environment content
                local agent_env_content
                agent_env_content=$(docker exec "${container_name}" cat /home/testuser/.ssh/agent_env 2>/dev/null || true)
                
                if echo "${agent_env_content}" | grep -q "SSH_AUTH_SOCK=/tmp/test-agent.sock"; then
                    log_test_pass "${test_name}"
                else
                    log_test_fail "${test_name} - Incorrect agent environment content"
                    log_debug "Agent env content: ${agent_env_content}"
                fi
            else
                log_test_fail "${test_name} - Agent environment file not created"
            fi
        else
            log_test_fail "${test_name} - Container failed to start"
        fi
    else
        log_test_fail "${test_name} - Failed to start container"
    fi
    
    cleanup_container "${container_name}"
}

# Test SSH connection with agent
test_ssh_connection_with_agent() {
    local test_name="SSH Connection with Agent"
    log_test_start "${test_name}"
    ((TESTS_RUN++))
    
    local container_name="ssh-agent-connection-test"
    local port=2304
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # Generate test key pair
    generate_test_key "ed25519" "${temp_dir}/test_key"
    
    # Read public key for authorized_keys
    local public_key
    public_key=$(cat "${temp_dir}/test_key.pub")
    
    # Encode private key for agent
    local private_key_encoded
    private_key_encoded=$(encode_key "${temp_dir}/test_key")
    
    cleanup_container "${container_name}"
    
    # Run container with SSH agent and our test key
    if docker run -d --name "${container_name}" \
        -p "${port}:22" \
        -e SSH_USER=testuser \
        -e SSH_PASSWORD=testpass123 \
        -e SSH_AUTHORIZED_KEYS="${public_key}" \
        -e SSH_PERMIT_PASSWORD_AUTH=no \
        -e SSH_PERMIT_PUBKEY_AUTH=yes \
        -e SSH_AGENT_START=yes \
        -e SSH_AGENT_KEYS="${private_key_encoded}" \
        "${DOCKER_IMAGE}" >/dev/null 2>&1; then
        
        if wait_for_container "${port}"; then
            sleep 3
            
            # Try to connect using the key in the agent (via exec in container)
            local connection_test
            connection_test=$(docker exec "${container_name}" bash -c "
                source /home/testuser/.ssh/agent_env 2>/dev/null || true
                ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes \
                    testuser@localhost 'echo agent-connection-successful' 2>/dev/null || echo 'connection-failed'
            " 2>/dev/null || echo "exec-failed")
            
            if echo "${connection_test}" | grep -q "agent-connection-successful"; then
                log_test_pass "${test_name}"
            else
                log_test_fail "${test_name} - SSH connection using agent failed"
                log_debug "Connection test result: ${connection_test}"
                log_debug "Container logs: $(docker logs "${container_name}" 2>&1 | tail -10)"
            fi
        else
            log_test_fail "${test_name} - Container failed to start"
        fi
    else
        log_test_fail "${test_name} - Failed to start container"
    fi
    
    cleanup_container "${container_name}"
    rm -rf "${temp_dir}"
}

# Test agent socket permissions
test_agent_socket_permissions() {
    local test_name="SSH Agent Socket Permissions"
    log_test_start "${test_name}"
    ((TESTS_RUN++))
    
    local container_name="ssh-agent-perms-test"
    local port=2305
    
    cleanup_container "${container_name}"
    
    # Run container with SSH agent
    if docker run -d --name "${container_name}" \
        -p "${port}:22" \
        -e SSH_USER=testuser \
        -e SSH_PASSWORD=testpass123 \
        -e SSH_AGENT_START=yes \
        "${DOCKER_IMAGE}" >/dev/null 2>&1; then
        
        if wait_for_container "${port}"; then
            sleep 2
            
            # Check socket permissions and ownership
            local socket_perms
            socket_perms=$(docker exec "${container_name}" ls -la /tmp/ssh-agent.sock 2>/dev/null || echo "socket-not-found")
            
            if echo "${socket_perms}" | grep -q "srw-------.*testuser testuser"; then
                log_test_pass "${test_name}"
            else
                log_test_fail "${test_name} - Incorrect socket permissions or ownership"
                log_debug "Socket permissions: ${socket_perms}"
            fi
        else
            log_test_fail "${test_name} - Container failed to start"
        fi
    else
        log_test_fail "${test_name} - Failed to start container"
    fi
    
    cleanup_container "${container_name}"
}

# Test cleanup on container stop
test_agent_cleanup() {
    local test_name="SSH Agent Cleanup"
    log_test_start "${test_name}"
    ((TESTS_RUN++))
    
    local container_name="ssh-agent-cleanup-test"
    local port=2306
    
    cleanup_container "${container_name}"
    
    # Run container with SSH agent
    if docker run -d --name "${container_name}" \
        -p "${port}:22" \
        -e SSH_USER=testuser \
        -e SSH_PASSWORD=testpass123 \
        -e SSH_AGENT_START=yes \
        "${DOCKER_IMAGE}" >/dev/null 2>&1; then
        
        if wait_for_container "${port}"; then
            sleep 2
            
            # Check if agent process is running
            local agent_running_before
            agent_running_before=$(docker exec "${container_name}" pgrep ssh-agent >/dev/null && echo "yes" || echo "no")
            
            if [[ "${agent_running_before}" == "yes" ]]; then
                # Stop container gracefully
                docker stop "${container_name}" >/dev/null 2>&1
                
                # Check logs for cleanup message
                local logs
                logs=$(docker logs "${container_name}" 2>&1)
                
                if echo "${logs}" | grep -q "SSH agent stopped"; then
                    log_test_pass "${test_name}"
                else
                    log_test_fail "${test_name} - Agent cleanup not confirmed in logs"
                    log_debug "Container logs: ${logs}"
                fi
            else
                log_test_fail "${test_name} - SSH agent was not running"
            fi
        else
            log_test_fail "${test_name} - Container failed to start"
        fi
    else
        log_test_fail "${test_name} - Failed to start container"
    fi
    
    cleanup_container "${container_name}"
}

# Generate test report
generate_report() {
    echo ""
    log_info "SSH Agent Test Results"
    log_info "======================"
    log_info "Tests run: ${TESTS_RUN}"
    log_info "Tests passed: ${TESTS_PASSED}"
    log_info "Tests failed: ${TESTS_FAILED}"
    
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        echo ""
        log_error "Failed tests:"
        for test in "${FAILED_TESTS[@]}"; do
            log_error "  - ${test}"
        done
        echo ""
        exit 1
    else
        echo ""
        log_info "All SSH agent tests passed! 🎉"
        echo ""
    fi
}

# Main function
main() {
    log_info "Starting SSH Agent Integration Tests..."

    # Parse command line arguments first so logs show the correct image
    parse_args "$@"

    log_info "Docker image: ${DOCKER_IMAGE}"
    
    # Check dependencies
    check_dependencies
    
    # Run tests
    test_agent_startup
    test_agent_with_keys
    test_agent_forwarding_config
    test_agent_environment
    test_ssh_connection_with_agent
    test_agent_socket_permissions
    test_agent_cleanup
    
    # Generate report
    generate_report
}

# Run main function
main "$@"
