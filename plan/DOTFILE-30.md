# DOTFILE-30 ブラウザ操作 CLI の設定

## 概要

- Playwright の CDP 接続を使い、ホスト上の Google Chrome を CLI から操作できる導線を追加する。
- browser slot を最大 3 つまで定義し、host / devcontainer のどちらからでも同じ slot 名で切り替えられるようにする。
- 成功した操作を他エージェントへ再利用しやすい Gherkin に落とし込む shared skill を追加する。

## 要件

### 機能要件

- 3 つまでの Chrome remote debugging slot を単一の設定ファイルで管理できること。
- repo-local CLI から slot の一覧確認、起動コマンド生成、接続確認、ページ操作、スクリーンショット取得ができること。
- devcontainer から `host.docker.internal` と `ssh mac-host` を使ってホスト Chrome に到達できる手順を提供すること。
- browser 操作手順と成功した操作の Gherkin 化手順を shared skill として残すこと。

### 非機能要件

- 実装は CLI-only に閉じ、MCP や Desktop アプリ固有設定を前提にしないこと。
- host と devcontainer の差異は環境変数か自動判定で吸収し、同じ command surface を維持すること。
- `mise trust` が使えない環境でも Playwright helper が動くよう、mise shim ではなく実体バイナリ探索を優先すること。

### 制約条件

- 作業対象はこの repository copy のみとし、ホーム配下の実ファイル更新は行わない。
- Google Chrome の remote debugging port は既存ブラウザを壊さないよう slot ごとに分離する。
- 検証は benign な画面操作に限定し、危険な UI 変更や破壊的操作は行わない。

## 実装計画

### 1. Browser slot catalog と thin CLI を追加する

- `dot_config/browser-cli/slots.json` を追加し、slot ごとの `port` / `browserUrl` / `userDataDir` を定義する。
- `dot_local/bin/executable_browser-cli` を追加し、slot 解決、host command 生成、接続確認、Playwright helper への委譲を実装する。
- `dot_local/bin/executable_browser-playwright` を追加し、CDP 接続で `pages` / `goto` / `screenshot` / `click` を実行できるようにする。

### 2. Devcontainer とドキュメントを更新する

- `dot_config/devcontainer/devcontainer.json` に browser bridge 用の環境変数を追加する。
- `dot_config/devcontainer/scripts/executable_post-start.sh` に `mac-host` / `browser-cli` の案内を追加する。
- `setup.md` と `dot_config/navi/cheats/other.cheat.md` に host / devcontainer の両方で使う CLI-first 手順を追記する。
- `dot_config/rulesync/README.md` に shared skill の意図と source path を追記する。

### 3. Shared skill を追加する

- `browser-ops` skill で slot 選択、host/devcontainer 切り替え、fallback、検証の進め方を定義する。
- `browser-gherkin` skill で成功したブラウザ操作だけを Gherkin に書き下す規約とテンプレートを定義する。

## 技術的課題と対応策

- `host.docker.internal` はホスト側では名前解決できないため、slot 定義の `browserUrl` は placeholder 化し、CLI 側で host/container 向け URL に解決する。
- repo root で `node` / `playwright` の mise shim が trust 制約に引っかかるため、helper は mise install directory を直接探索する。
- devcontainer config は global 配置前提のため、repo source と適用後の両方で意味が通る文言に揃える。

## テスト計画

- `jq`, `bash -n`, `node --check`, `rg` による静的検証を行う。
- ホスト上で slot を起動し、`status`, `json-version`, `pages`, `screenshot`, `click` を順に smoke test する。
- コンテナ環境から `host.docker.internal` 経由で同じ slot に接続し、最低 1 つの benign な操作を再現する。
- 成功した操作を `browser-gherkin` のフォーマットで再記述し、再現に必要な前提だけを残す。

## リリース・運用メモ

- user-scope へ shared skill を反映する場合は `mise run rulesync-generate-user` と `chezmoi re-add` を使う。
- host 側へ dotfiles を反映した後は `browser-cli list` と `browser-cli status slot1` を最初の確認コマンドにする。

## 参考資料

- Playwright `BrowserType.connectOverCDP`: https://playwright.dev/docs/api/class-browsertype#browser-type-connect-over-cdp
- Playwright CLI: https://playwright.dev/docs/test-cli
