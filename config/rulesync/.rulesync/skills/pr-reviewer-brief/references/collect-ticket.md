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

前に作った資料の残りを `rm -rf <work>/ticket.json <work>/ticket-images <work>/screenshots` で消してから、
`<skill>/references/ticket.md` の 2〜4 に従い、`target.json` の `ticket` を取って `ticket.json` を書く。

## 2. 関連する PR を探す

チケットに PR へのリンクがあれば、それを使う。そのうえで種類ごとに探し、見つかった PR をまとめる（同じ PR は 1 つにする）。

- **GitHub Issue**: issue に紐づいた PR を使う（番号での全文検索は無関係な PR にも当たるので使わない）

  ```bash
  gh api graphql -F owner=<owner> -F repo=<repo> -F number=<番号> -f query='
    query($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        issue(number: $number) {
          closedByPullRequestsReferences(first: 50, includeClosedPrs: true) { nodes { number url state } }
        }
      }
    }' --jq '.data.repository.issue.closedByPullRequestsReferences.nodes[]
             | select(.url | startswith("https://github.com/<今のリポジトリの owner/repo>/pull/"))'
  ```

  `includeClosedPrs: true` で merged・closed の PR も含める（`gh issue view --json closedByPullRequestsReferences` は含めない）

  後の手順は PR 番号を今のリポジトリで引くので、今のリポジトリ（`gh repo view --json nameWithOwner --jq .nameWithOwner`）の
  PR だけを使う。別のリポジトリの PR しか無ければ、PR なしとして進める

- **それ以外（`ABC-123` など）**: タイトル・本文に ID を含む PR と、head ブランチ名に ID を含む PR を探す

  ```bash
  gh pr list --state all --search "<チケットの ID>" --json number,title,url,state,headRefName --limit 20
  gh pr list --state all --json number,title,url,state,headRefName --limit 200 \
    --jq '.[] | select(.headRefName | ascii_downcase | contains("<チケットの ID を小文字にしたもの>"))'
  ```

- 見つかったら、open な PR のうち一番新しいもの（open が無ければ merged のうち一番新しいもの）について `get_stack.py --pr <N>` を実行し、出力に
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
