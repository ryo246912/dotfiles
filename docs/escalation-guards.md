# escalation から導入した検査

リポジトリの checkout ルートで実行する。Python 3.11 以上と、mise.toml に固定した
lefthook が必要。CI は Python と lefthook を明示的に導入してから検証する。

```bash
mise run lint:contracts
mise run test:contracts
```

`lint:contracts` は `lint:all` と pre-push、CI から呼ぶ。検査するのは次の契約。

- project/global の oxlint の pin と devcontainer 用 schema URL の一致。
- project/global の各スコープ内で、task 定義・依存先の存在、循環依存、
  `depends` と `run` の内部 task の重複起動。mise が重複排除する共有 `depends` は許容する。

`test:contracts` は違反例と正常例を検証し、実際の `lefthook dump` を使って
post-checkout が hook 再登録だけを行うこと、設定ファイルが無い場合は再登録しないことも検査する。
post-merge の更新・再適用は維持する。checkout 後の設定反映は手動で行う（`docs/mise.md`）。

ファイルの書込対象の推論、任意の schema の意味的互換性、シェル内から起動する task の解析は行わない。
これらを検査済みとは扱わない。task 引数付きの配列形式の依存を追加する際は、検査側も対応させる。

文書・コメント・CLI の意味、前提と反映手順、fallback、agent 差は
`.rulesync/rules/CLAUDE.md` と `.coderabbit.yaml` にレビュー規則を置く。
ソースから `rulesync generate` で AGENTS.md と CLAUDE.md を再生成する。
ルールは次のセッションから参照され、CodeRabbit の規則は PR レビュー時に使われる。
ホスト側の dotfiles 反映は `mise bootstrap dotfiles diff` を確認してから
`mise bootstrap dotfiles apply` を行う。

agent-lessons の `ruled` 化には、各 Patterns 全件の違反・修正 fixture による実証が必要。
この変更だけで教訓全体を検査できたとは扱わず、チェックリストの印と status は変更しない。
