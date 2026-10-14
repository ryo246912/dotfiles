---
name: review-pr
description: >-
  GitHub PR の URL か番号を受け取り、他人の PR をレビューする skill。実画面での動作確認手順（URL と操作を 1 つずつ）、
  must/should/imo/nit/Q で区分したレビュー指摘候補の表と根拠コード、ユーザーとの壁打ちを経て、選んだ指摘だけを
  未 submit の draft レビューとして投稿し、submit 用の本文例まで出す。「PR をレビューして」「#1234 見て」
  「このPRのレビューコメント作って」「動作確認手順も出して」など、PR のレビューを始めたいときは明示的にスキル名が
  無くても使う。自分の PR に付いた指摘への対応には使わない。
---

# review-pr — PR レビューの開始から draft 投稿まで

レビュアーとして他人の PR を読み、**指摘候補を出す → ユーザーが選ぶ → draft を投稿する**までを進める。
submit（Approve / Comment / Request changes）はユーザーが自分で行う。指摘の取捨と最終的な文面の責任はユーザーにあり、このスキルは判断材料をそろえて下書きを作る役に徹する。

全体の流れ:

1. PR の情報を集める
2. コードを読み、指摘候補を洗い出して裏を取る
3. 動作確認手順を書く
4. 指摘候補の表と詳細を出す
5. **止まって**ユーザーと壁打ちし、投稿する No を決めてもらう
6. 選ばれた No を draft レビューとして投稿し、submit 用の本文例を出す

各手順の詳細は `references/` にある。crit-pr skill と共通なので、手順に入るときに該当ファイルを読む。

| 手順 | 読むファイル                 |
| ---- | ---------------------------- |
| 1    | `references/pr-info.md`      |
| 2, 4 | `references/findings.md`     |
| 3    | `references/manual-test.md`  |
| 6    | `references/draft-review.md` |

## 1. PR の情報を集める

`references/pr-info.md` に従う。

## 2. 指摘候補を洗い出し、裏を取る

`references/findings.md` に従う。

## 3. 動作確認手順を書く

`references/manual-test.md` に従う。

## 4. 指摘候補を出す

`references/findings.md` の「出し方」に従い、表と No ごとの詳細を出す。

## 5. 止まって、ユーザーに確認する

表と詳細を出したら、**ここで止める**。投稿する No を選んでもらうまで、何も投稿しない。

- 「どの No を投稿しますか？ 区分や文面の相談もどうぞ」と聞く
- 壁打ちで指摘が誤りと分かったら、表から外したことを明言する
- 区分や本 PR との関係を変えたら、表を出し直す

## 6. draft レビューを投稿し、submit 用の本文例を出す

`references/draft-review.md` に従う。

## してはいけないこと

- レビューを submit しない（`event` を付けた投稿、`submit_pending` の実行を含む）
- 他人のブランチへの commit / push、他人のスレッドへの返信、ラベルや状態の変更をしない
- 裏を取っていない候補を表に載せない
