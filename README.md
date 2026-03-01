# SSH Test Server

[![Build and Push](https://github.com/billchurch/ssh_test/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/billchurch/ssh_test/actions/workflows/build-and-push.yml)
[![Integration Tests](https://github.com/billchurch/ssh_test/actions/workflows/test.yml/badge.svg)](https://github.com/billchurch/ssh_test/actions/workflows/test.yml)

A fully configurable SSH server Docker container designed specifically for integration testing, development, and SSH client validation. Built with security best practices and complete runtime configurability.

**Available in three optimized variants:**

- **Debian-based** (`ghcr.io/billchurch/ssh_test:debian`): 118MB - Maximum compatibility with full GNU toolchain
- **Alpine-based** (`ghcr.io/billchurch/ssh_test:alpine`): 13.8MB - Ultra-minimal footprint for resource-constrained environments
- **Dropbear** (`ghcr.io/billchurch/ssh_test:dropbear`): ~5MB - BusyBox-style SSH with SCP but **no SFTP** ([webssh2 #483](https://github.com/billchurch/webssh2/issues/483))

## Features

- 🔧 **Fully Configurable**: All SSH settings configurable via environment variables
- 🔐 **Multiple Auth Methods**: Password, public key, and keyboard-interactive authentication
- 🏗️ **Multi-Architecture**: Supports AMD64 and ARM64 architectures
- 🍎 **Apple Container Ready**: Native support for Apple Container on Apple Silicon Macs
- 🛡️ **Security Focused**: Configurable security hardening options
- 🐛 **Debug Support**: Adjustable SSH debug levels with proper logging
- 📊 **CI/CD Ready**: Automated builds, testing, and container registry publishing
- 🧪 **Testing Tools**: Comprehensive test scripts and integration tests included
- 📡 **Optional Telnet**: Built-in telnet server for terminal client testing (Debian only)

## Quick Start

You can run the SSH test server using Docker, Docker Compose, or Apple Container (for macOS with Apple Silicon).

### Choosing Your Image

Choose the image variant that best fits your needs:

```bash
# Alpine - Ultra-minimal (13.8MB)
docker pull ghcr.io/billchurch/ssh_test:alpine

# Debian - Full compatibility (118MB, default)
docker pull ghcr.io/billchurch/ssh_test:debian
# or
docker pull ghcr.io/billchurch/ssh_test:latest  # same as debian

# Dropbear - SCP only, no SFTP (~5MB)
docker pull ghcr.io/billchurch/ssh_test:dropbear
```

### Using Docker

```bash
# Basic password authentication (Alpine - minimal)
docker run -d --name ssh-test-alpine \
  -p 2225:22 \
  -e SSH_USER=testuser \
  -e SSH_PASSWORD=testpass123 \
  ghcr.io/billchurch/ssh_test:alpine

# Basic password authentication (Debian - full compatibility)
docker run -d --name ssh-test-debian \
  -p 2224:22 \
  -e SSH_USER=testuser \
  -e SSH_PASSWORD=testpass123 \
  ghcr.io/billchurch/ssh_test:debian

# Dropbear - SCP only, no SFTP (simulates BusyBox devices)
docker run -d --name ssh-test-dropbear \
  -p 2226:22 \
  -e SSH_USER=testuser \
  -e SSH_PASSWORD=testpass123 \
  ghcr.io/billchurch/ssh_test:dropbear

# Test the connections
ssh -p 2225 testuser@localhost  # Alpine
ssh -p 2224 testuser@localhost  # Debian
ssh -p 2226 testuser@localhost  # Dropbear
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

# Run Dropbear version (SCP only, no SFTP)
docker-compose --profile dropbear up -d

# Telnet server (Debian with telnet enabled)
docker-compose --profile telnet up -d

# Traditional profiles still available
docker-compose --profile basic up -d        # Basic password auth
docker-compose --profile pubkey up -d       # Public key auth only
docker-compose --profile hardened up -d     # Security hardened
docker-compose --profile scp-only up -d     # SCP-only testing alias
```

### Using Apple Container (macOS with Apple Silicon)

[Apple Container](https://github.com/apple/container) is Apple's native tool for running Linux containers as lightweight VMs on Apple Silicon Macs. The SSH test server works seamlessly with Apple Container since it produces OCI-compatible images.

#### Requirements

- Mac with Apple Silicon (M1/M2/M3/M4)
- macOS 26 (latest beta)
- Apple Container installed: `brew install apple/tools/container`

#### First-Time Setup

Before running containers, start the container system (one-time setup):

```bash
# Start the container system (will prompt to install kernel if needed)
container system start
```

The first time you run this, it will prompt to install the recommended default kernel. Accept the prompt to continue.

#### Basic Usage

```bash
# Pull and run Alpine variant (minimal - 13.8MB)
container run --rm -d --name ssh-test-alpine \
  -p 2224:22 \
  -e SSH_USER=testuser \
  -e SSH_PASSWORD=testpassword \
  --cpus 1 \
  --memory 96mb \
  ghcr.io/billchurch/ssh_test:alpine

# Pull and run Debian variant (full compatibility - 118MB)
container run --rm -d --name ssh-test-debian \
  -p 2224:22 \
  -e SSH_USER=testuser \
  -e SSH_PASSWORD=testpass123 \
  --cpus 1 \
  --memory 96mb \
  ghcr.io/billchurch/ssh_test:debian

# Test the connections
ssh -p 2225 testuser@localhost  # Alpine
ssh -p 2224 testuser@localhost  # Debian

# View logs
container logs ssh-test-alpine

# Stop and remove
container stop ssh-test-alpine
container rm ssh-test-alpine
```

#### Public Key Authentication with Apple Container

```bash
# Generate a test key
ssh-keygen -t ed25519 -f test_key -N ""

# Start container with public key
container run -d --name ssh-key-test \
  -p 2224:22 \
  -e SSH_USER=keyuser \
  -e "SSH_AUTHORIZED_KEYS=$(cat test_key.pub)" \
  -e SSH_PERMIT_PASSWORD_AUTH=no \
  -e SSH_PERMIT_PUBKEY_AUTH=yes \
  ghcr.io/billchurch/ssh_test:alpine

# Connect with the key
ssh -i test_key -p 2224 keyuser@localhost
```

**Note**: All Docker examples in this README work with Apple Container by replacing `docker` with `container`. Apple Container uses the same command-line interface and options as Docker.

## Configuration

All configuration is done through environment variables:

### Basic Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `SSH_USER` | `testuser` | SSH username to create |
| `SSH_PASSWORD` | *(empty)* | Password for the SSH user |
| `SSH_PORT` | `22` | SSH server port |
| `SSH_DEBUG_LEVEL` | `0` | Debug level (0=none, 1=verbose, 2=debug, 3=debug3) |

### Authentication Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `SSH_PERMIT_PASSWORD_AUTH` | `yes` | Enable password authentication |
| `SSH_PERMIT_PUBKEY_AUTH` | `yes` | Enable public key authentication |
| `SSH_CHALLENGE_RESPONSE_AUTH` | `no` | Enable keyboard-interactive auth |
| `SSH_AUTHORIZED_KEYS` | *(empty)* | SSH public keys (newline separated) |
| `SSH_AUTH_METHODS` | `any` | Specific auth methods to require |

### Security Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `SSH_PERMIT_ROOT_LOGIN` | `no` | Allow root login |
| `SSH_PERMIT_EMPTY_PASSWORDS` | `no` | Allow empty passwords |
| `SSH_MAX_AUTH_TRIES` | `6` | Maximum authentication attempts |
| `SSH_LOGIN_GRACE_TIME` | `120` | Login grace time in seconds |
| `SSH_USE_DNS` | `no` | Perform DNS lookups |

### Forwarding Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `SSH_X11_FORWARDING` | `no` | Enable X11 forwarding |
| `SSH_AGENT_FORWARDING` | `no` | Enable SSH agent forwarding |
| `SSH_TCP_FORWARDING` | `no` | Enable TCP forwarding |

### Telnet Configuration (Debian Only)

The Debian image includes an optional telnet server for testing terminal clients against a plaintext protocol. Disabled by default.

| Variable | Default | Description |
| --- | --- | --- |
| `TELNET_ENABLED` | `no` | Enable telnet server (`yes`/`no`) |
| `TELNET_PORT` | `23` | Telnet server port |

Authentication reuses `SSH_USER` and `SSH_PASSWORD` — telnet spawns `/bin/login` which authenticates against the system user.

### SSH Agent Configuration

The SSH test server includes comprehensive SSH agent support for testing agent-based authentication and forwarding scenarios.

| Variable | Default | Description |
| --- | --- | --- |
| `SSH_AGENT_START` | `no` | Start internal SSH agent in container |
| `SSH_AGENT_KEYS` | *(empty)* | Base64-encoded private keys to load into agent (newline-separated) |
| `SSH_AGENT_SOCKET_PATH` | `/tmp/ssh-agent.sock` | Custom path for SSH agent socket |

#### SSH Agent Features

- **Internal Agent**: Start an SSH agent inside the container with `SSH_AGENT_START=yes`
- **Key Loading**: Automatically load private keys into the agent using `SSH_AGENT_KEYS`
- **Agent Forwarding**: Allow client agents to be forwarded with `SSH_AGENT_FORWARDING=yes`
- **Custom Socket**: Use custom socket paths for testing specific scenarios
- **Environment Setup**: Automatically configures user environment for agent access

#### SSH Agent Security Notes

⚠️ **Important**: The `SSH_AGENT_KEYS` variable contains sensitive private key data. In production or CI/CD environments:

- Load keys from secure environment variables or secrets management
- Never commit private keys to version control
- Use temporary keys for testing when possible
- Consider using key passphrases for additional security

### Advanced Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `SSH_HOST_KEYS` | *(auto-generated)* | Custom host keys (base64 encoded) |
| `SSH_CUSTOM_CONFIG` | *(empty)* | Additional sshd_config directives |
| `SSH_USE_PAM` | `no` | Use PAM for authentication |

#### SSH_CUSTOM_CONFIG Examples

The `SSH_CUSTOM_CONFIG` environment variable allows you to add any additional SSH configuration directives that aren't explicitly handled by other environment variables. Multiple directives can be stacked using newlines.

```bash
# Allow specific environment variables from SSH client
docker run -d \
  -p 2244:22 \
  -e SSH_USER=testuser \
  -e SSH_PASSWORD=testpassword \
  -e SSH_AUTHORIZED_KEYS="$(cat ./test-keys/*.pub)" \
  -e SSH_DEBUG_LEVEL=3 \
  -e SSH_PERMIT_PASSWORD_AUTH=yes \
  -e SSH_PERMIT_PUBKEY_AUTH=yes \
  -e SSH_CUSTOM_CONFIG=$'PermitUserEnvironment yes\nAcceptEnv FOO' \
  ghcr.io/billchurch/ssh_test:alpine

# Multiple custom configurations
docker run -d \
  -e SSH_CUSTOM_CONFIG=$'MaxSessions 10\nClientAliveInterval 30\nClientAliveCountMax 3' \
  ghcr.io/billchurch/ssh_test:alpine
```

## Usage Examples

### Password Authentication Only

```bash
docker run -d --name ssh-password-test \
  -p 2224:22 \
  -e SSH_USER=testuser \
  -e SSH_PASSWORD=secure123 \
  -e SSH_PERMIT_PASSWORD_AUTH=yes \
  -e SSH_PERMIT_PUBKEY_AUTH=no \
  ghcr.io/billchurch/ssh_test:latest
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
  ghcr.io/billchurch/ssh_test:latest

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
  ghcr.io/billchurch/ssh_test:latest
```

### Debug Mode

```bash
docker run -d --name ssh-debug-test \
  -p 2224:22 \
  -e SSH_USER=debuguser \
  -e SSH_PASSWORD=debugpass \
  -e SSH_DEBUG_LEVEL=3 \
  ghcr.io/billchurch/ssh_test:latest

# View debug logs
docker logs -f ssh-debug-test
```

### SSH Agent Examples

#### Basic Agent with Forwarding

```bash
docker run -d --name ssh-agent-test \
  -p 2224:22 \
  -e SSH_USER=agentuser \
  -e SSH_PASSWORD=agentpass \
  -e SSH_AGENT_START=yes \
  -e SSH_AGENT_FORWARDING=yes \
  ghcr.io/billchurch/ssh_test:latest
```

#### Agent with Preloaded Keys

```bash
# Generate a test key
ssh-keygen -t ed25519 -f test_agent_key -N "" -C "test@example.com"

# Encode the private key for the container
KEY_DATA=$(base64 -i test_agent_key | tr -d '\n')

# Run container with agent and key
docker run -d --name ssh-agent-keys \
  -p 2224:22 \
  -e SSH_USER=keyuser \
  -e SSH_AUTHORIZED_KEYS="$(cat test_agent_key.pub)" \
  -e SSH_PERMIT_PASSWORD_AUTH=no \
  -e SSH_AGENT_START=yes \
  -e SSH_AGENT_KEYS="${KEY_DATA}" \
  ghcr.io/billchurch/ssh_test:latest

# Test SSH connection using the agent
ssh -p 2224 keyuser@localhost

# Cleanup
rm -f test_agent_key test_agent_key.pub
```

#### Agent Forwarding Only (No Internal Agent)

```bash
# For testing client agent forwarding
docker run -d --name ssh-forwarding-test \
  -p 2224:22 \
  -e SSH_USER=forwarduser \
  -e SSH_PASSWORD=forwardpass \
  -e SSH_AGENT_FORWARDING=yes \
  -e SSH_AGENT_START=no \
  ghcr.io/billchurch/ssh_test:latest

# Connect with agent forwarding enabled
ssh -A -p 2224 forwarduser@localhost
```

### Telnet Server (Debian Only)

```bash
# Run Debian image with telnet enabled
docker run -d --name ssh-telnet-test \
  -p 2224:22 \
  -p 2323:23 \
  -e SSH_USER=testuser \
  -e SSH_PASSWORD=testpass123 \
  -e TELNET_ENABLED=yes \
  ghcr.io/billchurch/ssh_test:debian

# Connect via telnet
telnet localhost 2323

# SSH still works alongside telnet
ssh -p 2224 testuser@localhost

# Custom telnet port
docker run -d --name ssh-telnet-custom \
  -p 2224:22 \
  -p 8023:8023 \
  -e SSH_USER=testuser \
  -e SSH_PASSWORD=testpass123 \
  -e TELNET_ENABLED=yes \
  -e TELNET_PORT=8023 \
  ghcr.io/billchurch/ssh_test:debian
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
make build-dropbear  # Dropbear-based image (SCP only, no SFTP)

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
make test-dropbear   # Test Dropbear image

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
# Latest stable release (Debian)
docker pull ghcr.io/billchurch/ssh_test:latest

# Specific version (Debian)
docker pull ghcr.io/billchurch/ssh_test:v1.0.2

# Specific version with variant
docker pull ghcr.io/billchurch/ssh_test:v1.0.2-alpine
docker pull ghcr.io/billchurch/ssh_test:v1.0.2-debian
docker pull ghcr.io/billchurch/ssh_test:v1.0.2-dropbear

# Latest variant tags
docker pull ghcr.io/billchurch/ssh_test:alpine
docker pull ghcr.io/billchurch/ssh_test:debian
docker pull ghcr.io/billchurch/ssh_test:dropbear

# Development builds
docker pull ghcr.io/billchurch/ssh_test:main
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
  ghcr.io/billchurch/ssh_test:latest

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
  ghcr.io/billchurch/ssh_test:latest
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

### Enabling Debug Mode

Enable maximum debug output:

```bash
docker run -d --name ssh-debug \
  -p 2224:22 \
  -e SSH_USER=testuser \
  -e SSH_PASSWORD=testpass \
  -e SSH_DEBUG_LEVEL=3 \
  ghcr.io/billchurch/ssh_test:latest

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

## Choosing Your Variant

### Use Dropbear When

- **Testing SCP fallback**: Your application needs to handle devices without SFTP
- **BusyBox simulation**: Mimicking embedded/IoT devices that only support SSH + SCP
- **webssh2 File Browser**: Testing the SCP fallback for [webssh2 #483](https://github.com/billchurch/webssh2/issues/483)
- **Smallest footprint**: ~5MB image with just SSH and SCP

### Use Alpine When

- **Size matters**: Ultra-minimal 13.8MB footprint
- **Resource-constrained environments**: Kubernetes pods, edge computing
- **Fast deployment**: Quicker download and startup times
- **Security**: Smaller attack surface with minimal components
- **Simple SSH testing**: Basic SSH client validation

### Use Debian When

- **Maximum compatibility**: Full GNU toolchain and libraries
- **Complex applications**: Applications requiring specific libraries
- **Legacy systems**: Compatibility with older SSH clients
- **Development**: More debugging tools and utilities available
- **Production-like testing**: Closer to typical server environments
- **Telnet testing**: Optional telnet server for terminal client testing

### Performance Comparison

| Metric | Dropbear | Alpine | Debian |
| --- | --- | --- | --- |
| **Image Size** | ~5MB | 13.8MB | 118MB |
| **Download Time** | ~1 second | ~2 seconds | ~15 seconds |
| **Memory Usage** | ~4MB | ~8MB | ~20MB |
| **Startup Time** | ~1 second | ~1 second | ~2 seconds |
| **SSH** | Yes | Yes | Yes |
| **SCP** | Yes | Yes | Yes |
| **SFTP** | **No** | Yes | Yes |
| **Telnet** | **No** | **No** | Optional |
| **Compatibility** | Limited | Good | Excellent |

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
- **Dropbear variant**: Built with [Dropbear](https://matt.ucc.asn.au/dropbear/dropbear.html) for SCP-only testing (~5MB)
- Uses [OpenSSH](https://www.openssh.com/) for robust SSH implementation (Debian/Alpine)
- Uses [Dropbear](https://matt.ucc.asn.au/dropbear/dropbear.html) for lightweight SSH (Dropbear variant)
- Optimized Docker images with smart OS detection and adaptive configuration
- Multi-architecture support with 88% size reduction possible via Alpine
- Inspired by the need for better SSH integration testing tools
