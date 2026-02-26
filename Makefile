# SSH Test Server - Makefile
# Common development and testing tasks

.PHONY: help build test clean run stop logs shell lint security-scan push-local integration-test

# Default target
help: ## Show this help message
	@echo "SSH Test Server - Available Commands:"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo

# Variables
IMAGE_NAME ?= ssh-test-server
IMAGE_TAG ?= dev
CONTAINER_NAME ?= ssh-test-dev
SSH_PORT ?= 2224
SSH_USER ?= testuser
SSH_PASSWORD ?= testpass123
TELNET_PORT ?= 2323

# Build targets
build: build-debian ## Build the default (Debian) Docker image

build-all: build-debian build-alpine build-dropbear ## Build all image variants

build-debian: ## Build Debian-based image
	docker build -f docker/Dockerfile -t $(IMAGE_NAME):debian -t $(IMAGE_NAME):latest .
	@echo "✅ Built Debian image: $(IMAGE_NAME):debian (also tagged as latest)"

build-alpine: ## Build Alpine-based image
	docker build -f docker/Dockerfile.alpine -t $(IMAGE_NAME):alpine .
	@echo "✅ Built Alpine image: $(IMAGE_NAME):alpine"

build-dropbear: ## Build Dropbear-based image (SCP only, no SFTP)
	docker build -f docker/Dockerfile.dropbear -t $(IMAGE_NAME):dropbear .
	@echo "✅ Built Dropbear image: $(IMAGE_NAME):dropbear"

build-dev: ## Build development version (Debian)
	docker build -f docker/Dockerfile -t $(IMAGE_NAME):$(IMAGE_TAG) .

build-multi: ## Build multi-architecture image (requires buildx)
	docker buildx build --platform linux/amd64,linux/arm64 \
		-f docker/Dockerfile -t $(IMAGE_NAME):$(IMAGE_TAG) .

# Runtime targets
run: run-debian ## Run the default (Debian) SSH test server container

run-debian: ## Run Debian-based SSH test server
	docker run -d --name $(CONTAINER_NAME)-debian \
		-p $(SSH_PORT):22 \
		-e SSH_USER=$(SSH_USER) \
		-e SSH_PASSWORD=$(SSH_PASSWORD) \
		-e SSH_DEBUG_LEVEL=1 \
		$(IMAGE_NAME):debian

run-alpine: ## Run Alpine-based SSH test server
	docker run -d --name $(CONTAINER_NAME)-alpine \
		-p 2225:22 \
		-e SSH_USER=$(SSH_USER) \
		-e SSH_PASSWORD=$(SSH_PASSWORD) \
		-e SSH_DEBUG_LEVEL=1 \
		$(IMAGE_NAME):alpine

run-dropbear: ## Run Dropbear-based SSH test server (SCP only, no SFTP)
	docker run -d --name $(CONTAINER_NAME)-dropbear \
		-p 2226:22 \
		-e SSH_USER=$(SSH_USER) \
		-e SSH_PASSWORD=$(SSH_PASSWORD) \
		-e SSH_DEBUG_LEVEL=1 \
		$(IMAGE_NAME):dropbear

run-dev: ## Run development version
	docker run -d --name $(CONTAINER_NAME) \
		-p $(SSH_PORT):22 \
		-e SSH_USER=$(SSH_USER) \
		-e SSH_PASSWORD=$(SSH_PASSWORD) \
		-e SSH_DEBUG_LEVEL=1 \
		$(IMAGE_NAME):$(IMAGE_TAG)

run-debug: ## Run container with debug mode enabled
	docker run -d --name $(CONTAINER_NAME)-debug \
		-p $(SSH_PORT):22 \
		-e SSH_USER=$(SSH_USER) \
		-e SSH_PASSWORD=$(SSH_PASSWORD) \
		-e SSH_DEBUG_LEVEL=3 \
		$(IMAGE_NAME):$(IMAGE_TAG)

run-telnet: ## Run Debian container with telnet enabled
	docker run -d --name $(CONTAINER_NAME)-telnet \
		-p $(SSH_PORT):22 \
		-p $(TELNET_PORT):23 \
		-e SSH_USER=$(SSH_USER) \
		-e SSH_PASSWORD=$(SSH_PASSWORD) \
		-e TELNET_ENABLED=yes \
		-e SSH_DEBUG_LEVEL=1 \
		$(IMAGE_NAME):debian

stop: ## Stop all running containers
	docker stop $(CONTAINER_NAME)-debian $(CONTAINER_NAME)-alpine $(CONTAINER_NAME)-dropbear $(CONTAINER_NAME)-telnet || true
	docker stop $(CONTAINER_NAME) $(CONTAINER_NAME)-debug || true

