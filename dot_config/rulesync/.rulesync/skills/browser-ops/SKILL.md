---
name: browser-ops
description: host または devcontainer から browser slot を選択し、Playwright CDP でホスト Chrome を確認・操作するときに使う skill。`browser-cli` の使い分け、slot 切り替え、fallback、検証の進め方が必要なときに使う。
targets:
  - claudecode
  - codexcli
---

# Browser Ops

`browser-cli` で host Chrome の remote debugging slot を操作するときに使います。

## 使う前に確認すること

- slot 定義: `dot_config/browser-cli/slots.json`
- CLI: `dot_local/bin/executable_browser-cli`
- Playwright helper: `dot_local/bin/executable_browser-playwright`

repo source 上では `./dot_local/bin/executable_browser-cli ...`、適用後は `browser-cli ...` を優先します。

## 基本フロー

1. slot を選ぶ
   - `./dot_local/bin/executable_browser-cli list`
   - `./dot_local/bin/executable_browser-cli show slot2`
2. host Chrome を起動する
   - host から直接: `./dot_local/bin/executable_browser-cli start slot2`
   - devcontainer から: `ssh mac-host "$(./dot_local/bin/executable_browser-cli host-command start slot2)"`
3. 接続を確認する
   - `./dot_local/bin/executable_browser-cli status slot2`
   - `./dot_local/bin/executable_browser-cli json-version slot2`
4. benign な操作を試す
   - page 一覧: `./dot_local/bin/executable_browser-cli pages slot2`
   - 遷移: `./dot_local/bin/executable_browser-cli goto slot2 https://example.com`
   - 画面保存: `./dot_local/bin/executable_browser-cli screenshot slot2 https://example.com /tmp/example-slot2.png`
   - クリック: `./dot_local/bin/executable_browser-cli click slot2 https://example.com 'text=More information...'`

## host / devcontainer の使い分け

- host:
  - `browser-cli` は `127.0.0.1` を自動で使います。
  - `start` はローカルで Chrome を起動します。
- devcontainer:
  - `browser-cli` は `host.docker.internal` を自動で使います。
  - `start` は `ssh mac-host` 経由で host 側に起動コマンドを投げます。

必要なら `BROWSER_CLI_TARGET=host|container` と `BROWSER_CLI_BROWSER_HOST=<host>` で明示できます。

## fallback

- `host.docker.internal` が解決できない:
  - `python -c "import socket; print(socket.gethostbyname('host.docker.internal'))"` で確認する
  - 解決しない場合は `BROWSER_CLI_BROWSER_HOST` で host IP を明示する
- `ssh mac-host` が使えない:
  - `~/.config/ssh/config` に `Host mac-host` があるか確認する
  - ない場合は `dot_config/devcontainer/scripts/executable_post-start.sh` の生成内容に合わせる
- Playwright helper が `playwright` を解決できない:
  - `PLAYWRIGHT_NODE_MODULES` で node_modules path を明示する
- sandbox や一時検証で profile dir を `HOME` 配下に作れない:
  - `BROWSER_CLI_USER_DATA_ROOT=/tmp/browser-cli-profiles` のように書き込み先を切り替える

## 完了条件

- どの slot を使ったか
- 到達に使った経路が host か devcontainer か
- 成功した command と結果

ここまで揃ったら `browser-gherkin` skill を開き、成功した操作だけを Gherkin に落とします。
