# Orca

[Orca](https://github.com/stablyai/orca) は、Codex や Claude Code などの CLI agent を
worktree ごとに起動し、desktop と mobile から状態確認・追加入力・差分レビューを行うための
アプリケーションです。この dotfiles では macOS 版を Homebrew で導入し、ログイン時に起動します。

## 導入

macOS の bootstrap を実行します。

```bash
mise run bootstrap:mac
```

既存環境で Orca だけを追加する場合も、同じ package task は冪等に実行できます。

```bash
mise run bootstrap:mac-packages
```

これは公式 tap の `stablyai/orca/orca` cask をインストールします。Homebrew から明示的に更新する
場合は次を実行します（Orca の stable channel に追従します）。

```bash
brew upgrade --cask orca
```

初回起動後は次を設定します。

1. home directory へのアクセスを許可する。
2. `~/.codex`、`~/.claude`、Ghostty 設定の import を確認する。
3. dotfiles repository を追加し、base ref を `origin/main` にする。
4. Codex / Claude Code は既存の CLI で一度ログインしてから、Orca の agent selector で選ぶ。
5. **Settings → Terminal** で Ghostty 設定を import し、OSC 52 clipboard を必要に応じて許可する。

## tmux と terminal emulator との共生

Orca の terminal は独立した PTY を持つ terminal emulator です。Ghostty / WezTerm などを置き換えず、
用途を分けて併用します。

- **Orca terminal（推奨）**: agent の起動、状態追跡、mobile からの操作、worktree ごとの terminal。
- **Ghostty / WezTerm + tmux**: 普段の shell、長時間の手動作業、Orca を終了しても保持したい既存 session。
- **同じ repository を同時操作しない**: Orca が作成した worktree は Orca から、通常 checkout は
  tmux から操作し、同じ working tree への同時書き込みを避ける。

この dotfiles の zsh は `TERM_PROGRAM=Orca` では tmux を自動 attach しません。これにより Orca が
各 agent process と terminal tab を直接追跡できます。Orca terminal 内で既存 tmux session が必要な
場合だけ明示的に attach します。

```bash
tmux list-sessions
tmux attach-session -t <session-name>
```

逆に Ghostty / WezTerm では従来どおり tmux が自動起動します。Orca 内で常時 tmux を自動起動すると、
Orca の tab/split、agent status、scrollback と tmux の window/pane が二重管理になるため推奨しません。
tmux 内で起動した任意の CLI agent は動作しますが、Orca の専用 agent launcher から起動した場合ほど
status や session metadata が統合されない点にも注意してください。

## mobile companion

mobile app は desktop の代替ではなく、desktop 上で動いている session の remote control です。
desktop の Orca を終了すると接続できないため、この dotfiles では Orca を macOS のログイン項目へ
追加します。

1. iOS は [App Store](https://apps.apple.com/us/app/orca-ide/id6766130217)、Android は
   [Orca Releases](https://github.com/stablyai/orca/releases) から公式版を導入する。
2. desktop Orca の account / status menu から pairing を開き、one-time code を表示する。
3. mobile で **Pair** を選び、code を入力する。
4. internet 越しでは **Orca Relay** を優先する。Relay を使う場合は desktop と mobile で同じ
   Orca account に sign in する。
5. LAN / Tailscale を使う場合は、mobile の host address に到達可能な IP または hostname を設定する。
   既定 port は `6768`。自宅 router でこの port を直接 internet 公開しない。

mobile からは agent の状態と terminal scrollback の確認、prompt への返信、Quick Commands、簡易的な
source control 操作ができます。Chat UI は読み書きしやすく、raw terminal は TUI や tmux の確認に向きます。
端末ごとに **Settings → Chat UI** で既定表示を選択できます。

接続できない場合は次を確認します。

- desktop Orca が起動中で、desktop / mobile の両方が最新である。
- pairing code の有効期限が切れていない。切れていれば再発行する。
- Relay では同じ Orca account、LAN / Tailscale では同じ到達可能な network path を使っている。
- Tailscale 利用時は macOS と mobile の双方が同じ tailnet に接続済みである。

詳細は公式の [install](https://www.onorca.dev/docs/install)、
[terminal](https://www.onorca.dev/docs/terminal)、
[mobile companion](https://www.onorca.dev/docs/mobile) を参照してください。
