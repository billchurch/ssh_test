#!/bin/bash
set -e

# SSH Test Server Entrypoint Script
# Configures SSH server based on environment variables
# Compatible with both Alpine and Debian-based distributions

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

# Detect OS and set appropriate paths and commands
if [ -f /etc/alpine-release ]; then
    IS_ALPINE=true
    SFTP_SERVER_PATH="/usr/lib/ssh/sftp-server"
    log_debug "Detected Alpine Linux"
else
    IS_ALPINE=false
    SFTP_SERVER_PATH="/usr/lib/openssh/sftp-server"
    log_debug "Detected Debian-based system"
fi

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
        log_warn "Invalid SSH_MAX_AUTH_TRIES '${SSH_MAX_AUTH_TRIES}', using default 6"
        export SSH_MAX_AUTH_TRIES=6
    fi
    
    # Validate SSH_LOGIN_GRACE_TIME
    if [[ ! "${SSH_LOGIN_GRACE_TIME}" =~ ^[0-9]+$ ]]; then
        log_warn "Invalid SSH_LOGIN_GRACE_TIME '${SSH_LOGIN_GRACE_TIME}', using default 120"
        export SSH_LOGIN_GRACE_TIME=120
    fi
    
    # Validate SSH_USER
    if [[ -z "${SSH_USER}" ]]; then
        log_error "SSH_USER cannot be empty"
        exit 1
    fi
    
    # Ensure we have some form of authentication
    if [[ "${SSH_PERMIT_PASSWORD_AUTH}" != "yes" ]] && [[ "${SSH_PERMIT_PUBKEY_AUTH}" != "yes" ]] && [[ "${SSH_CHALLENGE_RESPONSE_AUTH}" != "yes" ]]; then
        if [[ -z "${SSH_AUTHORIZED_KEYS}" ]]; then
            log_error "No authentication method enabled and no authorized keys provided"
            exit 1
        fi
    fi
    
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
    
    # Create user with home directory (OS-appropriate syntax)
    if [ "$IS_ALPINE" = true ]; then
        # Alpine uses adduser (busybox)
        adduser -h "/home/${SSH_USER}" -s /bin/bash -D "${SSH_USER}"
    else
        # Debian/Ubuntu uses useradd
        useradd -m -s /bin/bash "${SSH_USER}"
    fi
    
    # Set password if provided
    if [[ -n "${SSH_PASSWORD}" ]]; then
        echo "${SSH_USER}:${SSH_PASSWORD}" | chpasswd
        log_info "Password set for user '${SSH_USER}'"
    else
        # Set a dummy password to unlock the account for SSH key authentication
        # The '*' password hash prevents password login but allows key-based auth
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

# Setup MOTD (Message of the Day)
setup_motd() {
    log_info "Setting up MOTD..."
    
    # Determine which MOTD file to use based on OS
    if [ "$IS_ALPINE" = true ]; then
        MOTD_FILE="/usr/local/share/motd.alpine"
    else
        MOTD_FILE="/usr/local/share/motd.debian"
    fi
    
    # Process MOTD file with environment variable substitution if it exists
    if [ -f "$MOTD_FILE" ]; then
        # Use envsubst if available, otherwise use sed
        if command -v envsubst >/dev/null 2>&1; then
            envsubst < "$MOTD_FILE" > /etc/motd
        else
            # Fallback to sed for basic variable substitution
            sed -e "s/\${SSH_PORT}/${SSH_PORT}/g" \
                -e "s/\${SSH_USER}/${SSH_USER}/g" \
                -e "s/\${SSH_DEBUG_LEVEL}/${SSH_DEBUG_LEVEL}/g" \
                -e "s/\${SSH_PERMIT_PASSWORD_AUTH}/${SSH_PERMIT_PASSWORD_AUTH}/g" \
                -e "s/\${SSH_PERMIT_PUBKEY_AUTH}/${SSH_PERMIT_PUBKEY_AUTH}/g" \
                -e "s/\${SSH_CHALLENGE_RESPONSE_AUTH}/${SSH_CHALLENGE_RESPONSE_AUTH}/g" \
                "$MOTD_FILE" > /etc/motd
        fi
        log_info "MOTD configured"
    else
        log_warn "MOTD file not found at $MOTD_FILE"
    fi
}

