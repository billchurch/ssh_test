#!/bin/bash
set -e

# Dropbear SSH Test Server Entrypoint Script
# Configures Dropbear SSH server based on environment variables
# Designed for Alpine Linux with Dropbear (no SFTP subsystem)
# Reference: https://github.com/billchurch/webssh2/issues/483

# Color codes for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    if [[ "${SSH_DEBUG_LEVEL}" -gt 0 ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1" >&2
    fi
}

# Warn about unsupported environment variables
warn_unsupported_vars() {
    local unsupported_vars=(
        SSH_PERMIT_PUBKEY_AUTH
        SSH_PERMIT_EMPTY_PASSWORDS
        SSH_LOGIN_GRACE_TIME
        SSH_USE_DNS
        SSH_X11_FORWARDING
        SSH_CHALLENGE_RESPONSE_AUTH
        SSH_USE_PAM
        SSH_AUTH_METHODS
        SSH_HOST_KEYS
        SSH_CUSTOM_CONFIG
        SSH_AGENT_START
        SSH_AGENT_KEYS
        SSH_AGENT_SOCKET_PATH
        SSH_AGENT_FORWARDING
        SSH_KI_STATIC_OTP
    )

    for var in "${unsupported_vars[@]}"; do
        if [[ -n "${!var}" ]]; then
            log_warn "${var} is set but not supported by Dropbear (ignored)"
        fi
    done
}

# Validate environment variables
validate_env() {
    log_info "Validating environment variables..."

    # Validate SSH_PORT
    if [[ ! "${SSH_PORT}" =~ ^[0-9]+$ ]] || [[ "${SSH_PORT}" -lt 1 ]] || [[ "${SSH_PORT}" -gt 65535 ]]; then
        log_warn "Invalid SSH_PORT '${SSH_PORT}', using default port 22"
        export SSH_PORT=22
    fi

    # Validate SSH_DEBUG_LEVEL
    if [[ ! "${SSH_DEBUG_LEVEL}" =~ ^[0-3]$ ]]; then
        log_warn "Invalid SSH_DEBUG_LEVEL '${SSH_DEBUG_LEVEL}', using default 0"
        export SSH_DEBUG_LEVEL=0
    fi

    # Validate SSH_MAX_AUTH_TRIES
    if [[ ! "${SSH_MAX_AUTH_TRIES}" =~ ^[0-9]+$ ]] || [[ "${SSH_MAX_AUTH_TRIES}" -lt 1 ]]; then
        log_warn "Invalid SSH_MAX_AUTH_TRIES '${SSH_MAX_AUTH_TRIES}', using default 10"
        export SSH_MAX_AUTH_TRIES=10
    fi

    # Validate SSH_USER
    if [[ -z "${SSH_USER}" ]]; then
        log_error "SSH_USER cannot be empty"
        exit 1
    fi

    # Warn about unsupported env vars
    warn_unsupported_vars

    log_info "Environment validation completed"
}

# Create SSH user
create_ssh_user() {
    log_info "Creating SSH user '${SSH_USER}'..."

    # Check if user already exists
    if id "${SSH_USER}" &>/dev/null; then
        log_warn "User '${SSH_USER}' already exists, skipping creation"
        return 0
    fi

    # Alpine uses adduser (busybox)
    adduser -h "/home/${SSH_USER}" -s /bin/bash -D "${SSH_USER}"

    # Set password if provided
    if [[ -n "${SSH_PASSWORD}" ]]; then
        echo "${SSH_USER}:${SSH_PASSWORD}" | chpasswd
        log_info "Password set for user '${SSH_USER}'"
    else
        # Set a dummy password to unlock the account for SSH key authentication
        usermod -p '*' "${SSH_USER}"
        log_warn "No password set for user '${SSH_USER}' - account unlocked for key-only authentication"
    fi

    # Create .ssh directory
    mkdir -p "/home/${SSH_USER}/.ssh"
    chmod 700 "/home/${SSH_USER}/.ssh"
    chown "${SSH_USER}:${SSH_USER}" "/home/${SSH_USER}/.ssh"

    # Add authorized keys if provided
    if [[ -n "${SSH_AUTHORIZED_KEYS}" ]]; then
        log_info "Adding authorized keys for user '${SSH_USER}'"
        echo "${SSH_AUTHORIZED_KEYS}" > "/home/${SSH_USER}/.ssh/authorized_keys"
        chmod 600 "/home/${SSH_USER}/.ssh/authorized_keys"
        chown "${SSH_USER}:${SSH_USER}" "/home/${SSH_USER}/.ssh/authorized_keys"
        log_info "Authorized keys added ($(echo "${SSH_AUTHORIZED_KEYS}" | wc -l) keys)"
    fi

    log_info "User '${SSH_USER}' created successfully"
}

