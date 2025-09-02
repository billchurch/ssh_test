# Using Generated SSH Keys for Testing

This guide shows how to use the SSH test server's generated keys to test other applications.

## Generate SSH Keys for Testing

```bash
# Generate keys in a persistent directory
./scripts/test-auth-methods.sh --container ssh-test-alpine --user testuser --generate-keys --keys-dir ./test-keys

# Or generate without running tests
mkdir -p ./my-test-keys
./scripts/test-auth-methods.sh --generate-keys --keys-dir ./my-test-keys --container dummy 2>/dev/null || true
```

## Start SSH Server with Generated Keys

```bash
# Start container with one of the generated public keys
# NOTE: SSH_PASSWORD is required even for key-only auth to unlock the account
docker run -d \
  --name ssh-test-server-alpine \
  -p 2244:22 \
  -e SSH_USER=testuser \
  -e SSH_PASSWORD=testpass123 \
  -e SSH_AUTHORIZED_KEYS="$(cat ./test-keys/test_ed25519_key.pub)" \
  -e SSH_PERMIT_PUBKEY_AUTH=yes \
  -e SSH_PERMIT_PASSWORD_AUTH=no \
  -e SSH_DEBUG_LEVEL=1 \
  ssh-test-server:alpine
```

## Test with SSH Client

```bash
# Test connection with generated private key
ssh -i ./test-keys/test_ed25519_key \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -p 2244 testuser@localhost \
    "echo 'SSH connection successful!'"
```

## Available Key Types

The script generates 4 different key types for compatibility testing:

- **RSA 2048-bit**: `test_rsa_2048_key` / `test_rsa_2048_key.pub`
- **RSA 4096-bit**: `test_rsa_4096_key` / `test_rsa_4096_key.pub` 
- **Ed25519**: `test_ed25519_key` / `test_ed25519_key.pub`
- **ECDSA 256-bit**: `test_ecdsa_256_key` / `test_ecdsa_256_key.pub`

## Testing Other Applications

### WebSSH Clients
```bash
# Use with your WebSSH application
# Point your WebSSH client to:
# - Host: localhost
# - Port: 2244
# - Username: testuser  
# - Private Key: content of ./test-keys/test_ed25519_key
```

### Automated Testing Scripts
```bash
#!/bin/bash
# Example test script using generated keys

PRIVATE_KEY="./test-keys/test_ed25519_key"
SSH_HOST="localhost"
SSH_PORT="2244"
SSH_USER="testuser"

# Test your application's SSH functionality
your-app --ssh-key "${PRIVATE_KEY}" \
         --ssh-host "${SSH_HOST}" \
         --ssh-port "${SSH_PORT}" \
         --ssh-user "${SSH_USER}"
```

### Docker Compose Integration
```yaml
version: '3.8'
services:
  ssh-server:
    image: ssh-test-server:latest
    ports:
      - "2244:22"
    environment:
      - SSH_USER=testuser
      - SSH_PASSWORD=testpass123
      - SSH_AUTHORIZED_KEYS_FILE=/keys/test_ed25519_key.pub
      - SSH_PERMIT_PUBKEY_AUTH=yes
      - SSH_PERMIT_PASSWORD_AUTH=no
    volumes:
      - ./test-keys:/keys:ro
      
  your-app:
    build: .
    depends_on:
      - ssh-server
    volumes:
      - ./test-keys:/app/ssh-keys:ro
    environment:
      - SSH_PRIVATE_KEY_PATH=/app/ssh-keys/test_ed25519_key
```

## Cleanup

```bash
# Remove generated keys when done
rm -rf ./test-keys

# Stop and remove test container
docker stop ssh-test-server
docker rm ssh-test-server
```