# Generate or install host keys
setup_host_keys() {
    log_info "Setting up SSH host keys..."
    
    if [[ -n "${SSH_HOST_KEYS}" ]]; then
        log_info "Installing provided host keys..."
        # SSH_HOST_KEYS should contain the private keys, one per line
        # Format: KEY_TYPE:BASE64_ENCODED_KEY
        echo "${SSH_HOST_KEYS}" | while IFS=: read -r key_type key_data; do
            if [[ -n "${key_type}" ]] && [[ -n "${key_data}" ]]; then
                key_file="/etc/ssh/ssh_host_${key_type}_key"
                echo "${key_data}" | base64 -d > "${key_file}"
                chmod 600 "${key_file}"
                ssh-keygen -y -f "${key_file}" > "${key_file}.pub"
                chmod 644 "${key_file}.pub"
                log_debug "Installed ${key_type} host key"
            fi
        done
        log_info "Host keys installation completed"
    else
        log_info "Generating new host keys..."
        # Generate host keys if they don't exist
        ssh-keygen -A
        log_info "Host keys generation completed"
    fi
    
    # List generated keys for debugging
    if [[ "${SSH_DEBUG_LEVEL}" -gt 0 ]]; then
        log_debug "Available host keys:"
        ls -la /etc/ssh/ssh_host_* | while read -r line; do
            log_debug "  ${line}"
        done
    fi
}

# Configure SSH daemon
configure_sshd() {
    log_info "Configuring SSH daemon..."
    
    # Backup original config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig
    
    # Create new sshd_config
    cat > /etc/ssh/sshd_config << EOF
# SSH Test Server Configuration
# Generated automatically by entrypoint script

# Network
Port ${SSH_PORT}
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

# Host keys
$(find /etc/ssh -name 'ssh_host_*_key' -type f | sed 's/^/HostKey /')

# Logging - Use stderr for Docker log compatibility
# Note: With -e flag, sshd logs to stderr regardless of syslog facility
SyslogFacility AUTH
LogLevel $(case ${SSH_DEBUG_LEVEL} in 0) echo "INFO";; 1) echo "VERBOSE";; 2) echo "DEBUG";; 3) echo "DEBUG3";; esac)

# Authentication
LoginGraceTime ${SSH_LOGIN_GRACE_TIME}
PermitRootLogin ${SSH_PERMIT_ROOT_LOGIN}
StrictModes yes
MaxAuthTries ${SSH_MAX_AUTH_TRIES}
MaxSessions 10

# Authentication methods
PubkeyAuthentication ${SSH_PERMIT_PUBKEY_AUTH}
PasswordAuthentication ${SSH_PERMIT_PASSWORD_AUTH}
ChallengeResponseAuthentication ${SSH_CHALLENGE_RESPONSE_AUTH}
$(if [ "$IS_ALPINE" != true ]; then echo "UsePAM ${SSH_USE_PAM}"; fi)
PermitEmptyPasswords ${SSH_PERMIT_EMPTY_PASSWORDS}

# Specify authentication methods if not 'any'
$(if [[ "${SSH_AUTH_METHODS}" != "any" ]]; then echo "AuthenticationMethods ${SSH_AUTH_METHODS}"; fi)

# Network settings
UseDNS ${SSH_USE_DNS}
TCPKeepAlive yes
ClientAliveInterval 60
ClientAliveCountMax 3

# Forwarding
X11Forwarding ${SSH_X11_FORWARDING}
AllowAgentForwarding ${SSH_AGENT_FORWARDING}
AllowTcpForwarding ${SSH_TCP_FORWARDING}
GatewayPorts no