clean: ## Remove containers and images
	docker rm -f $(CONTAINER_NAME)-debian $(CONTAINER_NAME)-alpine $(CONTAINER_NAME)-dropbear $(CONTAINER_NAME)-telnet || true
	docker rm -f $(CONTAINER_NAME) $(CONTAINER_NAME)-debug || true
	docker rmi $(IMAGE_NAME):debian $(IMAGE_NAME):alpine $(IMAGE_NAME):dropbear $(IMAGE_NAME):latest || true
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) || true

logs: logs-debian ## Show default (Debian) container logs

logs-debian: ## Show Debian container logs
	docker logs -f $(CONTAINER_NAME)-debian

logs-alpine: ## Show Alpine container logs
	docker logs -f $(CONTAINER_NAME)-alpine

logs-dropbear: ## Show Dropbear container logs
	docker logs -f $(CONTAINER_NAME)-dropbear

shell: shell-debian ## Get a shell in the default (Debian) container

shell-debian: ## Get a shell in the Debian container
	docker exec -it $(CONTAINER_NAME)-debian /bin/bash

shell-alpine: ## Get a shell in the Alpine container
	docker exec -it $(CONTAINER_NAME)-alpine /bin/sh

shell-dropbear: ## Get a shell in the Dropbear container
	docker exec -it $(CONTAINER_NAME)-dropbear /bin/bash

# Testing targets
test: test-debian ## Run integration tests on default (Debian) image

test-all: test-debian test-alpine test-dropbear ## Run integration tests on all images

test-debian: ## Run integration tests on Debian image
	./tests/integration/run-tests.sh --image $(IMAGE_NAME):debian

test-alpine: ## Run integration tests on Alpine image
	./tests/integration/run-tests.sh --image $(IMAGE_NAME):alpine

test-dropbear: ## Run integration tests on Dropbear image
	./tests/integration/run-tests.sh --image $(IMAGE_NAME):dropbear

test-parallel: ## Run tests in parallel
	./tests/integration/run-tests.sh --image $(IMAGE_NAME):$(IMAGE_TAG) --parallel

test-verbose: ## Run tests with verbose output
	./tests/integration/run-tests.sh --image $(IMAGE_NAME):$(IMAGE_TAG) --verbose

test-connection-debian: ## Test SSH connection to Debian container
	./scripts/test-connection.sh --host localhost --port $(SSH_PORT) --user $(SSH_USER) --password $(SSH_PASSWORD)

test-connection-alpine: ## Test SSH connection to Alpine container
	./scripts/test-connection.sh --host localhost --port 2225 --user $(SSH_USER) --password $(SSH_PASSWORD)

test-connection-dropbear: ## Test SSH connection to Dropbear container
	./scripts/test-connection.sh --host localhost --port 2226 --user $(SSH_USER) --password $(SSH_PASSWORD)

test-auth-debian: ## Test authentication methods on Debian container
	./scripts/test-auth-methods.sh --container $(CONTAINER_NAME)-debian --user $(SSH_USER) --generate-keys

test-auth-alpine: ## Test authentication methods on Alpine container
	./scripts/test-auth-methods.sh --container $(CONTAINER_NAME)-alpine --user $(SSH_USER) --generate-keys

test-auth-dropbear: ## Test authentication methods on Dropbear container
	./scripts/test-auth-methods.sh --container $(CONTAINER_NAME)-dropbear --user $(SSH_USER) --generate-keys

test-telnet: ## Quick telnet connection test
	@echo "Testing telnet connectivity on port $(TELNET_PORT)..."
	@echo "" | nc -w 3 localhost $(TELNET_PORT) && echo "✅ Telnet server is accessible" || echo "❌ Telnet server is not accessible"

test-agent: test-agent-debian ## Run SSH agent tests on default (Debian) image

test-agent-all: test-agent-debian test-agent-alpine ## Run SSH agent tests on both images

test-agent-debian: ## Run SSH agent tests on Debian image
	./tests/integration/test-ssh-agent.sh --image $(IMAGE_NAME):debian

test-agent-alpine: ## Run SSH agent tests on Alpine image
	./tests/integration/test-ssh-agent.sh --image $(IMAGE_NAME):alpine

test-agent-verbose: ## Run SSH agent tests with verbose output
	./tests/integration/test-ssh-agent.sh --image $(IMAGE_NAME):$(IMAGE_TAG) --verbose

