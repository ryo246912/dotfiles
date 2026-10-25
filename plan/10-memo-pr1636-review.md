# PR #1636 レビューのメモ

## 目次

- [指摘一覧](#指摘一覧)

## 指摘一覧

重い順。「再現済み」は手元で再現を確認したもの。

| #   | 場所                                 | 問題                                                                                                                                                 | 修正案                                                                                                                   |
| --- | ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| 1   | `apply_plan.py:301`                  | 会社リポジトリ由来の根拠で `global` の教訓を作成・追記できる（`check_plan` は widen しか制限していない）                                             | create/attach でも `scope_key` が根拠のリポジトリの範囲を超えないか検査する。`consolidate.md` の「同じかその上位」も絞る |
| 2   | `apply_plan.py:305`                  | widen が既存の教訓を確認せずに上書きする。target が sources に含まれると直後に retired になる。lessons が空だと `srcs[0]` で IndexError              | 既存の target には fold で合流させる。target ∈ sources と空の lessons を検査で弾く                                       |
| 3   | `lessonlib.py:85`                    | `_strip_comment`・`_inline_list` が `\"` を考慮せず、`"` と ` #` を含む値が切れ、毎週その形で書き戻される（再現済み）                                | エスケープを考慮して走査する                                                                                             |
| 4   | `lessons-record/SKILL.md:42`         | `evidence: session: <date> ...` が引用符なしで YAML として不正。Basic Memory が読めず注入されない（再現済み）                                        | テンプレートで値を引用符で囲む                                                                                           |
| 5   | `collect.py:177`                     | author が null（ghost）で TypeError、週次全体が毎週止まる                                                                                            | `(author or {}).get("login")` 相当で ghost を扱う                                                                        |
| 6   | `lessons-harvest/SKILL.md:111`       | 観察 0 件のとき `git commit -qam` が初回の未追跡 `harvest-state.yml` を拾わない。`--state-only` を `--work` なしで呼ぶと TypeError                   | `git add` してから commit。`--state-only` で `--work` を不要にするか必須にする                                           |
| 7   | `collect.py:46`                      | REJECT の `intended` が "unintended" 等に当たる。`rejected()` が採用の有無を見ない。`merged:{since}..{until}` が両端を含み境界日の PR を二重に数える | 単語境界と否定を考慮。期間を半開区間にする                                                                               |
| 8   | `apply_plan.py:345`                  | widen・90 日の retire がパスを動かすのに `escalation.relink` を呼ばない                                                                              | `review.py` と同様に relink する                                                                                         |
| 9   | `local/bin/agent-lessons-context:63` | `timeout 30` の検索を 2 回直列に行い、最大 60 秒で SessionStart hook の 40 秒を超える                                                                | 検索を 1 回にまとめて結果を分ける                                                                                        |
| 10  | `lessonlib.py:197`                   | `glob_regex` が `{a,b}` を展開せず `**/*.{ts,tsx}` が当たらない（再現済み）                                                                          | ブレース展開に対応する                                                                                                   |
