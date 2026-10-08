#!/bin/bash
set -uo pipefail

# Docker Sandboxes 版の post-create / post-start 相当。
# sandbox 内で `sbx exec` から実行される（sbx には postCreateCommand が無いため、
# sbx-agent が sandbox へアタッチするたびに呼ぶ。全処理が冪等）。
#
# devcontainer の post-create.sh / post-start.sh のうち、sandbox 側で意味のある処理を行う。
# git 設定は sbx-agent が GIT_CONFIG_* で注入済みなのでここでは触らない。
#
# 失敗しても sandbox の起動は止めない（個々の処理を best-effort で進める）。

log_ok() { printf '✓ %s\n' "$1"; }
log_skip() { printf 'ℹ️ %s\n' "$1"; }
log_warn() { printf '⚠️ %s\n' "$1" >&2; }

scripts_dir="${HOME}/.config/devcontainer/scripts"

# ---------------------------------------------------------------------------
# ホストへの SSH 経路（通知 / host-tmux / plannotator tunnel の土台）
# ---------------------------------------------------------------------------
# devcontainer と同じ `mac-host` という SSH host 名で、ホストの sshd へ接続できるようにする。
# sandbox から見たホストは localhost ではなく host.docker.internal。
# 鍵は devcontainer 専用鍵（ホストの ~/.ssh/id_docker_devcontainer）をホストから read-only で
# マウントしているものを使う（個人鍵はマウントしない）。sbx はホストと同じ絶対パスに
# マウントするため、そのパスは SBX_HOST_SSH_KEY で渡される。
# 注意: 接続設定は ~/.config/ssh/config に書く。crit / host-tmux /
# ensure-plannotator-tunnel がこのパスを `ssh -F` で参照している。
setup_ssh_config() {
    local ssh_config="${HOME}/.config/ssh/config"
    local key="${SBX_HOST_SSH_KEY:-}"

    if [ -z "$key" ] || [ ! -f "$key" ]; then
        log_skip "ホスト通知用の SSH 鍵が無いため mac-host の設定をスキップしました（SBX_HOST_SSH_KEY=${key:-未設定}）"
        return 0
    fi

    # mount 元は read-only かつ権限が緩い場合があり ssh が鍵を拒否するため、コピーして 600 にする
    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"
    local local_key="${HOME}/.ssh/id_mac_host"
    if ! install -m 600 "$key" "$local_key" 2>/dev/null; then
        log_warn "SSH 鍵のコピーに失敗しました: $key"
        return 1
    fi
    mkdir -p "$(dirname "$ssh_config")"
    touch "$ssh_config"
    chmod 600 "$ssh_config"
    if grep -q '^Host mac-host$' "$ssh_config" 2>/dev/null; then
        log_skip "SSH config (mac-host) は既に存在します"
        return 0
    fi

    cat >>"$ssh_config" <<EOF
Host mac-host
    HostName host.docker.internal
    User ${HOST_USER:-$(id -un)}
    IdentityFile ${local_key}
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
EOF
    log_ok "SSH config を生成しました: ${ssh_config} (User: ${HOST_USER:-$(id -un)})"
}

# ---------------------------------------------------------------------------
# crit
# ---------------------------------------------------------------------------
# devcontainer では post-start.sh が `docker port` で host port を調べていたが、sandbox では
# ホスト側の sbx-agent が `sbx ports` で調べて SBX_CRIT_HOST_PORT として渡す。
setup_crit() {
    if [ ! -f "${HOME}/.crit.config.json" ]; then
        cat >"${HOME}/.crit.config.json" <<'EOF'
{
  "no_open": true,
  "agent_cmd": "claude --dangerously-skip-permissions -p"
}
EOF
        log_ok "~/.crit.config.json を生成しました"
    else
        log_skip "~/.crit.config.json は既に存在します"
    fi

    if [ -n "${SBX_CRIT_HOST_PORT:-}" ]; then
        printf '%s\n' "$SBX_CRIT_HOST_PORT" >"${HOME}/.crit-host-port"
        log_ok "crit の host port (${SBX_CRIT_HOST_PORT}) を ~/.crit-host-port に記録しました"
    else
        rm -f "${HOME}/.crit-host-port"
        log_skip "crit の host port が渡されていないため記録をスキップしました"
    fi
}

