---
root: true
targets:
  - codexcli
globs:
  - "**/*"
---

- 必ず日本語で回答してください。
- 実装や設定変更を行ったあとは、最終報告前に CodeRabbit で未コミット差分をレビューしてください。
  - まず `coderabbit` skill を使って review loop を開始してください。
  - skill が使えない場合は `coderabbit review --prompt-only --type uncommitted` をバックグラウンド実行し、完了まで定期確認してください。
  - 重大度の高い指摘を優先して修正し、軽微な nit は根拠が弱ければ見送って構いません。再レビューは最大 1 回までです（合計 2 パスまで）。
  - 既存 PR のレビューコメント対応は `review-fix` に分離し、このフローでは扱わないでください。
