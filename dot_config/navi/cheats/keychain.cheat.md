% keychain, mac, secrets

# Store a secret in Keychain (security command)

# Using service="keychain-cli" for consistency

security add-generic-password -a <account_name> -s "keychain-cli" -w <secret> -U

# Get a secret from Keychain (security command)

# Output only the password/secret (-w)

security find-generic-password -s "keychain-cli" -a <account_name> -w

# Delete a secret from Keychain (security command)

security delete-generic-password -a <account_name> -s "keychain-cli"

# List all accounts stored in Keychain under "keychain-cli"

security find-generic-password -s "keychain-cli" 2>/dev/null | grep "acct" | cut -d'=' -f2 | tr -d '"'

$ account_name: security find-generic-password -s "keychain-cli" 2>/dev/null | grep "acct" | cut -d'=' -f2 | tr -d '"'
