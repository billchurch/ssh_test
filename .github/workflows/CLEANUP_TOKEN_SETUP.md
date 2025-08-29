# GitHub Container Registry Cleanup Token Setup

## Required Token Permissions

The `RELEASE_PLEASE_TOKEN` used in the cleanup workflow requires the following scopes:

### For Personal Access Token (PAT):
- `write:packages` - Required to delete package versions
- `read:packages` - Required to list and read package metadata
- `delete:packages` - Required to delete packages (if available in your GitHub version)

## How to Create the Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token" → "Generate new token (classic)"
3. Give it a descriptive name like "Container Registry Cleanup"
4. Select the following scopes:
   - ✅ `write:packages` (Upload packages to GitHub Package Registry)
   - ✅ `read:packages` (Download packages from GitHub Package Registry)
   - ✅ `delete:packages` (Delete packages from GitHub Package Registry) - if available
5. Set an expiration (recommended: 90 days with rotation)
6. Click "Generate token" and copy the token

## Add Token to Repository Secrets

1. Go to your repository Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `RELEASE_PLEASE_TOKEN`
4. Value: Paste your PAT token
5. Click "Add secret"

## Alternative: Using GitHub App Token

If using a GitHub App instead of PAT:
1. The app needs `packages: write` permission
2. Install the app on your repository/organization
3. Use the app token in the workflow

## Verification

After setting up the token, you can verify it works by:
1. Running the workflow manually with dry-run enabled
2. Check the workflow logs for successful authentication
3. Verify no "permission denied" errors appear

## Security Best Practices

- Rotate tokens regularly (every 90 days)
- Use fine-grained PATs if available in your organization
- Limit token scope to only required permissions
- Never commit tokens to the repository
- Use repository secrets for all sensitive values