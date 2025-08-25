# SSH Test Server

[![Build and Push](https://github.com/billchurch/ssh_test/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/billchurch/ssh_test/actions/workflows/build-and-push.yml)
[![Integration Tests](https://github.com/billchurch/ssh_test/actions/workflows/test.yml/badge.svg)](https://github.com/billchurch/ssh_test/actions/workflows/test.yml)

A fully configurable SSH server Docker container designed specifically for integration testing, development, and SSH client validation. Built with security best practices and complete runtime configurability.

**Available in two optimized variants:**
- **Debian-based** (`ssh-test-server:debian`): 118MB - Maximum compatibility with full GNU toolchain
- **Alpine-based** (`ssh-test-server:alpine`): 13.8MB - Ultra-minimal footprint for resource-constrained environments

## Features

- 🔧 **Fully Configurable**: All SSH settings configurable via environment variables
- 🔐 **Multiple Auth Methods**: Password, public key, and keyboard-interactive authentication
- 🏗️ **Multi-Architecture**: Supports AMD64 and ARM64 architectures
- 🛡️ **Security Focused**: Configurable security hardening options
- 🐛 **Debug Support**: Adjustable SSH debug levels with proper logging
- 📊 **CI/CD Ready**: Automated builds, testing, and container registry publishing
- 🧪 **Testing Tools**: Comprehensive test scripts and integration tests included

## Quick Start

### Choosing Your Image

Choose the image variant that best fits your needs:

```bash
# Alpine - Ultra-minimal (13.8MB)
docker pull ssh-test-server:alpine

# Debian - Full compatibility (118MB, default)
docker pull ssh-test-server:debian
# or 
docker pull ssh-test-server:latest  # same as debian
```

### Using Docker

```bash
# Basic password authentication (Alpine - minimal)
docker run -d --name ssh-test-alpine \
  -p 2225:22 \
  -e SSH_USER=testuser \
  -e SSH_PASSWORD=testpass123 \
  ssh-test-server:alpine

# Basic password authentication (Debian - full compatibility)
docker run -d --name ssh-test-debian \
  -p 2224:22 \
  -e SSH_USER=testuser \
  -e SSH_PASSWORD=testpass123 \
  ssh-test-server:debian

# Test the connections
ssh -p 2225 testuser@localhost  # Alpine
ssh -p 2224 testuser@localhost  # Debian
```

### Using Docker Compose

```bash
# Clone the repository
git clone https://github.com/billchurch/ssh-test-server.git
cd ssh-test-server/examples

# Run Alpine version (minimal)
docker-compose --profile alpine up -d

# Run Debian version (full compatibility)
docker-compose --profile debian up -d

# Run both versions simultaneously
docker-compose --profile all up -d

# Traditional profiles still available
docker-compose --profile basic up -d        # Basic password auth
docker-compose --profile pubkey up -d       # Public key auth only
docker-compose --profile hardened up -d     # Security hardened
```

## Configuration

All configuration is done through environment variables:

### Basic Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SSH_USER` | `testuser` | SSH username to create |
| `SSH_PASSWORD` | *(empty)* | Password for the SSH user |
| `SSH_PORT` | `22` | SSH server port |
| `SSH_DEBUG_LEVEL` | `0` | Debug level (0=none, 1=verbose, 2=debug, 3=debug3) |

### Authentication Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SSH_PERMIT_PASSWORD_AUTH` | `yes` | Enable password authentication |
| `SSH_PERMIT_PUBKEY_AUTH` | `yes` | Enable public key authentication |
| `SSH_CHALLENGE_RESPONSE_AUTH` | `no` | Enable keyboard-interactive auth |
| `SSH_AUTHORIZED_KEYS` | *(empty)* | SSH public keys (newline separated) |
| `SSH_AUTH_METHODS` | `any` | Specific auth methods to require |

### Security Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SSH_PERMIT_ROOT_LOGIN` | `no` | Allow root login |
| `SSH_PERMIT_EMPTY_PASSWORDS` | `no` | Allow empty passwords |
| `SSH_MAX_AUTH_TRIES` | `6` | Maximum authentication attempts |
| `SSH_LOGIN_GRACE_TIME` | `120` | Login grace time in seconds |
| `SSH_USE_DNS` | `no` | Perform DNS lookups |

### Forwarding Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SSH_X11_FORWARDING` | `no` | Enable X11 forwarding |
| `SSH_AGENT_FORWARDING` | `no` | Enable SSH agent forwarding |
| `SSH_TCP_FORWARDING` | `no` | Enable TCP forwarding |

### Advanced Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SSH_HOST_KEYS` | *(auto-generated)* | Custom host keys (base64 encoded) |
| `SSH_CUSTOM_CONFIG` | *(empty)* | Additional sshd_config directives |
| `SSH_USE_PAM` | `no` | Use PAM for authentication |

## Usage Examples

### Password Authentication Only

```bash
docker run -d --name ssh-password-test \
  -p 2224:22 \
  -e SSH_USER=testuser \
  -e SSH_PASSWORD=secure123 \
  -e SSH_PERMIT_PASSWORD_AUTH=yes \
  -e SSH_PERMIT_PUBKEY_AUTH=no \
  ghcr.io/billchurch/ssh-test-server:latest
```

### Public Key Authentication Only

```bash
# Generate a test key
ssh-keygen -t ed25519 -f test_key -N ""

# Start container with public key
docker run -d --name ssh-key-test \
  -p 2224:22 \
  -e SSH_USER=keyuser \
  -e "SSH_AUTHORIZED_KEYS=$(cat test_key.pub)" \
  -e SSH_PERMIT_PASSWORD_AUTH=no \
  -e SSH_PERMIT_PUBKEY_AUTH=yes \
  ghcr.io/billchurch/ssh-test-server:latest

# Connect with the key
ssh -i test_key -p 2224 keyuser@localhost
```

**Note:** When no password is provided (`SSH_PASSWORD` not set), the user account is automatically unlocked by setting a dummy password hash (`*`) to enable SSH key authentication while still preventing password logins.

### Security Hardened Configuration

```bash
docker run -d --name ssh-secure-test \
  -p 2224:22 \
  -e SSH_USER=secureuser \
  -e SSH_PASSWORD=VerySecureP@ss123 \
  -e SSH_PERMIT_ROOT_LOGIN=no \
  -e SSH_MAX_AUTH_TRIES=3 \
  -e SSH_LOGIN_GRACE_TIME=60 \
  -e SSH_USE_DNS=no \
  -e SSH_X11_FORWARDING=no \
  -e SSH_AGENT_FORWARDING=no \
  -e SSH_TCP_FORWARDING=no \
  ghcr.io/billchurch/ssh-test-server:latest
```

### Debug Mode

```bash
docker run -d --name ssh-debug-test \
  -p 2224:22 \
  -e SSH_USER=debuguser \
  -e SSH_PASSWORD=debugpass \
  -e SSH_DEBUG_LEVEL=3 \
  ghcr.io/billchurch/ssh-test-server:latest

# View debug logs
docker logs -f ssh-debug-test
```

## Testing Tools

The project includes comprehensive testing tools:

### Basic Connection Test

```bash
# Test password authentication
./scripts/test-connection.sh --host localhost --port 2224 --user testuser --password testpass123

# Test public key authentication
./scripts/test-connection.sh --host localhost --port 2224 --user testuser --key ~/.ssh/id_rsa

# Verbose mode
./scripts/test-connection.sh --host localhost --port 2224 --user testuser --password testpass123 --verbose
```

### Authentication Methods Test

```bash
# Test against a running container
./scripts/test-auth-methods.sh --container ssh-test-server --user testuser

# Generate test keys and run comprehensive tests
./scripts/test-auth-methods.sh --container ssh-test-server --user testuser --generate-keys --cleanup-keys
```

### Integration Test Suite

```bash
# Run full integration tests
./tests/integration/run-tests.sh

# Run tests with custom image
./tests/integration/run-tests.sh --image your-custom-image:latest

# Run tests in parallel with reporting
./tests/integration/run-tests.sh --parallel --report test-results.txt
```

## Development

### Building the Images

```bash
# Build both variants
make build-all

# Build specific variants
make build-debian    # Debian-based image
make build-alpine    # Alpine-based image

# Build for local testing
make build-dev       # Development version (Debian)

# Build multi-architecture (requires buildx)
docker buildx build --platform linux/amd64,linux/arm64 -f docker/Dockerfile -t ssh-test-server:multi .
```

### Running Tests

```bash
# Test both image variants
make test-all

# Test specific variants
make test-debian     # Test Debian image
make test-alpine     # Test Alpine image

# Run connection tests
make test-connection-debian   # Test Debian container connection
make test-connection-alpine   # Test Alpine container connection

# Run authentication tests  
make test-auth-debian        # Test Debian auth methods
make test-auth-alpine        # Test Alpine auth methods

# Compare image sizes
make compare-sizes

# Full integration test with build
make integration-test        # Build both + test both
```

### Contributing

We welcome contributions! This project uses automated releases and conventional commit messages.

**Quick Start:**
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make changes following our [contribution guidelines](CONTRIBUTING.md)
4. Use [conventional commit messages](https://conventionalcommits.org/): `feat: add new feature`
5. Run tests: `./tests/integration/run-tests.sh`
6. Submit a pull request

**Important:** Please read our [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on:
- Conventional commit message format
- Development workflow
- Testing requirements  
- Release process
- Code style guidelines

## CI/CD Pipeline

The project uses GitHub Actions for:

- **Multi-architecture builds** for AMD64 and ARM64
- **Automated testing** with comprehensive integration tests
- **Security scanning** with Trivy vulnerability scanner
- **Container publishing** to GitHub Container Registry
- **SBOM generation** for supply chain security

### GitHub Container Registry

Images are automatically published to GitHub Container Registry:

```bash
# Latest stable release
docker pull ghcr.io/billchurch/ssh-test-server:latest

# Specific version
docker pull ghcr.io/billchurch/ssh-test-server:v1.0.0

# Development builds
docker pull ghcr.io/billchurch/ssh-test-server:main
```

## Use Cases

### Integration Testing

Perfect for testing SSH clients, automation tools, and deployment scripts:

```bash
# Start test environment
docker-compose --profile basic up -d

# Run your SSH client tests
pytest tests/ssh_client_tests.py

# Cleanup
docker-compose --profile basic down
```

### WebSSH Testing

Ideal for testing web-based SSH clients like WebSSH2:

```bash
# Start SSH test server
docker run -d --name webssh-test \
  -p 4444:22 \
  -e SSH_USER=webuser \
  -e SSH_PASSWORD=webpass123 \
  -e SSH_DEBUG_LEVEL=2 \
  ghcr.io/billchurch/ssh-test-server:latest

# Configure your WebSSH client to connect to localhost:4444
```

### Development Environment

Use as a consistent SSH target for development:

```bash
# Development setup with volume mounts
docker run -d --name dev-ssh \
  -p 2224:22 \
  -e SSH_USER=developer \
  -e SSH_PASSWORD=devpass \
  -v ./workspace:/home/developer/workspace \
  ghcr.io/billchurch/ssh-test-server:latest
```

## Troubleshooting

### Common Issues

**Container fails to start:**
```bash
# Check container logs
docker logs container-name

# Verify environment variables
docker inspect container-name | jq '.Config.Env'
```

**SSH connection refused:**
```bash
# Test port connectivity
nc -zv localhost 2224

# Check if SSH service is running
docker exec container-name ps aux | grep sshd
```

**Authentication failures:**
```bash
# Enable debug mode
docker run ... -e SSH_DEBUG_LEVEL=3 ...

# Check authentication configuration
docker exec container-name cat /etc/ssh/sshd_config
```

**SSH Public Key Authentication Issues:**

When using public key authentication without setting a password (SSH_PASSWORD not provided), the container automatically unlocks the user account to allow key-based authentication. This is necessary because:

1. Linux locks user accounts that have no password set (marked with `!` in `/etc/shadow`)
2. SSH daemon refuses authentication to locked accounts, even with valid SSH keys
3. The entrypoint script sets a dummy password hash (`*`) which:
   - Unlocks the account for SSH key authentication
   - Still prevents password-based login (no valid password can match `*`)

If you experience issues with key authentication:
```bash
# Check if user account is locked
docker exec container-name grep username /etc/shadow
# If you see '!' or '!!' in the password field, the account is locked

# Manually unlock (if needed)
docker exec container-name usermod -p '*' username

# Verify SSH key is properly set
docker exec container-name cat /home/username/.ssh/authorized_keys
```

### Debug Mode

Enable maximum debug output:

```bash
docker run -d --name ssh-debug \
  -p 2224:22 \
  -e SSH_USER=testuser \
  -e SSH_PASSWORD=testpass \
  -e SSH_DEBUG_LEVEL=3 \
  ghcr.io/billchurch/ssh-test-server:latest

# Watch debug logs in real-time
docker logs -f ssh-debug
```

## Security Considerations

While designed for testing, security best practices are followed:

- Non-root user execution when possible
- Configurable authentication restrictions
- No default passwords in production images
- Regular security updates via automated rebuilds  
- Minimal attack surface with optimized Debian slim base

**Note**: This container is designed for testing environments. Do not expose it directly to the internet without additional security measures.

## Choosing Between Alpine and Debian

### Use Alpine When:
- **Size matters**: Ultra-minimal 13.8MB footprint
- **Resource-constrained environments**: Kubernetes pods, edge computing
- **Fast deployment**: Quicker download and startup times
- **Security**: Smaller attack surface with minimal components
- **Simple SSH testing**: Basic SSH client validation

### Use Debian When:
- **Maximum compatibility**: Full GNU toolchain and libraries  
- **Complex applications**: Applications requiring specific libraries
- **Legacy systems**: Compatibility with older SSH clients
- **Development**: More debugging tools and utilities available
- **Production-like testing**: Closer to typical server environments

### Performance Comparison:
| Metric | Alpine | Debian |
|--------|--------|--------|
| **Image Size** | 13.8MB | 118MB |
| **Download Time** | ~2 seconds | ~15 seconds |
| **Memory Usage** | ~8MB | ~20MB |
| **Startup Time** | ~1 second | ~2 seconds |
| **Compatibility** | Good | Excellent |

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and changes.

## Support

- 🐛 **Issues**: Report bugs and feature requests on [GitHub Issues](https://github.com/billchurch/ssh-test-server/issues)
- 📖 **Documentation**: Comprehensive documentation in this README and code comments
- 💬 **Discussions**: Community support via [GitHub Discussions](https://github.com/billchurch/ssh-test-server/discussions)

## Acknowledgments

- **Debian variant**: Built with [Debian](https://www.debian.org/) bookworm-slim for optimal size and compatibility (118MB)
- **Alpine variant**: Built with [Alpine Linux](https://alpinelinux.org/) for ultra-minimal footprint (13.8MB)
- Uses [OpenSSH](https://www.openssh.com/) for robust SSH implementation
- Optimized Docker images with smart OS detection and adaptive configuration
- Dual-architecture support with 88% size reduction possible via Alpine
- Inspired by the need for better SSH integration testing tools