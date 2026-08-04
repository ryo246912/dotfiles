# cSpell:disable
# プラグイン本体は sheldon(dot_config/sheldon/plugins.toml)で管理し、zsh-defer で遅延ロードする。
# このファイルは各プラグインの「読込後設定」（zinit の atload 相当）を担う。
#
# 実行タイミング:
#   .zshrc が `zsh-defer source lazy.zsh` で本ファイル群を遅延ロードする。sheldon が
#   キューした各プラグインの source より後に本ファイルが実行されるため、ここでの設定は
#   プラグイン本体のロード後に適用される（zinit の turbo + atload と同じ順序）。

# --- zsh-autosuggestions ---
# 補完候補のハイライト色。表示時に参照されるためロード順に依存せず設定できる。
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=100"
# 遅延ロード時は自動起動が次プロンプトまで遅れるため明示的に起動する。
(( $+functions[_zsh_autosuggest_start] )) && _zsh_autosuggest_start

# --- zsh-auto-notify（macOS のみ / sheldon の macos profile でロード）---
if [ "$(uname)" = "Darwin" ]; then
  export AUTO_NOTIFY_THRESHOLD=20
  AUTO_NOTIFY_IGNORE+=(
    "ccmanager"
    "claude"
    "czg"
    "chezmoi apply"
    "git branch"
    "git log"
    "git show"
    "git rebase"
    "gh-dash"
    "gh-actions-dash"
    "lazygit"
    "gitui"
    "gh pr create"
    "gh pr diff"
    "gh pr edit"
    "yazi"
  )
fi

# --- fast-syntax-highlighting ---
# コメントの配色。FAST_HIGHLIGHT_STYLES はプラグインロード時に生成されるため存在確認する。
(( ${+FAST_HIGHLIGHT_STYLES} )) && FAST_HIGHLIGHT_STYLES[comment]=white

# --- hlissner/zsh-autopair ---
# autopair.zsh は source 時に autopair-init を自動実行するため、追加の初期化は不要。

# NOTE: 補完(completion)について
#   zinit 時代に snippet で取得していた各種補完は以下に移行した:
#     - fzf(key-bindings/completion) ... lazy/mise.zsh で `source <(fzf --zsh)`
#     - docker / chezmoi             ... lazy/mise.zsh で `<tool> completion zsh` を生成
#     - git / tmux                   ... zsh 同梱の _git / _tmux を使用
#     - brew                         ... Homebrew 同梱の補完(FPATH)を使用
#   これらは mise で管理するツール本体のバージョンに追従する。
