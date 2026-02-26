# Telnet Server Implementation Plan

<!-- markdownlint-disable MD001 MD013 MD024 -->

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task.

<!-- markdownlint-enable MD013 -->

**Goal:** Add an optional busybox telnetd to the Debian image,
enabled via `TELNET_ENABLED=yes`, for webssh2 terminal client
testing.

**Architecture:** The telnet daemon runs as a second background
process alongside sshd, managed by the existing entrypoint script.
It uses busybox telnetd with `/bin/login` for authentication,
reusing the system user created by `create_ssh_user()`. Disabled
by default; zero behavioral change for existing users.

**Tech Stack:** busybox telnetd, bash, Docker, Make

---

## Task 1: Add busybox package to Dockerfile

**Files:**

- Modify: `docker/Dockerfile:23-39` (apt-get install block)

#### Step 1: Add busybox to the install list

In `docker/Dockerfile`, add `busybox` after the `socat` line
(line 30):

```dockerfile
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openssh-server \
        openssh-client \
        bash \
        mc \
        ncurses-bin \
        socat \
        busybox \
        libpam-google-authenticator \
        && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
              /usr/share/doc/* \
              /usr/share/man/* \
              /usr/share/locale/* \
              /tmp/* \
              /var/tmp/* \
    && mkdir -p /var/run/sshd /etc/ssh/ssh_host_keys
```

#### Step 2: Verify the edit

Run: `grep -n busybox docker/Dockerfile`
Expected: Shows busybox on a line in the apt-get install block.

#### Step 3: Commit

```bash
git add docker/Dockerfile
git commit -m "feat: add busybox package for telnetd support"
```

---

## Task 2: Add telnet ENV vars and EXPOSE to Dockerfile

**Files:**

- Modify: `docker/Dockerfile:46-75` (ENV block and EXPOSE)

#### Step 1: Add TELNET env vars to the ENV block

After the `SSH_KI_STATIC_OTP=""` line (line 72), add the telnet
variables:

```dockerfile
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
    SSH_AGENT_START=no \
    SSH_AGENT_KEYS="" \
    SSH_AGENT_SOCKET_PATH="/tmp/ssh-agent.sock" \
    SSH_CUSTOM_CONFIG="" \
    SSH_KI_STATIC_OTP="" \
    TELNET_ENABLED=no \
    TELNET_PORT=23
```

#### Step 2: Add EXPOSE 23

After the existing `EXPOSE 22` line (line 75), add:

```dockerfile
# Expose SSH port (default 22, configurable via SSH_PORT)
EXPOSE 22

# Expose telnet port (default 23, configurable via TELNET_PORT)
EXPOSE 23
```

#### Step 3: Verify

Run: `grep -n -E 'TELNET|EXPOSE' docker/Dockerfile`
Expected: Shows TELNET_ENABLED, TELNET_PORT in ENV block and
both EXPOSE lines.

#### Step 4: Commit

```bash
git add docker/Dockerfile
git commit -m "feat: add TELNET env vars and EXPOSE to Dockerfile"
```

---

## Task 3: Add TELNET_PORT validation to entrypoint

**Files:**

- Modify: `docker/entrypoint.sh:46-88` (validate_env function)

#### Step 1: Add TELNET_PORT validation

After the `SSH_LOGIN_GRACE_TIME` validation block (line 71) and
before the `SSH_USER` validation (line 73), add:

```bash
    # Validate TELNET_PORT (only if telnet is enabled)
    if [[ "${TELNET_ENABLED}" == "yes" ]]; then
        if [[ ! "${TELNET_PORT}" =~ ^[0-9]+$ ]] \
            || [[ "${TELNET_PORT}" -lt 1 ]] \
            || [[ "${TELNET_PORT}" -gt 65535 ]]; then
            log_warn "Invalid TELNET_PORT '${TELNET_PORT}', using default 23"
            export TELNET_PORT=23
        fi
    fi
```

#### Step 2: Verify

Run: `grep -n TELNET docker/entrypoint.sh`
Expected: Shows the TELNET_PORT validation lines in
validate_env.

#### Step 3: Commit

```bash
git add docker/entrypoint.sh
git commit -m "feat: add TELNET_PORT validation to entrypoint"
```

---

## Task 4: Add start_telnet() function to entrypoint

**Files:**

- Modify: `docker/entrypoint.sh` (add function + call in main)

#### Step 1: Add the start_telnet function

Insert before the `print_startup_info()` function (before
line 497):