# Generate Dropbear host keys
setup_host_keys() {
    log_info "Setting up Dropbear host keys..."

    local key_types=("rsa" "ecdsa" "ed25519")

    for key_type in "${key_types[@]}"; do
        local key_file="/etc/dropbear/dropbear_${key_type}_host_key"
        if [[ ! -f "${key_file}" ]]; then
            log_debug "Generating ${key_type} host key..."
            dropbearkey -t "${key_type}" -f "${key_file}" >/dev/null 2>&1
            log_debug "Generated ${key_type} host key: ${key_file}"
        else
            log_debug "Host key already exists: ${key_file}"
        fi
    done

    # List generated keys for debugging
    if [[ "${SSH_DEBUG_LEVEL}" -gt 0 ]]; then
        log_debug "Available Dropbear host keys:"
        ls -la /etc/dropbear/dropbear_*_host_key 2>/dev/null | while read -r line; do
            log_debug "  ${line}"
        done
    fi

    log_info "Host keys setup completed"
}

# Build Dropbear CLI arguments
build_dropbear_args() {
    DROPBEAR_ARGS=()

    # Foreground mode (don't fork)
    DROPBEAR_ARGS+=("-F")

    # Enhanced mode - log to stderr for Docker log compatibility
    DROPBEAR_ARGS+=("-E")

    # Port
    DROPBEAR_ARGS+=("-p" "${SSH_PORT}")

    # Host keys
    local key_types=("rsa" "ecdsa" "ed25519")
    for key_type in "${key_types[@]}"; do
        local key_file="/etc/dropbear/dropbear_${key_type}_host_key"
        if [[ -f "${key_file}" ]]; then
            DROPBEAR_ARGS+=("-r" "${key_file}")
        fi
    done

    # Disable password auth if requested
    if [[ "${SSH_PERMIT_PASSWORD_AUTH}" == "no" ]]; then
        DROPBEAR_ARGS+=("-s")
        log_debug "Password authentication disabled (-s)"
    fi

    # Disallow root login if requested
    if [[ "${SSH_PERMIT_ROOT_LOGIN}" == "no" ]]; then
        DROPBEAR_ARGS+=("-w")
        log_debug "Root login disabled (-w)"
    fi

    # TCP forwarding
    if [[ "${SSH_TCP_FORWARDING}" == "no" ]]; then
        DROPBEAR_ARGS+=("-j" "-k")
        log_debug "TCP forwarding disabled (-j -k)"
    fi

    # Max auth tries
    if [[ "${SSH_MAX_AUTH_TRIES}" -gt 0 ]]; then
        DROPBEAR_ARGS+=("-T" "${SSH_MAX_AUTH_TRIES}")
        log_debug "Max auth tries: ${SSH_MAX_AUTH_TRIES}"
    fi

    # Idle timeout (Dropbear-specific)
    if [[ "${SSH_IDLE_TIMEOUT}" -gt 0 ]]; then
        DROPBEAR_ARGS+=("-I" "${SSH_IDLE_TIMEOUT}")
        log_debug "Idle timeout: ${SSH_IDLE_TIMEOUT} seconds"
    fi

    # Keepalive (Dropbear-specific)
    if [[ "${SSH_KEEPALIVE}" -gt 0 ]]; then
        DROPBEAR_ARGS+=("-K" "${SSH_KEEPALIVE}")
        log_debug "Keepalive: ${SSH_KEEPALIVE} seconds"
    fi

    # Note: Dropbear v2022.83 (Alpine 3.19) does not support runtime -v flags.
    # Debug verbosity is a compile-time option in this version.
    # SSH_DEBUG_LEVEL is still used by the entrypoint for its own log_debug() output.
    if [[ "${SSH_DEBUG_LEVEL}" -gt 0 ]]; then
        log_debug "SSH_DEBUG_LEVEL=${SSH_DEBUG_LEVEL} (entrypoint logging only; Dropbear lacks runtime -v)"
    fi

    log_debug "Dropbear args: ${DROPBEAR_ARGS[*]}"
}

