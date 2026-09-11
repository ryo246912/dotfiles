#!/usr/bin/env bash
# ghui の `e`(open in editor) から呼ばれる PR アクションランチャ。
#
# ghui はキーバインドを増やせず、任意のシェルコマンドを実行できるフックは
# editorCommand ただ一つしかない。そこでこのスクリプトを噛ませ、fzf で
# 複数のアクションから選べるようにする。
# ghui は TUI を suspend し、端末に接続した状態で `$SHELL -c` で実行するため、
# fzf の選択も nvim の起動もそのまま動く。
set -euo pipefail

repo=${1:-}
number=${2:-}
base_ref=${3:-}
head_ref=${4:-}
# repoPaths で解決されたローカルクローンのパス。未設定/不一致なら空になりうる。
repo_path=${5:-}

if [ -z "$repo" ] || [ -z "$number" ]; then
  echo "usage: ${0##*/} <owner/repo> <number> [baseRef] [headRef] [repoPath]" >&2
  exit 2
fi

# $1 の clone の origin が対象の PR と同じリポジトリを指しているか判定する。
# owner/repo に正規表現メタ文字が入りうるため glob で比較する。
remote_matches() {
  local url
  url=$(git -C "$1" remote get-url origin 2>/dev/null) || return 1
  url=${url%.git}
  url=${url%/}
  case "$url" in
    *"/$repo" | *":$repo") return 0 ;;
    *) return 1 ;;
  esac
}

# repoPaths の指す場所を優先し、無ければ「今いる場所が同じリポジトリなら」それを使う。
# ghui は tmux popup から pane_current_path を cwd にして起動されるため、
# repoPaths が未整備でもリポジトリ内から呼べば大抵は解決できる。
resolve_repo_path() {
  local top
  if [ -n "$repo_path" ] && top=$(git -C "$repo_path" rev-parse --show-toplevel 2>/dev/null); then
    printf '%s\n' "$top"
    return 0
  fi
  if top=$(git rev-parse --show-toplevel 2>/dev/null) && remote_matches "$top"; then
    printf '%s\n' "$top"
    return 0
  fi
  return 1
}

# 解決できた場合だけ repo_dir に入れる。コマンド置換の中で exit しても
# サブシェルが終わるだけでスクリプトは止まらないため、呼び出し側で `|| exit 1` する。
repo_dir=""
require_repo_path() {
  if ! repo_dir=$(resolve_repo_path); then
    printf 'error: %s のローカルクローンが見つかりません。\n' "$repo" >&2
    printf '       ~/.config/ghui/config.json の repoPaths を設定するか、該当リポジトリ内から ghui を起動してください。\n' >&2
    return 1
  fi
}

action=$(
  printf '%s\n' \
    "diff     : PR の差分を Diffview で見る (checkout しない)" \
    "checkout : PR を checkout して Diffview で見る" \
    "open     : ローカルクローンを エディタ で開く" \
    "merge    : gh pr merge --admin でマージする" |
    fzf --header="$repo #$number  ($head_ref -> $base_ref)" --layout=reverse --border
) || exit 0
action=${action%% *}

case "$action" in
  diff)
    require_repo_path || exit 1
    # 作業ツリーとブランチを一切触らずに差分だけ見たいので、checkout せず
    # refs/ghui/ 配下の専用 ref へ fetch して、その2点間を Diffview で開く。
    git -C "$repo_dir" fetch --no-tags --force origin \
      "$base_ref:refs/ghui/base-$number" \
      "pull/$number/head:refs/ghui/head-$number"
    (cd "$repo_dir" && nvim -c "DiffviewOpen refs/ghui/base-$number...refs/ghui/head-$number")
    ;;
  checkout)
    require_repo_path || exit 1
    # base を最新にしてから checkout する。未コミットの変更があると
    # gh pr checkout が失敗するが、その場合は set -e でここで止めてよい。
    git -C "$repo_dir" fetch --no-tags origin "$base_ref"
    (
      cd "$repo_dir"
      gh pr checkout "$number" --repo "$repo"
      nvim -c "DiffviewOpen origin/$base_ref...HEAD"
    )
    ;;
  open)
    require_repo_path || exit 1
    (cd "$repo_dir" && exec "${VISUAL:-${EDITOR:-nvim}}" .)
    ;;
  merge)
    # --admin は branch protection を迂回するため、誤爆防止に確認を挟む。
    printf '%s #%s を --admin でマージします。よろしいですか? [y/N] ' "$repo" "$number"
    read -r reply
    case "$reply" in
      [yY] | [yY][eE][sS]) ;;
      *)
        echo "中止しました"
        exit 0
        ;;
    esac
    gh pr merge "$number" --repo "$repo" --admin
    ;;
  *)
    echo "unknown action: $action" >&2
    exit 1
    ;;
esac
