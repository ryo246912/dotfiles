---
description: plan/ に仕様と実装計画だけを整理する command。実装はしない。
---
`plan` フェーズとして扱ってください。

- `plan/` がなければ作成する
- 仕様の正本を `plan/00-spec.md` に整理する
- ユーザーから受け取ったファイルベースの指示や制約を `plan/99-instrucemt.md` に記録する
- 実装計画だけを `plan/01-plan.md` または `plan/01-plan-<slug>.md` に書く
- 調査が必要なら `plan/00-search.md` に TODO を残す

禁止事項:

- コード実装
- apply_patch による本体変更
- コミット、push、PR 作成

最後に、更新した plan artifact と未解決事項だけを簡潔に報告してください。
