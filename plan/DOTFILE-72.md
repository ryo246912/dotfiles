# DOTFILE-72 multi-worktree の Go 化と切り出し準備

## 概要

- 現在 `dot_local/bin/executable_multi-worktree` に集約されている multi-worktree CLI を Go に移し、将来このディレクトリごと別リポジトリへ切り出せる構成に整理する。
- 既存の設定ファイルパス、主要サブコマンド、補完、README ベースの利用フローは維持しつつ、Bash 固有の肥大化した実装を分割して保守しやすくする。

## 要件

### 機能要件

- `create` / `recreate` / `list` / `status` / `status main` / `sync` / `cd` / `dev` / `exec` / `exec main` / `open` / `remove` / `help` を Go 実装へ移す。
- 既存の設定ファイルパス `~/.config/multi-worktree/config.toml` とサンプル設定ファイルの形式を維持する。
- task root の synthetic git repository 作成、`.devcontainer/devcontainer.json` 生成、`.claude/settings.local.json` 生成を継続サポートする。
- shell 補完と README を Go 実装に追従させる。
- dotfiles 内では新しい実装を単独ディレクトリに配置し、将来そのまま別リポジトリへ移せる形にする。

### 非機能要件

- Bash の簡易パーサや巨大な単一ファイル実装を避け、責務ごとにパッケージ分割する。
- destructive な操作 (`remove`, `sync --all`) は現行と同等以上の安全性を保つ。
- 既存の外部依存 (`git`, `devcontainer`, `code`, `rsync`, `jq` など) は存在確認と失敗時メッセージを明確にする。
- テストしやすいように、設定読み込み、パス解決、task/repo 解決、コマンド実行境界を分離する。

### 制約条件

- 作業はこのリポジトリ内で完結させる。
- chezmoi 管理下のエントリポイントと設定配置は維持する。
- 実装着手は plan 承認後に限定する。

## 実装方針

### 1. 切り出し前提の新規ディレクトリを作る

- 新規トップレベルディレクトリ `tools/multi-worktree/` を作り、ここを将来の別リポジトリ原型にする。
- 配下に `go.mod`, `cmd/multi-worktree`, `internal/...`, `README.md`, `completions/`, `examples/` を置き、自己完結した構造にする。
- dotfiles 側の `dot_local/bin/executable_multi-worktree` は薄い起動ラッパーへ寄せ、実体ロジックは `tools/multi-worktree/` に集約する。

### 2. CLI と設定読み込みを Go に置き換える

- CLI には `cobra` を使い、サブコマンド構造、ヘルプ、shell completion 生成を Go 側で一元管理する。
- 設定ファイルは TOML ライブラリで構造体に読み込み、`groups.*`, `settings`, `settings.devcontainer`, `dev_commands` を型安全に扱う。
- 現在のパス展開、group 解決、task root 命名規則、default branch 解決を `internal/config` / `internal/pathutil` / `internal/task` に分ける。

### 3. Git / worktree 操作を責務分離して移植する

- `internal/gitops` に `fetch`, `worktree add/remove/prune`, `branch resolve`, `status`, `HEAD` 取得などの実行境界をまとめる。
- `create` / `recreate` / `sync` / `remove` は現行挙動を踏襲しつつ、コマンド実行と判定ロジックを分離してテスト可能にする。
- `list`, `status`, `exec`, `open`, `cd` は CLI 入出力と core ロジックを分ける。
- `dev` は `devcontainer` 実行前後の判定だけを Go 化し、実コマンド実行自体は外部コマンド呼び出しで維持する。

### 4. task 補助ファイルと配布資産を整理する

- `.devcontainer/devcontainer.json` と `.claude/settings.local.json` の生成処理を `internal/scaffold` に分離する。
- 補完スクリプトは Go から生成できるものを優先し、`dot_config/multi-worktree/completion.bash` と `dot_config/multi-worktree/_multi-worktree` へ反映する。
- `dot_config/multi-worktree/README.md` と `config.toml.sample` は Go 実装の配置・起動方法に合わせて更新する。

## 変更対象ファイル

- 新規: `tools/multi-worktree/**`
- 更新: `dot_local/bin/executable_multi-worktree`
- 更新: `dot_config/multi-worktree/README.md`
- 更新: `dot_config/multi-worktree/config.toml.sample`
- 更新: `dot_config/multi-worktree/completion.bash`
- 更新: `dot_config/multi-worktree/_multi-worktree`
- 必要に応じて更新: `README.md` または setup 系ドキュメント

## 検証方法

- `env -i PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin HOME="$HOME" TMPDIR="${TMPDIR:-/tmp}" GOCACHE="${TMPDIR:-/tmp}/multi-worktree-go-cache/build" GOPATH="${TMPDIR:-/tmp}/multi-worktree-go-cache/path" GOMODCACHE="${TMPDIR:-/tmp}/multi-worktree-go-cache/mod" go test ./tools/multi-worktree/...`
- `env -i PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin HOME="$HOME" TMPDIR="${TMPDIR:-/tmp}" GOCACHE="${TMPDIR:-/tmp}/multi-worktree-go-cache/build" GOPATH="${TMPDIR:-/tmp}/multi-worktree-go-cache/path" GOMODCACHE="${TMPDIR:-/tmp}/multi-worktree-go-cache/mod" go run ./tools/multi-worktree/cmd/multi-worktree --help`
- 一時ディレクトリ上に複数のテスト用 git リポジトリを作成し、`create` / `recreate` / `list` / `status` / `sync` / `remove` をスモークテストする。
- `dot_local/bin/executable_multi-worktree --help` で既存エントリポイントから新実装へ到達できることを確認する。

## リスクと対応策

- 現行スクリプトは 2200 行超で責務が混在しており、暗黙仕様の取りこぼしが起きやすい。
  - README と既存コマンド分岐を突き合わせ、主要サブコマンドごとに parity checklist を作る。
- Usage では `--branch` と書かれている一方、実装は `--from` を受け付けており不一致がある。
  - Go 実装では後方互換を意識して alias 対応するか、どちらを正とするかを明示して README を合わせる。
- `git fetch origin main` はこの sandbox では `.git/FETCH_HEAD` 更新に失敗した。
  - 実装前の同期証跡はローカル参照 (`HEAD == origin/main`) で残し、実装時の追加 fetch が必要なら同じ制約を前提に扱う。
- `go` は shell shim 経由だと `mise trust` 制約に当たる。
  - 検証コマンドでは `env -i` で PATH / HOME / Go cache を明示し、実バイナリを直接使う。

## 未解決事項

- `tools/multi-worktree/` のバイナリを dotfiles 上でどう起動するかは、薄いラッパーで `go run` を使うか、ビルド済みバイナリ前提にするかを実装時に決める必要がある。
- 引数なしの `dev` に使う内蔵 fuzzy picker が TTY なし環境でどこまで扱えるかは、必要に応じて追加改善を検討する。
