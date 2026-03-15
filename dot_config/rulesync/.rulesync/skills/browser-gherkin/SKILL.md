---
name: browser-gherkin
description: 成功したブラウザ操作を、slot・開始 URL・安定 selector・期待結果を含む Gherkin に書き下す skill。Playwright で検証済みの画面操作を他 agent 向けに再現可能な手順へ固定したいときに使う。
targets:
  - claudecode
  - codexcli
---

# Browser Gherkin

## 概要

成功したブラウザ操作を、他 agent でも再現しやすい Gherkin に変換します。
探索メモの要約ではなく、実際に成功した最短手順だけを書きます。

## 変換前に揃える情報

- browser slot ID
- 開始 URL
- 実行した操作
- 使った selector
- 操作後に観測できた期待結果

1 つでも欠けるなら、先に `browser-ops` で再確認します。

## 必須ルール

- 成功した操作だけを対象にする
- `Given` に slot と開始 URL を入れる
- `When` には実際に使った selector の戦略を入れる
- `Then` には UI 上で観測できる結果を書く
- 座標、DOM index、探索途中の失敗手順は書かない
- selector は `role`、`text`、`data-testid`、安定した CSS の順で表現する

## 出力テンプレート

```gherkin
Feature: Browser operation replay

  Scenario: <short scenario name>
    Given browser slot "<slot>" is reachable at "<browserUrl>"
    And the page "<startUrl>" is open
    When the agent clicks "<selector>" by <selector strategy>
    Then <observable result>
```

## 書き下し方

- scenario 名は結果ベースで短く書く
- selector strategy は `role` や `text` のように具体的に書く
- `Then` は「見える」「開く」「URL が変わる」のように観測可能な形にする

## 例

```gherkin
Feature: Browser operation replay

  Scenario: Open settings menu from slot2
    Given browser slot "slot2" is reachable at "http://host.docker.internal:9223"
    And the page "https://example.com" is open
    When the agent clicks "role=button[name=\"Settings\"]" by role
    Then "role=menu[name=\"Settings\"]" is visible
```

成功が確認できていない補助情報や推測は、Gherkin に混ぜません。
