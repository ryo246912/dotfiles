[[ "${HOST_ENV:-}" == *work* ]] || return

# AWS
# https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html#envvars-list
export AWS_CLI_AUTO_PROMPT=on-partial
# aws-vault
export AWS_VAULT_BIOMETRICS=true
export AWS_VAULT_BACKEND=keychain
# terraform
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"

# ccmanagerのCCMANAGER_MULTI_PROJECT_ROOTはworkロールごとに異なるため、
# ここでは設定しない。lazy/workN.zsh（例: work2.zsh, work3.zsh）が担当する。