```bash
# Start telnet server if enabled
start_telnet() {
    if [[ "${TELNET_ENABLED}" != "yes" ]]; then
        log_debug "Telnet server disabled"
        return 0
    fi

    log_info "Starting telnet server on port ${TELNET_PORT}..."

    # Verify busybox telnetd is available
    if ! command -v busybox >/dev/null 2>&1; then
        log_error "busybox not found - telnet requires busybox"
        return 1
    fi

    # -F: foreground (we background it ourselves)
    # -p: port to listen on
    # -l: login program to spawn
    busybox telnetd -F -p "${TELNET_PORT}" -l /bin/login &
    TELNETD_PID=$!
    log_info "Telnet server started (PID ${TELNETD_PID})"
}
```

#### Step 2: Call start_telnet from main()

In `main()`, after `configure_sshd` (line 564) and before
`print_startup_info` (line 567), add:

```bash
    # Start telnet server if enabled
    start_telnet
```

#### Step 3: Verify

Run: `grep -n -A2 'start_telnet\|telnet' docker/entrypoint.sh`
Expected: Shows the function definition and the call in main().

#### Step 4: Commit

```bash
git add docker/entrypoint.sh
git commit -m "feat: add start_telnet() function to entrypoint"
```

---

## Task 5: Update print_startup_info() for telnet

**Files:**

- Modify: `docker/entrypoint.sh` (print_startup_info function)

#### Step 1: Add telnet status to startup info

After the SSH Agent block (before the `==` separator line),
add:

```bash
    if [[ "${TELNET_ENABLED}" == "yes" ]]; then
        log_info "Telnet: Enabled (port ${TELNET_PORT})"
    else
        log_info "Telnet: Disabled"
    fi
```

#### Step 2: Verify

Run: `grep -n -B1 -A3 'Telnet' docker/entrypoint.sh`
Expected: Shows the telnet status block in print_startup_info.

#### Step 3: Commit

```bash
git add docker/entrypoint.sh
git commit -m "feat: show telnet status in startup info"
```

---

## Task 6: Update cleanup() to stop telnetd

**Files:**

- Modify: `docker/entrypoint.sh` (cleanup function + main wait)

#### Step 1: Add telnetd cleanup

After the SSH agent cleanup block and before `exit 0`, add:

```bash
    # Stop telnet server if it's running
    if [[ -n "${TELNETD_PID}" ]] \
        && kill -0 "${TELNETD_PID}" >/dev/null 2>&1; then
        log_debug "Stopping telnet server (PID ${TELNETD_PID})..."
        kill -TERM "${TELNETD_PID}" >/dev/null 2>&1 || true
        log_info "Telnet server stopped"
    fi
```

#### Step 2: Update the wait in main()

The current `main()` ends with `wait "${SSHD_PID}"`. Since we
now have two background processes, change the end of main() to
wait for both. Replace:

```bash
    # Attach to sshd process and wait
    wait "${SSHD_PID}"
```

With:

```bash
    # Wait for background processes
    if [[ -n "${TELNETD_PID}" ]]; then
        wait -n "${SSHD_PID}" "${TELNETD_PID}"
    else
        wait "${SSHD_PID}"
    fi
```

#### Step 3: Verify

Run: `grep -n -B1 -A4 'TELNETD_PID' docker/entrypoint.sh`
Expected: Shows TELNETD_PID in start_telnet, cleanup, and
main wait.

#### Step 4: Commit

```bash
git add docker/entrypoint.sh
git commit -m "feat: add telnetd cleanup and multi-process wait"
```

---

## Task 7: Add docker-compose telnet service

**Files:**

- Modify: `examples/docker-compose.yml` (add service)

#### Step 1: Add telnet service

Before the `volumes:` block (line 321), add:

```yaml
  # Telnet server for terminal client testing (webssh2)
  ssh-telnet:
    image: ghcr.io/billchurch/ssh_test:debian
    container_name: ssh-test-telnet
    ports:
      - "2237:22"
      - "2323:23"
    environment:
      - SSH_USER=testuser
      - SSH_PASSWORD=testpass123
      - SSH_PERMIT_PASSWORD_AUTH=yes
      - TELNET_ENABLED=yes
      - TELNET_PORT=23
      - SSH_DEBUG_LEVEL=1
    restart: unless-stopped
    profiles:
      - telnet
      - all
```

#### Step 2: Verify

Run: `grep -n -A15 'ssh-telnet' examples/docker-compose.yml`
Expected: Shows the telnet service definition.

#### Step 3: Commit

```bash
git add examples/docker-compose.yml
git commit -m "feat: add telnet service to docker-compose"
```

---

## Task 8: Add Makefile telnet targets

**Files:**

- Modify: `Makefile`

#### Step 1: Add TELNET_PORT variable

After the `SSH_PASSWORD` variable (line 19), add:

```makefile
TELNET_PORT ?= 2323
```

#### Step 2: Add run-telnet target

After the `run-debug` target (after line 86), add:

<!-- markdownlint-disable MD013 -->

