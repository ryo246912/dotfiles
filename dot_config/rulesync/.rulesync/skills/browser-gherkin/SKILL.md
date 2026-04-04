---
name: browser-gherkin
description: 成功したブラウザ操作を、他エージェントが再実行しやすい Gherkin に書き下す skill。host / devcontainer の前提、slot、安定した selector、成功条件を整理したいときに使う。
targets:
  - claudecode
  - codexcli
---

# Browser Gherkin

この skill は、実際に成功したブラウザ操作だけを Gherkin に再記述するときに使います。未検証の推測手順は書きません。

## 入力に含めるもの

- 実行環境: `host` または `devcontainer`
- 使用 slot: `slot1` など
- 開始 URL
- 実際に成功した selector
- 成功条件: URL 変化、表示文言、保存ファイルなど

## 書き方のルール

- `Feature` は目的を 1 行で書く
- `Scenario` は 1 つの成功した操作に絞る
- `Given` には slot と到達経路を含める
- `When` は観測可能な UI 操作だけを書く
- `Then` は機械的に確認できる結果だけを書く
- 手元で失敗した fallback や調査メモは Gherkin に混ぜず、別メモへ分離する

## テンプレート

```gherkin
Feature: Browser slot operation

  Scenario: slot2 で example.com の詳細リンクを開く
    Given devcontainer から slot2 の host Chrome に接続できる
    And "https://example.com" を開いている
    When "text=More information..." をクリックする
    Then URL が "https://www.iana.org/help/example-domains" に変わる
```

## チェックポイント

- selector は `text=` や `role=` など再現性が高いものを優先する
- URL は最終到達先まで明記する
- 保存物がある場合は出力 path を `Then` に含める
- host と devcontainer で手順差分があるなら `Given` に書き分ける
