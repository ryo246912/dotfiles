# DOTFILE-14 claude-powerline 導入計画

## 概要

- `ccusage` ベースの Claude Code status line を `claude-powerline` へ置き換える。
- status line には現在の git ブランチ名と、Claude の 5 時間 block/session 指標が表示される状態を目標にする。
- dotfiles 本体だけでなく、devcontainer と `mise` の導入経路も `claude-powerline` 前提へ揃える。

## 要件

### 機能要件

- `dot_claude/settings.json` の `statusLine.command` を `claude-powerline` 実行へ切り替える。
- `dot_claude/claude-powerline.json` を追加し、表示内容を `git` と `block` に限定する。
- `dot_config/mise/config.toml` と `dot_config/devcontainer/mise.toml` の `ccusage` 導入設定を `claude-powerline` に置き換える。
- `dot_config/devcontainer/devcontainer.json` の `~/.config/ccusage` mount を削除する。
- `dot_config/ccusage/settings.json` を削除し、`ccusage` 専用設定を残さない。

### 非機能要件

- JSON / JSONC / TOML が既存の lint ルールで妥当な状態を保つ。
- upstream README の設定方法と整合する構成にする。
- 表示要件を満たすための最小差分に留め、不要なセグメントや mount を増やさない。

### 制約条件

- 作業対象はこの repository copy の `dotfiles` 配下に限定する。
- repo root の `mise.toml` は未 trust のため、検証で Node 系 CLI を使う場合は shim を迂回する。
- `block` セグメントの実表示は Claude Code の hook data 有無に依存するため、ローカル smoke check では CLI 実行可能性と出力形を優先確認する。

## 実装計画

### 1. Claude Code の status line を置き換える

- `dot_claude/settings.json` の `statusLine.command` を `claude-powerline` ベースへ変更する。
- `dot_claude/claude-powerline.json` を追加し、1 行で `git` と `block` だけが出る構成にする。
- `git` セグメントはブランチ名中心、`block` セグメントは残りセッション確認に寄せた表示へ調整する。

### 2. 導入経路を `claude-powerline` へ統一する

- `dot_config/mise/config.toml` と `dot_config/devcontainer/mise.toml` のパッケージ定義を `@owloops/claude-powerline` に差し替える。
- devcontainer から `ccusage` 専用 mount を外し、`.claude` mount だけで設定が届く状態にする。
- 廃止済みの `dot_config/ccusage/settings.json` を削除する。

### 3. 検証と公開を完了する

- `jq`, `taplo`, JSONC parse, `rg` で静的整合性を確認する。
- `claude-powerline` CLI をローカルで実行し、branch と block を含む status line が生成できることを確認する。
- 変更を commit / push し、draft PR を作成して Linear へ関連付ける。

## 変更対象ファイル

- `dot_claude/settings.json`
- `dot_claude/claude-powerline.json`
- `dot_config/mise/config.toml`
- `dot_config/devcontainer/mise.toml`
- `dot_config/devcontainer/devcontainer.json`
- `dot_config/ccusage/settings.json`
- `plan/DOTFILE-14.md`

## 検証方法

- `jq empty dot_claude/settings.json dot_claude/claude-powerline.json`
- `node -e "const fs=require('fs');const s=fs.readFileSync('dot_config/devcontainer/devcontainer.json','utf8').replace(/^\\s*\\/\\/.*$/mg,'');JSON.parse(s);"`
- `taplo format --check dot_config/mise/config.toml dot_config/devcontainer/mise.toml`
- `rg -n "ccusage|claude-powerline" dot_claude dot_config`
- `NPM_CONFIG_CACHE=/tmp/dotfile-14-npm-cache /Users/ryo./.local/share/mise/installs/node/22.19.0/bin/npx -y @owloops/claude-powerline@latest --style=powerline --config=dot_claude/claude-powerline.json`
- `git status --short && git add ... && git commit ...`

## リスクと未解決事項

- `block` セグメントはネイティブ rate limit data がない環境では transcript ベース表示へ fallback するため、ユーザー実環境と完全一致しない可能性がある。
- `gh` の認証や remote push 権限がない場合、PR 作成まで完了できない。
- repo root の `mise.toml` trust 制約があるため、検証コマンドは shim を避ける前提で実行する。
