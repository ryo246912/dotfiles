# Keychain Secrets Management

Inspired by [this tweet](https://x.com/RomanVDev/status/2044688769287106784), this setup uses the macOS Keychain to store sensitive environment variables. This allows for:

1. **Security**: Secrets are not stored in plain text files.
2. **Sync**: If iCloud Keychain is enabled, secrets sync across your Apple devices.
3. **Cleanliness**: `.env` or `.envrc` files only contain references to the Keychain.

## Setup

Instead of a heavy wrapper, we use `navi` snippets for interactive management and raw `security` commands for scripting/direnv.

### Interactive Management (via navi)

Run `navi` and search for `keychain` to:

- Store a secret
- Retrieve a secret
- Delete a secret
- List accounts

### Integration with direnv

In your `.envrc` file, reference the Keychain using the `security` command:

```bash
# Get secret from Keychain
export STRIPE_API_KEY=$(security find-generic-password -s "keychain-cli" -a "stripe_api_key" -w)
export GITHUB_TOKEN=$(security find-generic-password -s "keychain-cli" -a "github_token" -w)

# Traditional env vars
export APP_NAME="My Cool App"
```

## Why this approach?

As mentioned in the inspiration tweet, the built-in Keychain works fine. By using `navi` snippets, we avoid adding more code to the shell startup (lazy loading) while still providing a convenient interface for managing the secrets.
