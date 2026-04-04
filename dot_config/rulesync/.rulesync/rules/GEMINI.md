---
root: true
targets:
  - geminicli
globs:
  - "**/*"
---

# GEMINI.md

- 必ず日本語で回答してください。
- 実装や設定変更を行ったあとは、最終報告前に `/coderabbit` コマンドまたは `coderabbit review --prompt-only --type uncommitted` で未コミット差分をレビューしてください。
- 重大度の高い指摘を優先して修正し、軽微な nit を追い続けないでください。再レビューは最大 1 回までです（合計 2 パスまで）。
- 既存 PR のレビューコメント対応は `review-fix` 相当の別フローで扱い、この rule では扱いません。
