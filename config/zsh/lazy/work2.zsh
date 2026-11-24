[[ "${HOST_ENV:-}" == *work2* ]] || return

# AWS
# https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html#envvars-list
export AWS_CLI_AUTO_PROMPT=on-partial
# aws-vault
export AWS_VAULT_BIOMETRICS=true
export AWS_VAULT_BACKEND=keychain
# ccmanager
export CCMANAGER_MULTI_PROJECT_ROOT=~/work/worktrees
# terraform
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