# Setup MOTD (Message of the Day)
setup_motd() {
    log_info "Setting up MOTD..."

    local MOTD_FILE="/usr/local/share/motd.dropbear"

    if [[ -f "${MOTD_FILE}" ]]; then
        # Use sed for variable substitution
        sed -e "s/\${SSH_PORT}/${SSH_PORT}/g" \
            -e "s/\${SSH_USER}/${SSH_USER}/g" \
            -e "s/\${SSH_DEBUG_LEVEL}/${SSH_DEBUG_LEVEL}/g" \
            -e "s/\${SSH_PERMIT_PASSWORD_AUTH}/${SSH_PERMIT_PASSWORD_AUTH}/g" \
            "${MOTD_FILE}" > /etc/motd
        log_info "MOTD configured"
    else
        log_warn "MOTD file not found at ${MOTD_FILE}"
    fi
}

# Print startup information
print_startup_info() {
    echo ""
    log_info "Dropbear SSH Test Server Starting..."
    log_info "===================================="
    log_info "SSH Daemon: Dropbear"
    log_info "Port: ${SSH_PORT}"
    log_info "User: ${SSH_USER}"
    log_info "Password Auth: ${SSH_PERMIT_PASSWORD_AUTH}"
    log_info "Pubkey Auth: always enabled (Dropbear default)"
    log_info "SFTP: DISABLED (not installed)"
    log_info "SCP: ENABLED"
    log_info "TCP Forwarding: ${SSH_TCP_FORWARDING}"
    log_info "Debug Level: ${SSH_DEBUG_LEVEL}"

    if [[ -n "${SSH_AUTHORIZED_KEYS}" ]]; then
        log_info "Authorized Keys: $(echo "${SSH_AUTHORIZED_KEYS}" | wc -l) keys configured"
    fi

    if [[ "${SSH_IDLE_TIMEOUT}" -gt 0 ]]; then
        log_info "Idle Timeout: ${SSH_IDLE_TIMEOUT} seconds"
    fi

    if [[ "${SSH_KEEPALIVE}" -gt 0 ]]; then
        log_info "Keepalive: ${SSH_KEEPALIVE} seconds"
    fi

    log_info "===================================="

    # Display MOTD for direct exec sessions
    if [[ -f /etc/motd ]]; then
        echo ""
        cat /etc/motd
    fi
    echo ""
}

# Cleanup function
cleanup() {
    log_info "Received termination signal, shutting down..."

    # Stop Dropbear daemon if running
    if [[ -n "${DROPBEAR_PID}" ]] && kill -0 "${DROPBEAR_PID}" >/dev/null 2>&1; then
        log_debug "Stopping Dropbear daemon (PID ${DROPBEAR_PID})..."
        kill -TERM "${DROPBEAR_PID}" >/dev/null 2>&1 || true
        sleep 1
    fi

    exit 0
}

# Handle signals gracefully
trap cleanup TERM INT

# Main execution
main() {
    log_info "Dropbear SSH Test Server Entrypoint Starting..."

    # Validate environment
    validate_env

    # Create SSH user
    create_ssh_user

    # Setup host keys
    setup_host_keys

    # Setup MOTD
    setup_motd

    # Build Dropbear arguments
    build_dropbear_args

    # Print startup information
    print_startup_info

    log_info "Starting Dropbear daemon with args: ${DROPBEAR_ARGS[*]}"

    # Start Dropbear in background to keep this script as PID 1
    /usr/sbin/dropbear "${DROPBEAR_ARGS[@]}" &
    DROPBEAR_PID=$!
    log_debug "Dropbear started with PID ${DROPBEAR_PID}"

    # Wait for Dropbear process; traps will handle termination
    wait "${DROPBEAR_PID}"
}

# Run main function
main "$@"
