#!/bin/bash
set -euo pipefail

repo_root=$1
mode=${2:-}
template="$(cd -- "$(dirname -- "$0")/.." && pwd)/lefthook-local.yml"
config=lefthook-local.yml

cd "$repo_root"

install_hooks() (
    local stem extension
    if [[ "$mode" == --quiet ]]; then
        exec >/dev/null 2>&1
    fi
    for stem in lefthook .lefthook .config/lefthook; do
        for extension in yml yaml json jsonc toml; do
            if [[ -e "$stem.$extension" ]]; then
                env -u LEFTHOOK_CONFIG lefthook install
                return
            fi
        done
    done

    # Lefthook 2.2.1 の install は主設定がないと lefthook.yml を生成する。
    # インストール時だけ空の主設定を渡し、ローカル設定は標準の探索で読み込む。
    local temp_dir
    temp_dir="$(mktemp -d)"
    trap 'rm -rf -- "$temp_dir"' EXIT
    printf '{}\n' > "$temp_dir/lefthook.yml"
    LEFTHOOK_CONFIG="$temp_dir/lefthook.yml" lefthook install
)

if [[ "$mode" == --install-only ]]; then
    install_hooks
    exit 0
fi

if [[ ! -r "$template" ]]; then
    printf '⚠️ Lefthook のテンプレートを読み込めません。%s\n' "$template" >&2
    exit 1
fi

# 旧テンプレートの内容を識別し、編集済みの設定だけ手動移行を案内する。
legacy_template_sha256=42d0f6fbcb66b24db9efa9a359e2f0a3241ca7ac00c832ecfeb92ddccf84b00e
if [[ -f lefthook.local.yml ]] && ! sha256sum --status -c <<< "$legacy_template_sha256  lefthook.local.yml"; then
    printf '⚠️ %s の lefthook.local.yml を確認し、設定を lefthook-local.yml に移行してください。\n' "$repo_root" >&2
    if [[ ! -e "$config" ]]; then
        exit 0
    fi
fi

# Lefthook は候補のうち最初のローカル設定だけを読み込む。
for stem in lefthook-local .lefthook-local .config/lefthook-local; do
    for extension in yml yaml json jsonc toml; do
        candidate="$stem.$extension"
        if [[ ! -e "$candidate" && ! -L "$candidate" ]]; then
            continue
        fi
        if [[ "$candidate" == "$config" ]] && cmp -s "$template" "$candidate"; then
            continue
        fi
        printf '⚠️ %s に既存の %s があるため、AI 用 Lefthook 設定の配置をスキップしました。\n' "$repo_root" "$candidate" >&2
        exit 0
    done
done

git_exclude="$(git rev-parse --path-format=absolute --git-path info/exclude)"
mkdir -p "$(dirname "$git_exclude")"
if ! grep -Fxq "/$config" "$git_exclude" 2>/dev/null; then
    printf '/%s\n' "$config" >> "$git_exclude"
fi

if [[ ! -e "$config" ]]; then
    (set -o noclobber; cat "$template" > "$config")
fi

install_hooks
printf '✓ %s に Lefthook をインストールしました\n' "$repo_root"
