[[ "${HOST_ENV:-}" == *work3* ]] || return

# AWS
# https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html#envvars-list
export AWS_CLI_AUTO_PROMPT=on-partial
# aws-vault
export AWS_VAULT_BIOMETRICS=true
export AWS_VAULT_BACKEND=keychain
# ccmanager
if command -v ccmanager >/dev/null 2>&1; then
    export CCMANAGER_MULTI_PROJECT_ROOT=~/Programming/work3/worktrees
fi
