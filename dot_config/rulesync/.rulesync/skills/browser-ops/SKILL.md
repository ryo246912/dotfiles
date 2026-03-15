---
name: browser-ops
description: host Chrome の remote debugging slot を CLI-only で起動・確認し、devcontainer から Playwright で接続するときに使う skill。複数 slot の切り替え、host/devcontainer の経路整理、最小限の画面操作確認が必要なときに使う。
targets:
  - claudecode
  - codexcli
---

# Browser Operations

## 概要

host Chrome の remote debugging slot を CLI-only で扱うための skill です。
この repo では slot 定義の正本を `dot_config/browser-cli/slots.json` に置き、deploy 後は `~/.config/browser-cli/slots.json` から参照します。

## 基本ルール

- MCP や Desktop 設定には触れず、CLI と repo source だけで完結させる
- slot は raw port ではなく `slot1` から `slot3` の ID で扱う
- host Chrome の起動は host 側で行い、devcontainer からは `ssh mac-host` で呼び出す
- 画面操作前に `slot`、開始 URL、使う selector、期待結果をメモする
- selector は `role`、`text`、`data-testid`、安定した CSS の順で選び、座標クリックは避ける

## 使い分け

### host で直接使う

```sh
browser-cli list
browser-cli start slot1
browser-cli status slot1
browser-cli json-version slot1
browser-cli pages slot1
```

### devcontainer から host Chrome を起動する

`mac-host` alias は devcontainer の `post-start.sh` が作ります。repo source をそのまま使う場合は次を優先します。

```sh
./dot_local/bin/executable_browser-cli host-command start slot2
ssh mac-host "$(./dot_local/bin/executable_browser-cli host-command start slot2)"
curl http://host.docker.internal:9223/json/version
./dot_local/bin/executable_browser-cli pages slot2
```

deploy 済みなら `browser-cli` へ置き換えて構いません。

## 操作フロー

1. `browser-cli list` で対象 slot を決める
2. host で slot を起動する
3. `browser-cli status <slot>` または `curl <browserUrl>/json/version` で疎通確認する
4. `browser-cli pages <slot>` で既存 tab を確認する
5. 必要なら `browser-cli goto`、`browser-cli screenshot`、`browser-cli click` を使う
6. 成功した操作だけを `browser-gherkin` skill で Gherkin 化する

## Playwright helper の最小コマンド

```sh
browser-cli goto slot2 https://example.com
browser-cli screenshot slot2 https://example.com /tmp/slot2-example.png
browser-cli click slot2 https://example.com 'role=button[name="Settings"]' 'role=menu[name="Settings"]'
```

`click` の第 4 引数は成功確認用 selector です。分かる場合は必ず付けます。

## 失敗時の切り分け

- `status` や `json-version` が失敗する:
  host Chrome が未起動、または devcontainer から `host.docker.internal` を解決できていない
- `pages` は通るが `click` が失敗する:
  selector が不安定、または page 遷移前提が不足している
- `browser-cli` が config を読めない:
  `BROWSER_CLI_CONFIG` を source の `slots.json` に向ける

失敗ログはそのまま skill 化せず、成功した最短手順だけを残します。
