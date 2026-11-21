---
name: pr-reviewer-all-review
description: pr-reviewer-comment の統合レビューを呼び出し、crit、解説資料、実環境での動作確認を選べる。「レビュアーとして全観点でレビュー」「専門レビューも含めてレビュー」など、統合レビューを明示されたときに使う。
targets:
  - claudecode
  - codexcli
---

# PR レビュアー向けの統合レビュー

使い方は Claude Code では `/pr-reviewer-all-review`、Codex では `$pr-reviewer-all-review`。PR の URL または番号を渡す。

| 引数                                  | 意味                                                |
| ------------------------------------- | --------------------------------------------------- |
| `-h` / `--help`                       | ヘルプを表示して終了                                |
| `--crit`                              | pr-reviewer-comment-crit の UI で候補を確認する     |
| `--brief`                             | pr-reviewer-brief で解説資料だけを作る              |
| `--behavior`                          | pr-reviewer-behavior で起動済み環境の動作も確認する |
| `--submit [APPROVE\|REQUEST_CHANGES]` | 選んだ指摘と確認済みの本文で公開する                |

ヘルプは最優先。PR を取得せずに終了する。不明な引数や PR 指定の欠落があれば使い方を表示する。

通常は pr-reviewer-comment、`--crit` 指定時は pr-reviewer-comment-crit の本文を読み、その手順で PR をレビューする。
PR の URL または番号と、指定された場合は `--submit` の意図と種別を引き継ぐ。統合スキル固有のオプションはここで解釈する。

- `--brief` があれば PR の取得後に pr-reviewer-brief を「説明だけ・動作確認不要」で実行する。資料が stack 全体を説明する場合も、レビュー指摘は指定 PR の差分を基準にする。
- `--behavior` があれば候補提示前に pr-reviewer-behavior を一度だけ実行し、環境と SHA を記録する。別の PR に起因する現象は対象 PR の指摘に含めない。前提が揃わない場合は未確認の理由と手動確認手順を残す。得られた指摘も共通手順で裏を取る。
