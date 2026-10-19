# 段階 1（チケットモード）: チケットと関連する PR を集める

pr-reviewer-brief skill のチケットモードの段階 1。PR ではなくチケットの ID か URL を渡されたときに使う。軽いモデル（Haiku）で
行う前提で、**考えるより集める**ことに徹する。

入力: `<skill>`・`<work>`、`<work>/target.json`（`{"mode": "ticket", "ticket": "<ID か URL>"}`）。

出力（すべて `<work>` に置く）:

| ファイル      | 中身                                                                              |
| ------------- | --------------------------------------------------------------------------------- |
| `ticket.json` | チケットの内容（`references/ticket.md` の手順）                                   |
| `target.json` | 関連する PR が見つかれば、`get_stack.py` の出力に `mode`・`ticket` を足して上書き |
| `pr-<N>.json` | 関連する各 PR の `gh pr view` の結果                                              |
| `notes.md`    | 段階 2 への引き継ぎメモ（`collect.md` の 5 と同じ書式）                           |
| `shas.json`   | 根拠リンク用の SHA                                                                |

## 1. チケットを取る

`<skill>/references/ticket.md` の 2・3 に従い、`target.json` の `ticket` を取って `ticket.json` を書く。

## 2. 関連する PR を探す

チケットの ID で PR を探す（タイトル・本文・ブランチ名に ID を含むもの）。チケットに PR へのリンクがあれば、それも使う。

```bash
gh pr list --state all --search "<チケットの ID>" --json number,title,url,state,headRefName --limit 20
```

- 見つかったら、open な PR のうち一番新しいものについて `get_stack.py --pr <N>` を実行し、出力に
  `"mode": "ticket"` と `"ticket": "<ID>"` を足して `target.json` を上書きする（stack ならスタック構成が出る）
- 各 PR について `collect.md` の 1 と同じく `pr-<N>.json` を取る
- 差分は hunk に分けない（チケットモードでは変更グループを出さない）。`gh pr diff <N> --name-only` で変更ファイルの一覧だけ見て、
  `notes.md` の「変更の入口」に使う
- 見つからなければ PR なしで進める（変更内容はチケットに書かれた「これから変えること」になる）

## 3. 引き継ぎメモと SHA を書く

- `notes.md` は `collect.md` の 5 と同じ書式で書く。「目的・背景」にはチケットから分かることを、「変更前のコードで読むべき場所」には
  チケットに出てくる画面・機能に当たるコードの場所を書く
- `shas.json` には、今の default branch の SHA を `base_sha` に入れる（前提知識の根拠リンクに使う）

  ```bash
  default=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
  git fetch origin "$default"
  printf '{"base_sha": "%s"}\n' "$(git rev-parse "origin/$default")" > <work>/shas.json
  ```

## 終わり方

最後に 1 行だけ返す: `ticket=<取れたか fetched の値> prs=<関連する PR の数>`。
