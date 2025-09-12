Keyboard-Interactive Authentication – Options, Setup, and Plan

Overview
- Goal: Enable flexible keyboard-interactive (KI) authentication in the test containers for realistic client testing scenarios.
- Images: Debian and Alpine variants are supported; Debian provides the easiest path to PAM-backed KI.
- Current state: The images already support KI toggles via env and can run a PAM-backed password prompt as KI.

What Works Today (no code changes required)
- Enable KI: Set `SSH_CHALLENGE_RESPONSE_AUTH=yes`.
- Use PAM on Debian: Set `SSH_USE_PAM=yes` (Debian only; Alpine variant currently ships without PAM).
- Choose auth flows using `SSH_AUTH_METHODS`:
  - Only KI (password-like prompt): `keyboard-interactive`
  - 2-step with key then KI: `publickey,keyboard-interactive`
  - 2-step with password then KI: `password,keyboard-interactive`
- Example (Debian): use the user’s password as the KI response
  - Env:
    - `SSH_USER=kiuser`
    - `SSH_PASSWORD=kipass` (sets the user’s password)
    - `SSH_PERMIT_PASSWORD_AUTH=no` (prevent plain password method)
    - `SSH_PERMIT_PUBKEY_AUTH=no`
    - `SSH_CHALLENGE_RESPONSE_AUTH=yes`
    - `SSH_USE_PAM=yes`
    - `SSH_AUTH_METHODS=keyboard-interactive`
  - Connect: `ssh -o PreferredAuthentications=keyboard-interactive -p 2229 kiuser@localhost` and respond with `kipass`.
  - A ready-to-run profile exists under `examples/docker-compose.yml` → `ssh-keyboard-interactive`.

Planned Additions
1) Static OTP (fake second factor) assigned at runtime via ENV
   - Objective: Simulate a 2FA prompt using KI, where the response is a container-provided “one-time” value set at start.
   - Approach A (simple, no extra PAM modules): Reuse the account password as the OTP
     - Set `SSH_PERMIT_PASSWORD_AUTH=no` to avoid plain password logins.
     - Require a first factor plus KI: set `SSH_AUTH_METHODS=publickey,keyboard-interactive` (first factor = public key; second = KI where the response equals the user’s password, serving as the OTP).
     - Add a new env alias for clarity (planned): `SSH_KI_STATIC_OTP`. If set, the entrypoint will set the user’s Linux password to this value solely for KI use. This keeps “OTP” separate from any documented user password used elsewhere.
     - Pros: No new packages; works with existing OpenSSH + PAM on Debian.
     - Cons: KI prompt label is generic ("Password:"); functionally valid but not a custom "Verification code:" prompt.

   - Approach B (more realistic prompt/flow): Use a PAM module that prompts for a verification code
     - Debian: Install `libpam-google-authenticator` (TOTP) or `libpam-oath` (HOTP/TOTP) and configure `/etc/pam.d/sshd` to require it after public key or password.
     - Alpine: Install PAM-capable OpenSSH and modules (e.g., `openssh-server-pam`, `linux-pam`, plus the chosen PAM module), then enable `UsePAM yes`.
     - Pros: Realistic second-factor prompt and flow. Matches client expectations for TOTP-like KI.
     - Cons: Larger image and extra config. Requires changes to Dockerfiles and entrypoint.

2) Other KI methods to consider
   - TOTP: `libpam-google-authenticator` (user secret stored per-user, supports rate limiting and lockout).
   - HOTP/TOTP via OATH Toolkit: `libpam-oath` with tokens configured in a file (can be container-initialized).
   - RADIUS: `pam_radius_auth` to delegate to a test RADIUS server (can be another container).
   - DUO: `pam_duo` for push/SMS/OTP simulation (requires external service or a mock).
   - Policy and timing tests: `pam_time` (time-of-day), `pam_delay` (latency), `pam_faildelay` (throttling), `pam_permit` (always-pass) for client behavior testing.

Configuration Matrix and Guidance
- Debian (recommended for KI):
  - Enable KI: `SSH_CHALLENGE_RESPONSE_AUTH=yes`
  - Enable PAM: `SSH_USE_PAM=yes`
  - Choose method combinations via `SSH_AUTH_METHODS`:
    - `keyboard-interactive` (KI only)
    - `publickey,keyboard-interactive` (key then KI)
    - `password,keyboard-interactive` (password then KI)
  - Static OTP (Approach A):
    - Planned env: `SSH_KI_STATIC_OTP=123456`
    - Set `SSH_PERMIT_PASSWORD_AUTH=no`
    - Set `SSH_AUTH_METHODS=publickey,keyboard-interactive`
    - Result: client authenticates by public key, then enters `123456` at the KI prompt.

