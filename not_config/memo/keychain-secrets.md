# Keychain Secrets Management

Inspired by [this tweet](https://x.com/RomanVDev/status/2044688769287106784), this setup uses the macOS Keychain to store sensitive environment variables. This allows for:

1. **Security**: Secrets are not stored in plain text files.
2. **Sync**: If iCloud Keychain is enabled, secrets sync across your Apple devices.
3. **Cleanliness**: `.env` or `.envrc` files only contain references to the Keychain.

## Setup

A wrapper function `keychain-cli` is provided in `dot_config/zsh/lazy/keychain.zsh`.

### Commands

- `keychain-cli set <account> [secret]`: Store a secret. If `secret` is omitted, you will be prompted.
- `keychain-cli get <account>`: Retrieve a secret.
- `keychain-cli delete <account>`: Remove a secret.
- `keychain-cli list`: List all accounts stored under the `keychain-cli` service.

## Integration with direnv

Instead of putting secrets in `.env`, use `.envrc` (via [direnv](https://direnv.net/)) to load them from the Keychain.

Example `.envrc`:

```bash
# Get secret from Keychain
export STRIPE_API_KEY=$(keychain-cli get stripe_api_key)
export GITHUB_TOKEN=$(keychain-cli get github_token)

# Traditional env vars
export APP_NAME="My Cool App"
```

## Why not a dedicated tool?

As mentioned in the inspiration tweet, using the built-in Keychain works fine and provides native sync through iCloud without needing third-party extensions or cloud services specifically for environment variables.
