# Contributing to SSH Test Server

Thank you for considering contributing to the SSH Test Server project! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Commit Message Convention](#commit-message-convention)
- [Release Process](#release-process)
- [Testing](#testing)
- [Code Style Guidelines](#code-style-guidelines)
- [Pull Request Guidelines](#pull-request-guidelines)
- [Documentation](#documentation)
- [Security](#security)
- [Questions and Support](#questions-and-support)

## Code of Conduct

This project adheres to a professional and welcoming environment. All contributors are expected to be respectful and constructive in their interactions.

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Git
- Basic understanding of SSH, Docker, and shell scripting
- For testing: `sshpass`, `ssh-keygen`, `netcat`

### Setting Up the Development Environment

1. **Fork and Clone the Repository**
   ```bash
   git clone https://github.com/YOUR-USERNAME/ssh-test-server.git
   cd ssh-test-server
   ```

2. **Build the Development Image**
   ```bash
   make build
   # or
   docker build -f docker/Dockerfile -t ssh-test-server:dev .
   ```

3. **Run Basic Tests**
   ```bash
   make test
   # or
   ./tests/integration/run-tests.sh --image ssh-test-server:dev
   ```

## Development Workflow

### Branching Strategy

- **main**: Stable release branch
- **develop**: Development branch (optional for small projects)
- **feature/**: New features (`feature/new-auth-method`)
- **fix/**: Bug fixes (`fix/env-var-validation`)
- **docs/**: Documentation updates (`docs/update-readme`)

### Making Changes

1. **Create a Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Your Changes**
   - Follow the [Code Style Guidelines](#code-style-guidelines)
   - Add tests for new functionality
   - Update documentation as needed

3. **Test Your Changes**
   ```bash
   # Run integration tests
   make test
   
   # Test specific scenarios
   make test-connection
   make test-auth
   
   # Test with different configurations
   docker-compose --profile basic up -d
   ./scripts/test-connection.sh --host localhost --port 2222 --user testuser --password testpass123
   ```

4. **Commit Your Changes** (see [Commit Message Convention](#commit-message-convention))

5. **Push and Create Pull Request**
   ```bash
   git push origin feature/your-feature-name
   ```

## Commit Message Convention

This project uses [Conventional Commits](https://conventionalcommits.org/) to automate changelog generation and semantic versioning. All commit messages MUST follow this format:

### Format
```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | Description | Version Impact |
|------|-------------|----------------|
| `feat` | New feature | Minor (0.1.0) |
| `fix` | Bug fix | Patch (0.0.1) |
| `docs` | Documentation only | None |
| `style` | Code style changes (formatting, etc.) | None |
| `refactor` | Code refactoring without feature/bug changes | None |
| `perf` | Performance improvements | Patch |
| `test` | Adding or updating tests | None |
| `build` | Build system changes | None |
| `ci` | CI/CD changes | None |
| `chore` | Other changes (maintenance, dependencies) | None |
| `revert` | Revert previous commit | None |

### Breaking Changes
Add `!` after the type to indicate breaking changes (triggers major version bump):
```bash
feat!: change default SSH port from 22 to 2222
fix!: remove deprecated SSH_LEGACY_AUTH environment variable
```

### Examples

**Good commit messages:**
```bash
feat: add support for Ed25519 host keys
fix: resolve container startup race condition with SSH daemon
docs: update README with new authentication examples
test: add integration tests for keyboard-interactive auth
ci: add security scanning with Trivy
refactor: simplify entrypoint script environment validation
perf: optimize Docker image layer caching
```

**Bad commit messages:**
```bash
update readme          # Missing type
fixed bug              # Too vague, missing scope
feat add new feature   # Missing colon
FIX: broken tests      # Type should be lowercase
```

### Scope Examples
- `feat(auth): add multi-factor authentication support`
- `fix(docker): resolve Alpine package installation issue`
- `docs(api): update environment variable reference`
- `test(integration): add cross-platform compatibility tests`

## Release Process

This project uses [Release Please](https://github.com/googleapis/release-please) for automated releases:

### How Releases Work

1. **Commit with Conventional Messages**: When you commit using conventional commit format, Release Please analyzes the commits
2. **Automatic PR Creation**: Release Please creates a "release PR" that:
   - Updates the CHANGELOG.md
   - Bumps the version in version.txt
   - Prepares the release notes
3. **Manual Release**: A maintainer reviews and merges the release PR
4. **Automated Publishing**: The merge triggers:
   - Git tag creation
   - GitHub release creation
   - Docker image building and publishing

### Version Bumping Rules

Based on conventional commits:
- `feat:` → Minor version bump (0.1.0 → 0.2.0)
- `fix:`, `perf:` → Patch version bump (0.1.0 → 0.1.1)  
- `feat!:`, `fix!:`, etc. → Major version bump (0.1.0 → 1.0.0)
- `docs:`, `test:`, `chore:` → No version bump

### Personal Access Token Setup

**For Maintainers**: To enable release automation, you need to set up a GitHub Personal Access Token:

1. **Create PAT**: Go to GitHub Settings → Developer settings → Personal access tokens
2. **Required Scopes**: `repo`, `workflow`
3. **Add to Repository**: Go to repo Settings → Secrets and variables → Actions
4. **Add Secret**: Name it `RELEASE_PLEASE_TOKEN` with your PAT value

## Testing

### Test Categories

1. **Integration Tests**: Full container testing with various configurations
2. **Connection Tests**: Basic SSH connectivity validation
3. **Authentication Tests**: Multi-method authentication verification
4. **Security Tests**: Security hardening validation
5. **Performance Tests**: Container startup and connection performance

### Running Tests

```bash
# Full test suite
make test
./tests/integration/run-tests.sh --image ssh-test-server:dev

# Parallel testing (faster)
make test-parallel

# Specific test categories
make test-connection    # Basic connectivity
make test-auth         # Authentication methods
make test-security     # Security configurations

# Manual testing with Docker Compose
docker-compose --profile basic up -d
docker-compose --profile hardened up -d
```

### Writing Tests

When adding new features:

1. **Add Integration Tests**: Update `tests/integration/run-tests.sh`
2. **Test Edge Cases**: Include failure scenarios
3. **Document Test Scenarios**: Update test documentation
4. **Validate Across Platforms**: Ensure AMD64 and ARM64 compatibility

## Code Style Guidelines

### Shell Scripts

- Use `#!/bin/sh` for maximum compatibility
- Follow POSIX shell standards
- Use `shellcheck` for linting:
  ```bash
  find . -name "*.sh" -type f -exec shellcheck {} \;
  ```
- Use meaningful variable names with UPPER_CASE for environment variables
- Add error checking: `set -e` for scripts that should fail fast

### Docker

- Use multi-stage builds when appropriate
- Minimize image layers
- Use specific base image versions (not `latest`)
- Follow Docker best practices for security
- Add labels for metadata

### Documentation

- Use clear, concise language
- Include code examples
- Update README when adding features
- Document environment variables completely

## Pull Request Guidelines

### Before Submitting

- [ ] Branch name follows convention (`feat/`, `fix/`, `docs/`)
- [ ] Commits follow conventional commit format
- [ ] All tests pass locally
- [ ] Documentation updated if needed
- [ ] CHANGELOG.md updated for significant changes (optional, as Release Please will handle this)

### PR Title and Description

- **Title**: Use conventional commit format
- **Description**: Include:
  - What changes were made and why
  - How to test the changes
  - Any breaking changes or migration notes
  - Link to related issues

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that causes existing functionality to change)
- [ ] Documentation update

## Testing
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] New tests added for new functionality

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Conventional commit format used
```

### Review Process

1. **Automated Checks**: CI tests must pass
2. **Code Review**: At least one maintainer review required
3. **Testing**: Reviewers may request additional testing
4. **Approval**: Maintainer approval required for merge

## Documentation

### Areas Requiring Documentation

- New environment variables
- Configuration changes
- API/interface changes
- Deployment procedures
- Troubleshooting guides

### Documentation Standards

- **README.md**: High-level overview and quick start
- **CONTRIBUTING.md**: This file - development guidelines
- **Docker comments**: Document Dockerfile steps
- **Script comments**: Explain complex shell script logic
- **Environment variables**: Document in README and code

## Security

### Reporting Security Issues

**DO NOT** open GitHub issues for security vulnerabilities. Instead:

1. Email the maintainer directly (if provided)
2. Use GitHub's private vulnerability reporting
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fixes (if any)

### Security Guidelines for Contributors

- Never commit secrets, tokens, or passwords
- Use minimal privileges in container configurations
- Validate all user inputs (environment variables)
- Follow security best practices for SSH configurations
- Regularly update base images and dependencies

### Security Testing

- Run security scans: `make security-scan`
- Test with hardened configurations
- Validate input sanitization
- Check for privilege escalation issues

## Questions and Support

### Getting Help

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and community support
- **Documentation**: Check README.md and inline code comments

### Issue Templates

When creating issues, use the provided templates:

- **Bug Report**: For reporting bugs
- **Feature Request**: For requesting new features
- **Documentation**: For documentation improvements
- **Question**: For general questions

### Response Times

This is a community-maintained project. Response times may vary:

- **Critical bugs**: Best effort within 48 hours
- **Features**: Review within 1 week
- **Documentation**: Review within 1 week
- **Questions**: Community support as available

## Thank You!

Your contributions make this project better for everyone. Whether it's code, documentation, testing, or community support - all contributions are valued and appreciated!