# Security
IgnoreUserKnownHosts yes
IgnoreRhosts yes
HostbasedAuthentication no
PermitUserEnvironment no

# Display MOTD
PrintMotd yes

# Subsystem
Subsystem sftp ${SFTP_SERVER_PATH}

# Custom configuration
${SSH_CUSTOM_CONFIG}
EOF

    # Validate configuration
    if ! /usr/sbin/sshd -t -f /etc/ssh/sshd_config; then
        log_error "SSH configuration validation failed"
        log_error "Configuration:"
        cat /etc/ssh/sshd_config | sed 's/^/  /'
        exit 1
    fi
    
    log_info "SSH daemon configuration completed"
    
    if [[ "${SSH_DEBUG_LEVEL}" -gt 1 ]]; then
        log_debug "SSH configuration:"
        cat /etc/ssh/sshd_config | sed 's/^/  /'
    fi
}

# Print startup information
print_startup_info() {
    echo ""
    log_info "SSH Test Server Starting..."
    log_info "=========================="
    log_info "Port: ${SSH_PORT}"
    log_info "User: ${SSH_USER}"
    log_info "Password Auth: ${SSH_PERMIT_PASSWORD_AUTH}"
    log_info "Pubkey Auth: ${SSH_PERMIT_PUBKEY_AUTH}"
    log_info "Challenge-Response Auth: ${SSH_CHALLENGE_RESPONSE_AUTH}"
    log_info "Debug Level: ${SSH_DEBUG_LEVEL}"
    
    if [[ "${SSH_AUTH_METHODS}" != "any" ]]; then
        log_info "Auth Methods: ${SSH_AUTH_METHODS}"
    fi
    
    if [[ -n "${SSH_AUTHORIZED_KEYS}" ]]; then
        log_info "Authorized Keys: $(echo "${SSH_AUTHORIZED_KEYS}" | wc -l) keys configured"
    fi
    
    log_info "=========================="
    
    # Display MOTD for direct exec sessions
    if [ -f /etc/motd ]; then
        echo ""
        cat /etc/motd
    fi
    echo ""
}

# Main execution
main() {
    log_info "SSH Test Server Entrypoint Starting..."
    
    # Validate environment
    validate_env
    
    # Create SSH user
    create_ssh_user
    
    # Setup host keys
    setup_host_keys
    
    # Setup MOTD
    setup_motd
    
    # Configure SSH daemon
    configure_sshd
    
    # Print startup information
    print_startup_info
    
    # Prepare SSH daemon arguments  
    # Run SSH daemon in foreground mode to capture logs properly
    SSHD_ARGS=("-D" "-e")
    
    # Note: We intentionally do NOT add debug flags (-d, -dd, -ddd) here because
    # they force sshd into single-connection mode ("will not fork when running in debugging mode").
    # Instead, we rely on LogLevel in sshd_config for debugging output while maintaining 
    # multi-connection capability.
    log_debug "SSH debug level ${SSH_DEBUG_LEVEL} configured via LogLevel in sshd_config"
    
    # Add port if different from default
    if [[ "${SSH_PORT}" != "22" ]]; then
        SSHD_ARGS+=("-p" "${SSH_PORT}")
    fi
    
    # Add config file
    SSHD_ARGS+=("-f" "/etc/ssh/sshd_config")
    
    log_info "Starting SSH daemon with args: ${SSHD_ARGS[*]}"
    
    # Validate configuration before starting
    if ! /usr/sbin/sshd -t -f /etc/ssh/sshd_config; then
        log_error "SSH configuration validation failed before starting daemon"
        exit 1
    fi
    
    log_info "SSH daemon starting in foreground mode..."
    
    # Start SSH daemon in foreground mode - this will keep the container alive
    # and allow us to see all SSH logs in docker logs
    exec /usr/sbin/sshd "${SSHD_ARGS[@]}"
}

# Handle signals gracefully
trap 'log_info "Received termination signal, shutting down..."; exit 0' TERM INT

# Run main function
main "$@"