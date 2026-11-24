[[ "${HOST_ENV:-}" == *work3* ]] || return

# AWS
# https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html#envvars-list
export AWS_CLI_AUTO_PROMPT=on-partial
# aws-vault
export AWS_VAULT_BIOMETRICS=true
export AWS_VAULT_BACKEND=keychain
# ccmanager
export CCMANAGER_MULTI_PROJECT_ROOT=~/Programming/work3/worktrees

# uv
export LDFLAGS="-L/opt/homebrew/opt/openssl@3/lib -L/opt/homebrew/opt/libpq/lib"
export CPPFLAGS="-I/opt/homebrew/opt/openssl@3/include -I/opt/homebrew/opt/libpq/include"
export PKG_CONFIG_PATH="/opt/homebrew/opt/openssl@3/lib/pkgconfig:/opt/homebrew/opt/libpq/lib/pkgconfig"
