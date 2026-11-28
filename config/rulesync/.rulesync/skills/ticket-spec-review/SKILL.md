---
name: ticket-spec-review
description: Notion・Jira などのタスクチケット、Slack のリンク、直接入力された要望を起点に、想定する振る舞い、適用範囲、横展開の漏れ、例外、受け入れ条件を pr-spec-review と共通の観点でレビューする。
targets:
  - claudecode
  - codexcli
---

# チケット・要望の仕様レビュー

チケット URL・識別子、Slack リンク、貼り付けた本文、直接の要望を受け取る。単独実行では [チケット・要望の取得](../pr-spec-review/references/ticket-intake.md) に従う。`ticket-all-review` からは取得済みの資料を受け取る。

[共通の仕様レビュー手順](../pr-spec-review/references/spec-review.md) を使う。明示された関連 PR があれば差分と統合後の状態を根拠にする。関連 PR がなく対象リポジトリを確認できる場合は、既定ブランチの SHA で現状を調べ、対応案と現状を区別する。実装状況を確認できない案は未確認とする。

結論、確認した事実、候補表、未確認事項を返す。候補表に対象の要求・画面・処理と区分を載せ、理由、推奨対応と根拠を添える。統合レビューから呼ばれた場合は結果を親へ返す。チケットや関連 PR への投稿・編集は別の依頼として扱う。
