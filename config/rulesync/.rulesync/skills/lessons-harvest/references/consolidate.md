# 段階 2: 観察を教訓にまとめる

担当: subagent（sonnet。未処理の観察が少なければ haiku）。`<skill>`・`<work>` は依頼文のとおり。

## 1. 材料を出す

```bash
python3 <skill>/scripts/apply_plan.py --list           # 未処理の観察（rule・category・scope_key・source）
python3 <skill>/scripts/lessons_query.py --index      # 既存の教訓の一覧（title・category・scope_key・status）
```

教訓の本文は、似ているか迷うものだけ読む（`~/.local/share/agent-lessons/<path>`）。全部は読まない。

## 2. plan.json を書く

未処理の観察を 1 件ずつ、次のどれか 1 つに割り当てる。書式は `<skill>/scripts/apply_plan.py` の先頭にある。

| 割り当て | いつ                                                                                                                                                                                                          |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `attach` | 同じ source で、status が `retired` ではなく、scope_key が同じかその上位（owner・global）の教訓に、同じ種類のものがある                                                                                       |
| `create` | 同じ source・scope_key の範囲に同じ種類の教訓が無い。その範囲の似た観察はまとめて 1 つの `create` に入れる。`key` は英語のケバブケース。別のリポジトリにまたがるものは、それぞれ作ってから `widen` でまとめる |
| `skip`   | 次の変更で効かない（その場限りの事情・好みの違い・誤った指摘）。理由を書く。リポジトリ固有なだけなら skip せず、そのリポジトリの `create`・`attach` にする                                                    |

plan.json の文章（`create`・`widen` の `title`・`rule`・`why`・`check`、`review`、`escalate` の案）は、元の
コメントや観察の言語に関わらず日本語で書く（そのまま教訓と `pr-body.md` になる）。コード・識別子・固有名詞は
原文のままでよく、`` ` `` で囲む。

`create` の `title`・`rule` は仕組みの水準の命令形の 1 文にする（title はそのまま SessionStart で注入される）。
形の違いはタイトルに並べない。観察の `pattern` はスクリプトが教訓の `## Patterns` に足すので、同じ仕組みの別の形
（UPDATE の条件漏れとロック漏れなど）は別の教訓を作らず `attach` する。`check` は diff で探すもの（grep する語・
コードの形）にし、「〜を考慮したか」とは書かない。

status が `ruled`（仕組みに移した）の教訓にも `attach` してよい。仕組みを入れた後にまた指摘されたことになるので、
スクリプトが「要確認」に回す。

次の場合だけ `widen` を書く。

- 同じ owner の異なる 2 リポジトリ以上に同じ教訓があるとき、owner（`<host>/<owner>`）へまとめる
- 個人のリポジトリ（`~/.config/agent-lessons/targets.yml`）だけを根拠に、異なる 2 owner 以上に同じ教訓があるとき、global へまとめる。
  会社など `targets.*.yml` のリポジトリが根拠に入るものは global にしない。広げる価値がありそうなら、社名・サービス名・
  リポジトリ名を取り除いた文面案を `review` に書く

リポジトリの領域に固有の教訓（地図の座標の扱いなど）は、似た教訓が別のリポジトリにあっても `widen` しない。

次の active な教訓には `escalate` に仕組み化の案を書く。注入より lint・hook・テスト・ルールファイルで防ぐほうが確実なため。

- 今週 `attach` する教訓で、`--index` の `since_active` が 1 以上（active になった後にまた指摘された）
- diff の形で機械的に見つけられる（`## Patterns` が grep や lint のルールで表せる）

案は具体に書く（どの lint のどのルールか、どの hook で何を grep するか、どんなテストを足すか、CLAUDE.md・AGENTS.md の
どこに何を書くか）。スクリプトは `since_active` が 2 以上の教訓も案なしで足す。足した先は agent-lessons の
`escalation.md`（仕組み化のチェックリスト）で、ユーザーが仕組みを入れて印を付けると ruled になる。

件数・昇格・失効はスクリプトが決めるので、plan.json には書かない。

## 3. 当てる

```bash
python3 <skill>/scripts/apply_plan.py --work <work>
```

検査で止まったら（未割り当て・二重の割り当て・日本語でない文章など）、plan.json を直して再実行する。未処理の
観察そのものが日本語でないと言われたら、観察は直さずに止まった旨を返す（その日の実行をやり直す）。成功すると教訓が更新され、
`<work>/pr-body.md` と `harvest-state.yml` が書かれる。

## 終わり方

スクリプトが最後に出した 1 行（JSON）をそのまま返す。
