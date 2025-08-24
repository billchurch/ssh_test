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

# Build targets
build: build-debian ## Build the default (Debian) Docker image

build-all: build-debian build-alpine ## Build both Debian and Alpine images

build-debian: ## Build Debian-based image
	docker build -f docker/Dockerfile -t $(IMAGE_NAME):debian -t $(IMAGE_NAME):latest .
	@echo "✅ Built Debian image: $(IMAGE_NAME):debian (also tagged as latest)"

build-alpine: ## Build Alpine-based image
	docker build -f docker/Dockerfile.alpine -t $(IMAGE_NAME):alpine .
	@echo "✅ Built Alpine image: $(IMAGE_NAME):alpine"

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

stop: ## Stop all running containers
	docker stop $(CONTAINER_NAME)-debian $(CONTAINER_NAME)-alpine || true
	docker stop $(CONTAINER_NAME) $(CONTAINER_NAME)-debug || true

clean: ## Remove containers and images
	docker rm -f $(CONTAINER_NAME)-debian $(CONTAINER_NAME)-alpine || true
	docker rm -f $(CONTAINER_NAME) $(CONTAINER_NAME)-debug || true
	docker rmi $(IMAGE_NAME):debian $(IMAGE_NAME):alpine $(IMAGE_NAME):latest || true
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) || true

logs: logs-debian ## Show default (Debian) container logs

logs-debian: ## Show Debian container logs
	docker logs -f $(CONTAINER_NAME)-debian

logs-alpine: ## Show Alpine container logs  
	docker logs -f $(CONTAINER_NAME)-alpine

shell: shell-debian ## Get a shell in the default (Debian) container

shell-debian: ## Get a shell in the Debian container
	docker exec -it $(CONTAINER_NAME)-debian /bin/bash

shell-alpine: ## Get a shell in the Alpine container
	docker exec -it $(CONTAINER_NAME)-alpine /bin/sh

# Testing targets
test: test-debian ## Run integration tests on default (Debian) image

test-all: test-debian test-alpine ## Run integration tests on both images

test-debian: ## Run integration tests on Debian image
	./tests/integration/run-tests.sh --image $(IMAGE_NAME):debian

test-alpine: ## Run integration tests on Alpine image
	./tests/integration/run-tests.sh --image $(IMAGE_NAME):alpine

test-parallel: ## Run tests in parallel
	./tests/integration/run-tests.sh --image $(IMAGE_NAME):$(IMAGE_TAG) --parallel

test-verbose: ## Run tests with verbose output
	./tests/integration/run-tests.sh --image $(IMAGE_NAME):$(IMAGE_TAG) --verbose

test-connection-debian: ## Test SSH connection to Debian container
	./scripts/test-connection.sh --host localhost --port $(SSH_PORT) --user $(SSH_USER) --password $(SSH_PASSWORD)

test-connection-alpine: ## Test SSH connection to Alpine container  
	./scripts/test-connection.sh --host localhost --port 2225 --user $(SSH_USER) --password $(SSH_PASSWORD)

test-auth-debian: ## Test authentication methods on Debian container
	./scripts/test-auth-methods.sh --container $(CONTAINER_NAME)-debian --user $(SSH_USER) --generate-keys

test-auth-alpine: ## Test authentication methods on Alpine container
	./scripts/test-auth-methods.sh --container $(CONTAINER_NAME)-alpine --user $(SSH_USER) --generate-keys

integration-test: build-all test-all ## Build both images and run integration tests

# Development targets
dev-setup: ## Set up development environment
	chmod +x scripts/*.sh
	chmod +x tests/integration/*.sh
	chmod +x docker/entrypoint.sh

lint: ## Lint shell scripts and Dockerfiles
	@echo "Linting shell scripts..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		find . -name "*.sh" -type f -exec shellcheck {} \; ; \
	else \
		echo "shellcheck not found, skipping shell script linting"; \
	fi
	@echo "Linting Dockerfiles..."
	@if command -v hadolint >/dev/null 2>&1; then \
		hadolint docker/Dockerfile docker/Dockerfile.alpine; \
	else \
		echo "hadolint not found, skipping Dockerfile linting"; \
	fi

security-scan: security-scan-debian ## Run security scan on default (Debian) image

security-scan-all: security-scan-debian security-scan-alpine ## Run security scan on both images

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