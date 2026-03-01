# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when
working with code in this repository.

## Project Overview

This is an SSH Test Server project - a fully configurable
Docker-based SSH server designed specifically for integration
testing, development, and SSH client validation. The project
provides a comprehensive testing environment for SSH connections
with multiple authentication methods and security configurations.

## Architecture

The system is built around a Docker container that runs OpenSSH
server with full runtime configurability:

- **Base**: Alpine Linux 3.19 for minimal footprint
- **SSH Server**: OpenSSH with comprehensive configuration options
- **Runtime Configuration**: All settings controlled via environment variables
- **Security**: Non-root execution, configurable authentication restrictions
- **Testing**: Comprehensive test suite with integration tests

### Key Components

- `docker/Dockerfile`: Multi-stage Docker build configuration
- `docker/entrypoint.sh`: Runtime configuration script that
  generates sshd_config
- `scripts/test-connection.sh`: Basic SSH connection testing
- `scripts/test-auth-methods.sh`: Authentication methods testing
- `tests/integration/run-tests.sh`: Comprehensive integration test suite
- `examples/docker-compose.yml`: Multiple deployment configurations

## Common Development Commands

### Building and Running

```bash
# Build Docker image
make build
# Or: docker build -f docker/Dockerfile -t ssh-test-server:dev .

# Run basic container
make run
# Or: docker run -d --name ssh-test-dev -p 2222:22 \
#   -e SSH_USER=testuser -e SSH_PASSWORD=testpass123 \
#   ssh-test-server:dev

# Run with debug mode
make run-debug

# Run with telnet enabled
make run-telnet
# Or: docker run -d --name ssh-test-dev -p 2222:22 -p 2323:23 \
#   -e SSH_USER=testuser -e SSH_PASSWORD=testpass123 \
#   -e TELNET_ENABLED=yes ssh-test-server:debian

# View logs
make logs
# Or: docker logs -f ssh-test-dev

# Get shell access
make shell
# Or: docker exec -it ssh-test-dev /bin/sh
```

### Testing Commands

```bash
# Run comprehensive integration tests
make test
# Or: ./tests/integration/run-tests.sh --image ssh-test-server:dev

# Run tests in parallel
make test-parallel

# Test basic connection
make test-connection
# Or: ./scripts/test-connection.sh --host localhost \
#   --port 2222 --user testuser --password testpass123

# Test authentication methods
make test-auth
# Or: ./scripts/test-auth-methods.sh \
#   --container ssh-test-dev --user testuser --generate-keys

# Run full CI pipeline locally
make ci-full
```

### Docker Compose Profiles

```bash
# Basic password authentication
docker-compose --profile basic up -d

# Public key authentication only  
docker-compose --profile pubkey up -d

# Security hardened configuration
docker-compose --profile hardened up -d

# Development setup with volume mounts
docker-compose --profile dev up -d
```

### Apple Container Commands (macOS with Apple Silicon)

Apple Container is a native macOS tool for running Linux
containers. All Docker commands can be replaced with `container`
for Apple Silicon Macs running macOS 26+.

**First-time setup required:**

```bash
# Start the container system (one-time setup, will prompt to install kernel)
container system start
```

```bash
# Build image (using Docker buildx, then use with container)
make build

# Run basic container
container run -d --name ssh-test-dev -p 2222:22 \
  -e SSH_USER=testuser -e SSH_PASSWORD=testpass123 \
  ghcr.io/billchurch/ssh_test:alpine

# Run with debug mode
container run -d --name ssh-test-debug -p 2222:22 \
  -e SSH_USER=testuser -e SSH_PASSWORD=testpass123 \
  -e SSH_DEBUG_LEVEL=3 \
  ghcr.io/billchurch/ssh_test:alpine

# View logs
container logs -f ssh-test-dev

# Get shell access
container exec -it ssh-test-dev /bin/sh

# Check container status
container ps

# Health check
container inspect ssh-test-dev | grep -A5 Health

# Cleanup
container stop ssh-test-dev && container rm ssh-test-dev

# Test connection (same as Docker)
ssh -p 2222 testuser@localhost

# Run tests against Apple Container
./tests/integration/run-tests.sh --container ssh-test-dev
```