# ---------------------------------------------------------------------------
# AI agent の設定
# ---------------------------------------------------------------------------
setup_agent_configs() {
    # ~/.claude.json はホストから read-only でマウントしたものをコピーして使う
    # （マウント先はホストと同じ絶対パスなので、その場所は SBX_HOST_CLAUDE_JSON で渡される）
    local claude_config_host="${SBX_HOST_CLAUDE_JSON:-}"
    if [ ! -f "${HOME}/.claude.json" ] && [ -n "$claude_config_host" ] && [ -f "$claude_config_host" ]; then
        if cp "$claude_config_host" "${HOME}/.claude.json"; then
            log_ok ".claude.json をコピーしました"
        else
            log_warn ".claude.json のコピーに失敗しました"
        fi
    else
        log_skip ".claude.json のコピーはスキップしました"
    fi

    # CLAUDE_CONFIG_DIR はホストのパスを指す（sbx-agent が --env で設定）。
    # そのディレクトリ配下の projects / settings.json などはホストと共有されるため、
    # devcontainer のような account2/work3 への symlink 共有は不要。
}

# ---------------------------------------------------------------------------
# lefthook（AI エージェント用の pre-commit lint）
# ---------------------------------------------------------------------------
# devcontainer の post-create.sh と同じ判定: multi-worktree の task root は
# ccmanager 用の synthetic git repository なので、その場合は直下の各リポジトリを対象にする。
install_lefthook_all() {
    local template="${HOME}/.config/devcontainer/lefthook.local.yml"

    if ! command -v lefthook >/dev/null 2>&1; then
        log_skip "lefthook が無いため hook のインストールをスキップしました（template をビルドしてください）"
        return 0
    fi
    if [ ! -f "$template" ]; then
        log_skip "lefthook.local.yml が無いため hook のインストールをスキップしました"
        return 0
    fi

    local workspace_root workspace_branch
    workspace_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    [ -z "$workspace_root" ] && {
        log_skip "git リポジトリではないため lefthook のインストールをスキップしました"
        return 0
    }
    workspace_branch="$(git -C "$workspace_root" branch --show-current 2>/dev/null || true)"

    local -a repo_roots=()
    if [[ "$workspace_branch" == multi-worktree-* ]]; then
        local child_git child_root
        for child_git in "${PWD}"/*/.git; do
            [ -e "$child_git" ] || continue
            child_root="$(dirname "$child_git")"
            git -C "$child_root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue
            repo_roots+=("$child_root")
        done
    else
        repo_roots+=("$workspace_root")
    fi

    local repo_root config git_exclude
    for repo_root in ${repo_roots[@]+"${repo_roots[@]}"}; do
        config="${repo_root}/lefthook.local.yml"
        if [ ! -e "$config" ] && ! cp "$template" "$config"; then
            log_warn "${repo_root} への lefthook.local.yml の配置に失敗しました"
            continue
        fi
        if git_exclude="$(git -C "$repo_root" rev-parse --path-format=absolute --git-path info/exclude 2>/dev/null)"; then
            mkdir -p "$(dirname "$git_exclude")"
            grep -Fxq "lefthook.local.yml" "$git_exclude" 2>/dev/null \
                || echo "lefthook.local.yml" >>"$git_exclude"
        fi
        if (cd "$repo_root" && LEFTHOOK_CONFIG="$config" lefthook install >/dev/null 2>&1); then
            log_ok "${repo_root} に Lefthook をインストールしました"
        else
            log_warn "${repo_root} への Lefthook のインストールに失敗しました"
        fi
    done
}

# ---------------------------------------------------------------------------
# nvim
# ---------------------------------------------------------------------------
# ホストの ~/.config/nvim はホストと同じ絶対パスにマウントされる（sandbox 内の $HOME とは別）。
# nvim は $XDG_CONFIG_HOME/nvim しか見ないため、symlink を張って同じ設定を読ませる。
# プラグイン本体は stdpath("data") = sandbox 内の ~/.local/share/nvim に入る。
setup_nvim() {
    local host_nvim="${SBX_HOST_NVIM_CONFIG:-}"
    local target="${XDG_CONFIG_HOME:-${HOME}/.config}/nvim"

    if [ -z "$host_nvim" ] || [ ! -d "$host_nvim" ]; then
        log_skip "nvim 設定が渡されていないためスキップしました（SBX_HOST_NVIM_CONFIG=${host_nvim:-未設定}）"
        return 0
    fi
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$host_nvim" ]; then
        log_skip "nvim 設定の symlink は既に存在します"
        return 0
    fi
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        log_warn "既存の ${target} があるため nvim 設定の symlink を張りませんでした"
        return 1
    fi

    mkdir -p "$(dirname "$target")"
    if ln -sfn "$host_nvim" "$target"; then
        log_ok "nvim 設定を共有しました: ${target} -> ${host_nvim}"
    else
        log_warn "nvim 設定の symlink に失敗しました"
    fi
}

# ---------------------------------------------------------------------------
# gh stack -> gh-stack の alias
# ---------------------------------------------------------------------------
# gh は未知のサブコマンドを PATH から探さず、extension ディレクトリにあるものしか
# dispatch しない（cli/cli の pkg/cmd/extension/manager.go: Dispatch は m.list() の結果しか
# 見ない）ため、PATH 上に gh-stack があるだけでは `gh stack` は動かない。
# gh の shell alias（`!` 始まり）は `sh -c '<expansion>' -- <args>` で実行され、`--` が $0 を
# 埋めるので "$@" がそのまま引数になる（pkg/cmd/root/alias.go: expandShellAlias）。
#
# alias の保存先 ~/.config/gh/config.yml は認証情報と同じファイルのため sandbox には
# マウントしていない（sbx-agent のコメント参照）。そのためここで毎回用意する。
# `gh alias` は auth check を免除されている（pkg/cmd/alias/alias.go の DisableAuthCheck）ので、
# gh 未ログインの sandbox でも設定できる。
setup_gh_alias() {
    command -v gh >/dev/null 2>&1 || {
        log_skip "gh が無いため gh stack の alias をスキップしました"
        return 0
    }
    if gh alias list 2>/dev/null | grep -q '^stack:'; then
        log_skip "gh の stack alias は既に定義済みです"
        return 0
    fi
    if gh alias set stack '!gh-stack "$@"' >/dev/null 2>&1; then
        log_ok "gh stack -> gh-stack の alias を設定しました"
        return 0
    fi
    log_warn "gh stack の alias を設定できませんでした"
    return 1
}

# ---------------------------------------------------------------------------
# プロジェクト生成物の分離
# ---------------------------------------------------------------------------
# workspace はホストと共有されているため、node_modules / .venv / target などの
# OS 依存の生成物をそのまま作るとホスト側に Linux 版が書かれてしまう。
# devcontainer と同じスクリプトで sandbox ローカル領域へ bind mount して隠す。
# sandbox は microVM なので mount が使え、base image の agent ユーザーは sudo を持つ。
separate_artifacts() {
    local script="${scripts_dir}/mount-container-only-dirs.sh"

    [ -x "$script" ] || [ -f "$script" ] || {
        log_skip "mount-container-only-dirs.sh が無いため生成物の分離をスキップしました"
        return 0
    }
    if ! sudo -n true 2>/dev/null; then
        log_warn "パスワード無しの sudo が使えないため生成物の分離をスキップしました"
        return 1
    fi
    if bash "$script" "$PWD"; then
        return 0
    fi
    log_warn "生成物の分離に失敗しました（ホスト側に node_modules 等が書かれる可能性があります）"
    return 1
}

setup_nvim
separate_artifacts
setup_ssh_config
setup_crit
setup_agent_configs
setup_gh_alias
install_lefthook_all

# plannotator のホスト側トンネルは mac-host 経由。スクリプト自体は image に入っている。
if [ -x "${scripts_dir}/ensure-plannotator-tunnel" ]; then
    log_ok "plannotator / host-tmux のスクリプトは ${scripts_dir} にあります"
fi

exit 0
