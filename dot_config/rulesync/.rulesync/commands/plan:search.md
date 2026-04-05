---
targets:
  - claudecode
  - codexcli
description: "plan/00-search.md に調査結果を追記する command。"
---

`plan:search` フェーズとして扱ってください。

- `plan/00-spec.md` と既存の `plan/01-plan*.md` を読んで前提を確認する
- 必要な調査だけを行い、結果を `plan/00-search.md` に追記する
- ユーザーから新しい制約が来た場合は `plan/99-instrucemt.md` も更新する
- 調査結果で計画が変わる場合のみ `plan/01-plan*.md` に差分を反映する

禁止事項:

- コード実装
- 既存コードの変更
- コミット、push、PR 作成

最後に、調査結果の要点と更新した artifact を簡潔に報告してください。