- Alpine (current image):
  - OpenSSH installed without PAM; KI toggles exist, but PAM-backed flows and advanced prompts require a PAM-enabled build.
  - Option 1: Keep simple KI tests on Debian; skip Alpine for KI second-factor scenarios.
  - Option 2 (planned): Provide an Alpine-PAM variant by adding `openssh-server-pam` and `linux-pam`, enabling `UsePAM yes`, and wiring the same env/options.

Examples
- 2FA with public key + KI (static OTP) – Debian
  - Intention: First factor = public key, second = KI response (static OTP).
  - Env (planned):
    - `SSH_USER=kiuser`
    - `SSH_AUTHORIZED_KEYS=$(cat test_key.pub)`
    - `SSH_PERMIT_PUBKEY_AUTH=yes`
    - `SSH_PERMIT_PASSWORD_AUTH=no`
    - `SSH_CHALLENGE_RESPONSE_AUTH=yes`
    - `SSH_USE_PAM=yes`
    - `SSH_AUTH_METHODS=publickey,keyboard-interactive`
    - `SSH_KI_STATIC_OTP=123456`  # entrypoint sets user’s password to this OTP for KI only
  - Client:
    - `ssh -i test_key -o PreferredAuthentications=publickey,keyboard-interactive -p 2224 kiuser@localhost`
    - Respond to KI with `123456`.

- 2FA with password + KI (static OTP) – Debian
  - Intention: First factor = password, second = KI response (static OTP). Useful to test multi-prompt flows.
  - Env (planned):
    - `SSH_USER=kiuser`
    - `SSH_PASSWORD=firstfactor`
    - `SSH_PERMIT_PASSWORD_AUTH=yes`
    - `SSH_PERMIT_PUBKEY_AUTH=no`
    - `SSH_CHALLENGE_RESPONSE_AUTH=yes`
    - `SSH_USE_PAM=yes`
    - `SSH_AUTH_METHODS=password,keyboard-interactive`
    - `SSH_KI_STATIC_OTP=654321`
  - Client:
    - `ssh -o PreferredAuthentications=password,keyboard-interactive -p 2224 kiuser@localhost`
    - Enter `firstfactor` then `654321` for KI.

Validation Tips
- Server-side: `docker logs -f <container>` with `SSH_DEBUG_LEVEL=2` or `3` to trace auth.
- Client-side:
  - Force KI path: `ssh -o PreferredAuthentications=keyboard-interactive ...`
  - Require combos: `ssh -o PreferredAuthentications=publickey,keyboard-interactive ...`
- Verify config in container: `docker exec <container> cat /etc/ssh/sshd_config`
- Check PAM on Debian: `docker exec <container> cat /etc/pam.d/sshd`

Implementation Plan (minimal changes)
1) Add static OTP env handling (Debian first)
   - New envs:
     - `SSH_KI_STATIC_OTP` (string, optional)
     - `SSH_KI_ENABLE` (bool, optional alias for `SSH_CHALLENGE_RESPONSE_AUTH`)
   - EntryPoint changes:
     - If `SSH_KI_STATIC_OTP` is set and `SSH_USE_PAM=yes`:
       - Ensure `SSH_PERMIT_PASSWORD_AUTH=no` (documented or auto-enforced with a warning).
       - Set the user’s password to `SSH_KI_STATIC_OTP` at startup strictly for KI use.
       - Recommend `SSH_AUTH_METHODS=publickey,keyboard-interactive` or `password,keyboard-interactive`.
     - Safety: Log clear warnings that this is a test-only OTP.

2) Optional advanced KI via PAM modules
   - Debian: Add optional install (build-arg or variant) for `libpam-google-authenticator` and/or `libpam-oath`.
   - EntryPoint: When enabled via env, write `/etc/pam.d/sshd` stanzas to require the chosen module after first factor.
   - Provide a helper script to pre-seed per-user secrets from env or mounted files.

3) Alpine PAM support (optional variant)
   - Create an Alpine-PAM image with `openssh-server-pam` and `linux-pam`.
   - Mirror Debian behavior for KI, static OTP, and optional TOTP.

Security and Caveats
- Never expose containers publicly; these flows are for testing.
- The static OTP is not secure; it is intentionally predictable for tests.
- With approach A, the KI prompt label is generic; clients typically only need a prompt/response round, not a specific label.
- When using real PAM modules, be aware of rate limits, lockouts, and secret storage.

Open Questions
- Do we prefer a dedicated Debian-only implementation first, or also ship an Alpine-PAM variant?
- Should the static OTP be per-user configurable (multi-user container)?
- Do we want a custom prompt message (e.g., "Verification code:")? That requires a PAM module that prompts.

How to Proceed
- If this plan looks good, I can:
  1) Wire `SSH_KI_STATIC_OTP` into the entrypoint (Debian image),
  2) Add an example Compose profile for key+KI(OTP) and password+KI(OTP), and
  3) Extend integration tests to cover KI flows and the 2-step combos.

