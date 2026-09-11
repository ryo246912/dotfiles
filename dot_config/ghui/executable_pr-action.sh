#!/usr/bin/env bash
# ghui の `e`(open in editor) から呼ばれる PR アクションランチャ。
#
# ghui はキーバインドを増やせず、任意のシェルコマンドを実行できるフックは
# editorCommand ただ一つしかない。そこでこのスクリプトを噛ませ、fzf で
# 複数のアクションから選べるようにする。
# ghui は TUI を suspend し、端末に接続した状態で `$SHELL -c` で実行するため、
# fzf の選択も nvim の起動もそのまま動く。
#
# 【引数を owner/repo と PR番号 に限っている理由】
# ghui の renderEditorCommand は {{...}} を素の文字列置換で埋めるだけで、
# シェルのクォートを一切しない(EditorOpener.ts が $SHELL -c に丸ごと渡す)。
# git のブランチ名は `;` `$( )` `|` `&` バッククォート `'` を含められるため、
# {{headRef}} / {{baseRef}} をテンプレートへ展開すると、細工したブランチ名の
# PR で `e` を押しただけで任意コマンドが実行されてしまう。
# ブランチ名はテンプレート経由で受け取らず、ここで gh から取得する。
# owner/repo は GitHub 側の文字種制限によりメタ文字を含みえず、PR番号は数値。
set -euo pipefail

repo=${1:-}
number=${2:-}
# repoPaths で解決されたローカルクローンのパス。未設定/不一致なら空になりうる。
repo_path=${3:-}

if [ -z "$repo" ] || [ -z "$number" ]; then
  echo "usage: ${0##*/} <owner/repo> <number> [repoPath]" >&2
  exit 2
fi
case "$number" in
  '' | *[!0-9]*)
    echo "error: PR番号が数値ではありません: $number" >&2
    exit 2
    ;;
esac

# 解決結果。コマンド置換(サブシェル)で受け取ると代入が親に伝わらないため、
# resolve 系の関数は戻り値だけを返し、結果はこのグローバルへ書く。
repo_dir=""
# PR のリポジトリを指していた remote 名。fetch 先として使う。
pr_remote=""

# $1 の clone が対象の PR と同じリポジトリを指す remote を持つか調べ、
# 見つかった remote 名を pr_remote に入れる。
# origin だけでなく全 remote を見るのは、fork を clone している場合に
# origin が自分の fork を指し、upstream 側が PR のリポジトリになるため。
# owner/repo に正規表現メタ文字が入りうるので glob で比較する。
match_remote() {
  local dir=$1 name url
  for name in $(git -C "$dir" remote 2>/dev/null); do
    url=$(git -C "$dir" remote get-url "$name" 2>/dev/null) || continue
    url=${url%.git}
    url=${url%/}
    case "$url" in
      *"/$repo" | *":$repo")
        pr_remote=$name
        return 0
        ;;
    esac
  done
  return 1
}

# repoPaths の指す場所を優先し、無ければ「今いる場所」を使う。
# ghui は tmux popup から pane_current_path を cwd にして起動されるため、
# repoPaths が未整備でもリポジトリ内から呼べば大抵は解決できる。
# どちらの候補も remote を検証する。総称パターン(:owner/:repo)を使っていると
# 別リポジトリや stale な clone が同じパスに居座ることがあり、検証しないと
# 誤った作業ツリーに対して checkout してしまうため。
resolve_repo_path() {
  local candidate top
  for candidate in "$repo_path" "$PWD"; do
    [ -n "$candidate" ] || continue
    top=$(git -C "$candidate" rev-parse --show-toplevel 2>/dev/null) || continue
    match_remote "$top" || continue
    repo_dir=$top
    return 0
  done
  return 1
}

require_repo_path() {
  if ! resolve_repo_path; then
    printf 'error: %s のローカルクローンが見つかりません。\n' "$repo" >&2
    printf '       ~/.config/ghui/config.json の repoPaths を設定するか、該当リポジトリ内から ghui を起動してください。\n' >&2
    return 1
  fi
}

# base ブランチ名は gh 経由で取得する(上記の理由によりテンプレートからは渡さない)。
# 取得した値はシェル変数としてクォートして使い、eval には一切通さない。
# head 側は refs/ghui/head-<番号> と pull/<番号>/head で足りるので取得しない。
base_ref=""
load_base_ref() {
  base_ref=$(gh pr view "$number" --repo "$repo" --json baseRefName --jq .baseRefName)
}

action=$(
  printf '%s\n' \
    "diff     : PR の差分を Diffview で見る (checkout しない)" \
    "checkout : PR を checkout して Diffview で見る" \
    "open     : ローカルクローンを エディタ で開く" \
    "merge    : gh pr merge --admin でマージする" |
    fzf --header="$repo #$number" --layout=reverse --border
) || exit 0
action=${action%% *}

case "$action" in
  diff)
    require_repo_path || exit 1
    load_base_ref
    # 作業ツリーとブランチを一切触らずに差分だけ見たいので、checkout せず
    # refs/ghui/ 配下の専用 ref へ fetch して、その2点間を Diffview で開く。
    # fetch 先は origin 固定にしない。fork の clone では origin が自分の fork を
    # 指しており、対象の base も pull/<番号>/head も取得できないため。
    git -C "$repo_dir" fetch --no-tags --force "$pr_remote" \
      "$base_ref:refs/ghui/base-$number" \
      "pull/$number/head:refs/ghui/head-$number"
    # nvim の -c に渡す文字列にはブランチ名を入れない。`|` はブランチ名にも
    # 使えてしまい、Ex コマンドの区切りとして解釈されるため。番号だけを使う。
    (cd "$repo_dir" && nvim -c "DiffviewOpen refs/ghui/base-$number...refs/ghui/head-$number")
    ;;
  checkout)
    require_repo_path || exit 1
    load_base_ref
    # base も専用 ref へ取り込み、checkout 後の HEAD と比較する。
    # 未コミットの変更があると gh pr checkout が失敗するが、set -e で止まってよい。
    git -C "$repo_dir" fetch --no-tags --force "$pr_remote" "$base_ref:refs/ghui/base-$number"
    (
      cd "$repo_dir"
      gh pr checkout "$number" --repo "$repo"
      nvim -c "DiffviewOpen refs/ghui/base-$number...HEAD"
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
