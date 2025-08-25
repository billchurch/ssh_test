# Changelog

All notable changes to the SSH Test Server project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1](https://github.com/billchurch/ssh_test/compare/v1.1.0...v1.1.1) (2025-08-25)


### Bug Fixes

* **ci:** remove duplicate suffix in Alpine variant tags ([4f97a42](https://github.com/billchurch/ssh_test/commit/4f97a423b7bef530eb790630af7af2017b45d4e1))

## [1.1.0](https://github.com/billchurch/ssh_test/compare/v1.0.2...v1.1.0) (2025-08-25)


### Features

* add Alpine variant CI builds and update docs ([de1dee2](https://github.com/billchurch/ssh_test/commit/de1dee2a854ab2a17692b81728e49f0897905df9))

## [1.0.2](https://github.com/billchurch/ssh_test/compare/v1.0.1...v1.0.2) (2025-08-25)


### Bug Fixes

* container build ([3c60d4e](https://github.com/billchurch/ssh_test/commit/3c60d4ed61fd9d4f7a1c1e0fd0b77bd66b7c8f43))
* improve cross-platform CI testing reliability ([e3a008b](https://github.com/billchurch/ssh_test/commit/e3a008b3676167e489f7a2802a4e03d89db06ed4))
* improve SSH readiness check in CI workflow ([9023c6a](https://github.com/billchurch/ssh_test/commit/9023c6a7efd4bcc2dc4a89e84a4546c1cf08b42c))
* removed secret conditional ([fcea00e](https://github.com/billchurch/ssh_test/commit/fcea00ed282b1ee0f8053f5a75666a755268eb81))

## [1.0.1](https://github.com/billchurch/ssh_test/compare/v1.0.0...v1.0.1) (2025-08-24)


### Bug Fixes

* simplify CI image references and suppress Hadolint warnings ([a5053b9](https://github.com/billchurch/ssh_test/commit/a5053b994cd2173792ed60419c08332da4e86ce6))

## 1.0.0 (2025-08-24)


### Features

* implement automated release workflow and project enhancement ([9c5af9d](https://github.com/billchurch/ssh_test/commit/9c5af9db30d257ae6c844838e8719b7b69ba8ccf))


### Bug Fixes

* corrected repo for integration test ([1626181](https://github.com/billchurch/ssh_test/commit/1626181f12c3dc89a95f2f843b1461a0db55890e))
* resolve Hadolint warnings for package version pinning ([a8719f4](https://github.com/billchurch/ssh_test/commit/a8719f4d7e816d1b36dc06f6d42637746d93672e))
* resolve SSH public key authentication failures ([e6ba24c](https://github.com/billchurch/ssh_test/commit/e6ba24c70cad640dc46710821bc82dc28a97b100))
* update GHCR authentication to use PAT ([873a7eb](https://github.com/billchurch/ssh_test/commit/873a7eb8b2e575a8b69cf2df376aef01024c1561))
* update integration tests ([38a9ce2](https://github.com/billchurch/ssh_test/commit/38a9ce2b4ba8d94f403e57517d1d0d2c686417b2))

## [Unreleased]

### Added
- Initial release of SSH Test Server
- Comprehensive environment variable configuration system
- Multi-architecture Docker image support (AMD64, ARM64)
- Multiple authentication methods (password, public key, keyboard-interactive)
- Flexible security configuration options
- Debug mode with adjustable verbosity levels
- Automated CI/CD pipeline with GitHub Actions
- Integration test suite with comprehensive coverage
- Testing scripts for connection and authentication validation
- Docker Compose examples for common use cases
- Security hardening options
- Custom SSH port configuration
- Host key management (auto-generation or custom keys)
- Environment variable validation with sensible defaults
- Health check support
- SBOM generation and vulnerability scanning
- Multi-stage Docker build optimization

### Features
- **Authentication Methods**: Password, public key, and keyboard-interactive authentication
- **Security Controls**: Root login restrictions, empty password controls, authentication attempt limits
- **Forwarding Options**: Configurable X11, SSH agent, and TCP forwarding
- **Debug Support**: Four levels of SSH debug output (0-3)
- **Container Optimization**: Alpine Linux base image for minimal footprint
- **Testing Tools**: Comprehensive test scripts and integration test suite
- **Documentation**: Extensive README with examples and troubleshooting guides

### Security
- Non-root container execution where possible
- Configurable authentication restrictions
- No hardcoded default passwords
- Minimal attack surface with Alpine Linux
- Regular security scanning with Trivy
- SBOM generation for supply chain transparency

## [1.0.0] - 2025-01-XX (Planned)

### Added
- Initial stable release
- Full documentation and examples
- Comprehensive test coverage
- Multi-architecture container images
- GitHub Container Registry publishing
- Community contribution guidelines

## Development Milestones

### Phase 1: Core Implementation ✅
- [x] Basic Dockerfile with SSH server setup
- [x] Environment variable configuration system
- [x] Entrypoint script with runtime configuration
- [x] User creation and authentication setup
- [x] Host key generation and management

### Phase 2: Advanced Features ✅
- [x] Multi-authentication method support
- [x] Security hardening options
- [x] Debug mode implementation
- [x] Custom SSH port configuration
- [x] Environment variable validation

### Phase 3: Testing Infrastructure ✅
- [x] Integration test suite
- [x] Connection testing scripts
- [x] Authentication method testing tools
- [x] Docker Compose examples
- [x] CI/CD pipeline setup

### Phase 4: Documentation & Publishing ✅
- [x] Comprehensive README documentation
- [x] Usage examples and tutorials
- [x] API/configuration reference
- [x] Troubleshooting guides
- [x] Contributing guidelines

### Phase 5: CI/CD & Distribution ✅
- [x] GitHub Actions workflows
- [x] Multi-architecture builds
- [x] Container registry publishing
- [x] Automated testing pipeline
- [x] Security scanning integration
- [x] SBOM generation

## Configuration Changes

### Environment Variables Added
- `SSH_USER`: SSH username to create
- `SSH_PASSWORD`: Password for SSH authentication
- `SSH_AUTHORIZED_KEYS`: SSH public keys for key-based authentication
- `SSH_HOST_KEYS`: Custom SSH host keys
- `SSH_PERMIT_PASSWORD_AUTH`: Enable/disable password authentication
- `SSH_PERMIT_PUBKEY_AUTH`: Enable/disable public key authentication
- `SSH_CHALLENGE_RESPONSE_AUTH`: Enable/disable keyboard-interactive authentication
- `SSH_PERMIT_ROOT_LOGIN`: Control root login access
- `SSH_PERMIT_EMPTY_PASSWORDS`: Allow empty passwords
- `SSH_PORT`: Custom SSH server port
- `SSH_DEBUG_LEVEL`: SSH debug verbosity level
- `SSH_AUTH_METHODS`: Specify required authentication methods
- `SSH_MAX_AUTH_TRIES`: Maximum authentication attempts
- `SSH_LOGIN_GRACE_TIME`: Login timeout in seconds
- `SSH_USE_PAM`: Enable PAM authentication
- `SSH_USE_DNS`: Enable DNS lookups
- `SSH_X11_FORWARDING`: Enable X11 forwarding
- `SSH_AGENT_FORWARDING`: Enable SSH agent forwarding
- `SSH_TCP_FORWARDING`: Enable TCP forwarding
- `SSH_CUSTOM_CONFIG`: Additional SSH configuration directives

## Breaking Changes

None yet - this is the initial release.

## Known Issues

- Keyboard-interactive authentication requires careful PAM configuration
- Some SSH client compatibility edge cases may exist with very old clients

## Upgrade Notes

This is the initial release, so no upgrade procedures are needed yet.

## Support

For support, bug reports, and feature requests:
- GitHub Issues: https://github.com/billchurch/ssh-test-server/issues
- GitHub Discussions: https://github.com/billchurch/ssh-test-server/discussions
- Documentation: README.md and inline code comments
