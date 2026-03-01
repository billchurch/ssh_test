# Telnet Server Design

## Purpose

Add an optional telnet server to the Debian image for testing web-based
terminal clients (e.g., webssh2) against a plaintext telnet target. The telnet
server is disabled by default and enabled via environment variable, following
the existing pattern used by `SSH_AGENT_START`.

## Scope

- Debian image only (Alpine and Dropbear variants are not affected)
- Opt-in via `TELNET_ENABLED=yes` (default: `no`)
- Reuses existing `SSH_USER` / `SSH_PASSWORD` for authentication

## Environment Variables

| Variable | Default | Description |
| --- | --- | --- |
| `TELNET_ENABLED` | `no` | Enable/disable telnet server |
| `TELNET_PORT` | `23` | Port for telnet to listen on |

No new authentication variables. Telnet spawns `/bin/login` which
authenticates against the system user created by `create_ssh_user()`.

## Architecture

### Daemon

Uses `busybox telnetd` which provides proper telnet protocol negotiation
(option handling, terminal type, window size) while remaining lightweight
(~500KB package). The applet runs in the foreground via `-F` flag, backgrounded
by the entrypoint script alongside sshd.

### Process Model

```text
entrypoint.sh (PID 1)
  ├── /usr/sbin/sshd -D -e  (background, always)
  └── busybox telnetd -F     (background, when TELNET_ENABLED=yes)
```

Both child processes are tracked by PID and cleaned up in the `cleanup()`
signal handler on container shutdown.

## Files Changed

### `docker/Dockerfile`

- Add `busybox` to `apt-get install` line
- Add `TELNET_ENABLED=no` and `TELNET_PORT=23` to ENV block
- Add `EXPOSE 23`

### `docker/entrypoint.sh`

- Add `TELNET_PORT` validation in `validate_env()`
- Add `start_telnet()` function called from `main()` after `configure_sshd()`
- Update `print_startup_info()` to show telnet status
- Update `cleanup()` to kill telnetd process

### `examples/docker-compose.yml`

- Add `ssh-telnet` service with `telnet` profile

### `Makefile`

- Add `run-telnet` target
- Add `test-telnet` target (placeholder or wired to integration tests)

## Testing

- Telnet connectivity: connect to port, receive login prompt
- Successful login with correct credentials
- Failed login with wrong credentials
- Telnet disabled by default (port not listening)
- Custom port via `TELNET_PORT`
- Container shutdown cleanly terminates telnetd

## Backward Compatibility

Zero impact on existing users. `TELNET_ENABLED` defaults to `no`, so the image
behaves identically to the current release unless the user explicitly opts in.
