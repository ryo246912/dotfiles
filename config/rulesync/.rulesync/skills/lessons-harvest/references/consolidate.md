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

`create` の `title` は命令形の 1 文にする（そのまま SessionStart で注入される）。

次の場合だけ `widen` を書く。

- 同じ owner の異なる 2 リポジトリ以上に同じ教訓があるとき、owner（`<host>/<owner>`）へまとめる
- 個人のリポジトリ（`~/.config/agent-lessons/targets.yml`）だけを根拠に、異なる 2 owner 以上に同じ教訓があるとき、global へまとめる。
  会社など `targets.*.yml` のリポジトリが根拠に入るものは global にしない。広げる価値がありそうなら、社名・サービス名・
  リポジトリ名を取り除いた文面案を `review` に書く

リポジトリの領域に固有の教訓（地図の座標の扱いなど）は、似た教訓が別のリポジトリにあっても `widen` しない。

件数・昇格・失効はスクリプトが決めるので、plan.json には書かない。

## 3. 当てる

```bash
python3 <skill>/scripts/apply_plan.py --work <work>
```

検査で止まったら（未割り当て・二重の割り当てなど）、plan.json を直して再実行する。成功すると教訓が更新され、
`<work>/pr-body.md` と `harvest-state.yml` が書かれる。

## 終わり方

スクリプトが最後に出した 1 行（JSON）をそのまま返す。