**Note**: Apple Container requires macOS 26 (latest beta) and
Apple Silicon. All testing scripts work identically with
containers started by either Docker or Apple Container.

### Development Workflow

```bash
# Full development cycle
make dev  # Clean, build, and run for development

# Check container status
make status

# Health check
make health

# Generate test SSH keys
make generate-keys

# Cleanup
make clean
```

## Configuration System

The SSH server is entirely configured through environment variables at runtime:

### Authentication Configuration

- `SSH_USER`: Username to create (required)
- `SSH_PASSWORD`: Password for authentication (required even
  for key-only auth to unlock account)
- `SSH_AUTHORIZED_KEYS`: SSH public keys (newline separated)
- `SSH_PERMIT_PASSWORD_AUTH`: Enable/disable password auth (yes/no)
- `SSH_PERMIT_PUBKEY_AUTH`: Enable/disable public key auth (yes/no)
- `SSH_CHALLENGE_RESPONSE_AUTH`: Enable keyboard-interactive auth (yes/no)

**Important**: Always set `SSH_PASSWORD` even when using only
public key authentication. Without a password, the user account
may remain locked and prevent key-based authentication from
working.

### Security Configuration

- `SSH_PERMIT_ROOT_LOGIN`: Allow root login (yes/no)
- `SSH_MAX_AUTH_TRIES`: Maximum authentication attempts
- `SSH_LOGIN_GRACE_TIME`: Login timeout in seconds
- `SSH_PERMIT_EMPTY_PASSWORDS`: Allow empty passwords (yes/no)

### Network and Debug

- `SSH_PORT`: SSH server port (default: 22)
- `SSH_DEBUG_LEVEL`: Debug verbosity (0-3)
- `SSH_USE_DNS`: Enable DNS lookups (yes/no)

### Telnet Configuration

- `TELNET_ENABLED`: Enable telnet server (yes/no, default: no)
- `TELNET_PORT`: Telnet server port (default: 23)

## Testing Architecture

The project includes a comprehensive testing framework:

### Test Scripts

1. **Basic Connection Test**
   (`scripts/test-connection.sh`): Tests connectivity and
   basic SSH functionality
2. **Authentication Methods Test**
   (`scripts/test-auth-methods.sh`): Comprehensive
   authentication testing with key generation
3. **Integration Test Suite**
   (`tests/integration/run-tests.sh`): Full integration
   tests with parallel execution support

### Test Scenarios Covered

- Basic SSH connectivity and handshake
- Password authentication (valid/invalid passwords)
- Public key authentication (multiple key types: RSA, Ed25519, ECDSA)
- Custom port configurations
- Security hardening validation
- Environment variable validation
- Authentication method restrictions
- Debug mode functionality

## Development Best Practices

- All SSH configuration happens at runtime through environment variables
- The entrypoint script validates all environment variables
  and provides sensible defaults
- Container logs provide detailed debug information when SSH_DEBUG_LEVEL > 0
- Test scripts support both individual testing and comprehensive test suites
- Docker Compose provides multiple preconfigured scenarios for common use cases

## Use Cases

This SSH test server is ideal for:

- Testing SSH clients and automation tools
- WebSSH client development and testing
- CI/CD pipeline SSH connectivity validation
- SSH authentication method testing
- Security configuration validation
- Development environments requiring consistent SSH targets

## Important Notes

- Container is designed for testing environments, not production use
- All test scripts require `sshpass` for password authentication testing
- Integration tests automatically generate and cleanup temporary SSH keys
- The entrypoint script provides comprehensive logging and error handling
- Security scanning and SBOM generation are part of the CI/CD pipeline
