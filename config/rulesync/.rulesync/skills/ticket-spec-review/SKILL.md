---
name: ticket-spec-review
description: Notion・Jira などのタスクチケット、Slack のリンク、直接入力された要望を起点に、想定する振る舞い、適用範囲、横展開の漏れ、例外、受け入れ条件を pr-spec-review と共通の観点でレビューする。
targets:
  - claudecode
  - codexcli
---

# チケット・要望の仕様レビュー

チケット URL・識別子、Slack リンク、貼り付けた本文、直接の要望を受け取る。単独実行では [チケット・要望の取得](../pr-spec-review/references/ticket-intake.md) に従う。`ticket-all-review` からは取得済みの資料を受け取る。

観点、調査、指摘の書式は [pr-spec-review のチケット・要望レビュー手順](../pr-spec-review/SKILL.md#チケット要望を起点に調べるとき) を正本とする。その節を読み、指定された手順とチェックリストを実行して報告する。集約元がある場合は、結果、根拠、未確認事項を集約元に返す。
