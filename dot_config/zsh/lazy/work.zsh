# AWS
# https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html#envvars-list
export AWS_CLI_AUTO_PROMPT=on-partial
# aws-vault
export AWS_VAULT_BIOMETRICS=true
export AWS_VAULT_BACKEND=keychain
# ccmanager
# work3ロールは別パスを使うため、ここでは設定しない（lazy/work3.zshが担当）。
# glob順はLC_COLLATE依存で信頼できないため、読み込み順に頼らずここで明示的に除外する。
if command -v ccmanager >/dev/null 2>&1 && [[ "${HOST_ENV:-}" == *work* ]] && [[ "${HOST_ENV:-}" != *work3* ]]; then
    export CCMANAGER_MULTI_PROJECT_ROOT=~/work/worktrees
fi
# terraform
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