integration-test: build-all test-all ## Build all images and run integration tests

# Development targets
dev-setup: ## Set up development environment
	chmod +x scripts/*.sh
	chmod +x tests/integration/*.sh
	chmod +x docker/entrypoint.sh
	chmod +x docker/entrypoint-dropbear.sh

lint: ## Lint shell scripts and Dockerfiles
	@echo "Linting shell scripts..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		find . -name "*.sh" -type f -exec shellcheck {} \; ; \
	else \
		echo "shellcheck not found, skipping shell script linting"; \
	fi
	@echo "Linting Dockerfiles..."
	@if command -v hadolint >/dev/null 2>&1; then \
		hadolint docker/Dockerfile docker/Dockerfile.alpine docker/Dockerfile.dropbear; \
	else \
		echo "hadolint not found, skipping Dockerfile linting"; \
	fi

security-scan: security-scan-debian ## Run security scan on default (Debian) image

security-scan-all: security-scan-debian security-scan-alpine security-scan-dropbear ## Run security scan on all images

security-scan-debian: ## Run security scan on Debian image
	@if command -v trivy >/dev/null 2>&1; then \
		trivy image $(IMAGE_NAME):debian; \
	else \
		echo "trivy not found, skipping security scan"; \
	fi

security-scan-alpine: ## Run security scan on Alpine image
	@if command -v trivy >/dev/null 2>&1; then \
		trivy image $(IMAGE_NAME):alpine; \
	else \
		echo "trivy not found, skipping security scan"; \
	fi

security-scan-dropbear: ## Run security scan on Dropbear image
	@if command -v trivy >/dev/null 2>&1; then \
		trivy image $(IMAGE_NAME):dropbear; \
	else \
		echo "trivy not found, skipping security scan"; \
	fi

compare-sizes: ## Compare image sizes
	@echo "Image Size Comparison:"
	@echo "======================"
	@docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep $(IMAGE_NAME) | head -10

# Docker Compose targets
compose-up: ## Start services using Docker Compose
	docker-compose --profile basic up -d

compose-down: ## Stop Docker Compose services
	docker-compose down

compose-logs: ## Show Docker Compose logs
	docker-compose logs -f

compose-agent: ## Start SSH agent services using Docker Compose
	docker-compose --profile ssh-agent up -d

compose-agent-basic: ## Start basic SSH agent service
	docker-compose --profile agent up -d

compose-agent-keys: ## Start SSH agent service with preloaded keys
	docker-compose --profile agent-keys up -d

compose-telnet: ## Start telnet service via Docker Compose
	docker-compose --profile telnet up -d

# CI/CD simulation
ci-build: ## Simulate CI build process
	docker build -f docker/Dockerfile -t $(IMAGE_NAME):test .

ci-test: ci-build ## Simulate CI test process
	./tests/integration/run-tests.sh --image $(IMAGE_NAME):test --report ci-test-results.txt

ci-full: lint ci-build ci-test security-scan ## Run full CI pipeline locally

# Utility targets
ssh-test: ## Quick SSH connection test
	ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p $(SSH_PORT) $(SSH_USER)@localhost

generate-keys: ## Generate test SSH keys
	ssh-keygen -t ed25519 -f test_key -N "" -C "test@ssh-test-server"
	@echo "Generated test keys: test_key (private) and test_key.pub (public)"

clean-keys: ## Remove generated test keys
	rm -f test_key test_key.pub

status: ## Show container status
	@echo "Container status:"
	@docker ps -a --filter name=$(CONTAINER_NAME) --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

health: ## Check container health
	@if docker ps --filter name=$(CONTAINER_NAME) --filter status=running -q | grep -q .; then \
		echo "Testing SSH connectivity..."; \
		if nc -z localhost $(SSH_PORT); then \
			echo "✅ SSH server is accessible on port $(SSH_PORT)"; \
		else \
			echo "❌ SSH server is not accessible on port $(SSH_PORT)"; \
		fi; \
	else \
		echo "❌ Container $(CONTAINER_NAME) is not running"; \
	fi

# Documentation targets
docs: ## Generate or update documentation
	@echo "Documentation is in README.md"
	@echo "Examples are in examples/ directory"
	@echo "Run 'make help' to see available commands"

# Development workflow
dev: clean build run ## Clean, build, and run for development
	@echo "Development container started:"
	@echo "  SSH: ssh -p $(SSH_PORT) $(SSH_USER)@localhost"
	@echo "  Password: $(SSH_PASSWORD)"
	@echo "  Logs: make logs"
	@echo "  Stop: make stop"