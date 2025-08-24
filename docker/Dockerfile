# SSH Test Server - Debian slim base for minimal size with full SSH support
FROM debian:bookworm-slim

LABEL maintainer="SSH Test Server"
LABEL description="Configurable SSH server for integration testing"
LABEL version="1.0.0"

# Avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install OpenSSH server and utilities with aggressive size optimization
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openssh-server \
        bash \
        && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
              /usr/share/doc/* \
              /usr/share/man/* \
              /usr/share/locale/* \
              /tmp/* \
              /var/tmp/* \
    && mkdir -p /var/run/sshd /etc/ssh/ssh_host_keys

# Copy entrypoint script with correct permissions
COPY --chmod=755 docker/entrypoint.sh /usr/local/bin/entrypoint.sh

# Default environment variables
ENV SSH_USER=testuser \
    SSH_PASSWORD="" \
    SSH_AUTHORIZED_KEYS="" \
    SSH_HOST_KEYS="" \
    SSH_PERMIT_PASSWORD_AUTH=yes \
    SSH_PERMIT_ROOT_LOGIN=no \
    SSH_PERMIT_EMPTY_PASSWORDS=no \
    SSH_PORT=22 \
    SSH_DEBUG_LEVEL=0 \
    SSH_AUTH_METHODS="any" \
    SSH_MAX_AUTH_TRIES=6 \
    SSH_LOGIN_GRACE_TIME=120 \
    SSH_PERMIT_PUBKEY_AUTH=yes \
    SSH_CHALLENGE_RESPONSE_AUTH=no \
    SSH_USE_PAM=no \
    SSH_USE_DNS=no \
    SSH_X11_FORWARDING=no \
    SSH_AGENT_FORWARDING=no \
    SSH_TCP_FORWARDING=no \
    SSH_CUSTOM_CONFIG=""

# Expose SSH port (default 22, configurable via SSH_PORT)
EXPOSE 22

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD nc -z localhost ${SSH_PORT:-22} || exit 1

# Use entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Default command (will be handled by entrypoint)
CMD ["/usr/sbin/sshd", "-D", "-e"]