```makefile
run-telnet: ## Run Debian container with telnet enabled
 docker run -d --name $(CONTAINER_NAME)-telnet \
  -p $(SSH_PORT):22 \
  -p $(TELNET_PORT):23 \
  -e SSH_USER=$(SSH_USER) \
  -e SSH_PASSWORD=$(SSH_PASSWORD) \
  -e TELNET_ENABLED=yes \
  -e SSH_DEBUG_LEVEL=1 \
  $(IMAGE_NAME):debian
```

<!-- markdownlint-enable MD013 -->

#### Step 3: Add telnet container to stop and clean targets

Update `stop` target to include the telnet container:

<!-- markdownlint-disable MD013 -->

```makefile
stop: ## Stop all running containers
 docker stop $(CONTAINER_NAME)-debian $(CONTAINER_NAME)-alpine $(CONTAINER_NAME)-dropbear $(CONTAINER_NAME)-telnet || true
 docker stop $(CONTAINER_NAME) $(CONTAINER_NAME)-debug || true
```

Update `clean` target similarly:

```makefile
clean: ## Remove containers and images
 docker rm -f $(CONTAINER_NAME)-debian $(CONTAINER_NAME)-alpine $(CONTAINER_NAME)-dropbear $(CONTAINER_NAME)-telnet || true
 docker rm -f $(CONTAINER_NAME) $(CONTAINER_NAME)-debug || true
 docker rmi $(IMAGE_NAME):debian $(IMAGE_NAME):alpine $(IMAGE_NAME):dropbear $(IMAGE_NAME):latest || true
 docker rmi $(IMAGE_NAME):$(IMAGE_TAG) || true
```

<!-- markdownlint-enable MD013 -->

#### Step 4: Add telnet-test target

After the `test-auth-dropbear` target (after line 156), add:

<!-- markdownlint-disable MD013 -->

```makefile
test-telnet: ## Quick telnet connection test
 @echo "Testing telnet connectivity on port $(TELNET_PORT)..."
 @echo "" | nc -w 3 localhost $(TELNET_PORT) && echo "✅ Telnet server is accessible" || echo "❌ Telnet server is not accessible"
```

<!-- markdownlint-enable MD013 -->

#### Step 5: Add compose-telnet target

After the `compose-agent-keys` target (after line 241), add:

```makefile
compose-telnet: ## Start telnet service via Docker Compose
 docker-compose --profile telnet up -d
```

#### Step 6: Verify

Run: `grep -n 'telnet\|TELNET' Makefile`
Expected: Shows TELNET_PORT variable, run-telnet,
test-telnet, compose-telnet targets.

#### Step 7: Commit

```bash
git add Makefile
git commit -m "feat: add telnet targets to Makefile"
```

---

## Task 9: Build and manually test

#### Step 1: Build the Debian image

Run: `make build-debian`
Expected: Image builds successfully with busybox package.

#### Step 2: Run container with telnet enabled

Run: `make run-telnet`
Expected: Container starts, logs show
"Telnet: Enabled (port 23)".

#### Step 3: Verify telnet connectivity

Run: `echo "" | nc -w 3 localhost 2323`
Expected: Receives telnet protocol data (login prompt bytes).

#### Step 4: Verify SSH still works

Run: `make test-connection-debian` (adjust port if needed)
Expected: SSH connection succeeds as before.

#### Step 5: Verify telnet is disabled by default

Run: `make run-debian` (without TELNET_ENABLED)
Then: `nc -z localhost 23` should fail (port not listening).

#### Step 6: Clean up

Run: `make stop && make clean`

#### Step 7: Commit if fixes were needed

If fixes were required, commit with an appropriate message.

---

## Task 10: Update CLAUDE.md with telnet configuration

**Files:**

- Modify: `CLAUDE.md`

#### Step 1: Add telnet configuration section

In the "Configuration System" section of CLAUDE.md, after the
"Network and Debug" subsection, add a "Telnet" subsection:

```markdown
### Telnet Configuration
- `TELNET_ENABLED`: Enable telnet server (yes/no, default: no)
- `TELNET_PORT`: Telnet server port (default: 23)
```

#### Step 2: Add telnet run example

In the "Building and Running" section, add:

<!-- markdownlint-disable MD013 -->

```bash
# Run with telnet enabled
make run-telnet
# Or: docker run -d --name ssh-test-dev -p 2222:22 -p 2323:23 \
#   -e SSH_USER=testuser -e SSH_PASSWORD=testpass123 \
#   -e TELNET_ENABLED=yes ssh-test-server:debian
```

<!-- markdownlint-enable MD013 -->

#### Step 3: Commit

```bash
git add CLAUDE.md
git commit -m "docs: add telnet configuration to CLAUDE.md"
```
