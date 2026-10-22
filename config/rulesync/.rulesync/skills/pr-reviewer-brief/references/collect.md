# 段階 1: 情報を集め、差分を振り分ける

pr-reviewer-brief skill の段階 1。軽いモデル（Haiku）で行う前提で、**考えるより集める**ことに徹する。前提の説明や
意図の文章は段階 2 が書くので、ここでは書かない。

入力: `<この skill のディレクトリ>`（以下 `<skill>`）と `<作業ディレクトリ>`（以下 `<work>`）。`<work>/target.json` に
対象（`get_stack.py` の出力）がある。

出力（すべて `<work>` に置く）:

| ファイル          | 中身                                                                       |
| ----------------- | -------------------------------------------------------------------------- |
| `pr-<N>.json`     | 各 PR の `gh pr view` の結果                                               |
| `diff.patch`      | 全体の差分（stack なら、一番下の未 merge の PR の base から一番上の head） |
| `hunks.json`      | `split_hunks.py` の出力                                                    |
| `hunks-index.txt` | hunk の一覧（1 hunk 1 行）                                                 |
| `groups.json`     | 変更グループの下書き（id・title・kind・hunks・prs だけ）                   |
| `notes.md`        | 段階 2 への引き継ぎメモ（下の書式）                                        |
| `shas.json`       | 根拠リンク用の SHA（`{"base_sha": "...", "head_sha": "..."}`）             |
| `ticket.json`     | 関連するチケットの内容（見つかったときだけ。`references/ticket.md`）       |

## 1. PR の情報を取る

前に作った資料のスクリーンショットが残らないよう、先に `rm -rf <work>/screenshots` で消す（撮るのは段階 3）。
変更ファイルの数は `changedFiles` を使う（`files` は 100 件までしか返らない）。

`target.json` の `prs` の各 PR について:

```bash
gh pr view <N> --json number,title,url,state,isDraft,author,body,baseRefName,headRefName,headRefOid,files,changedFiles,additions,deletions,labels,comments,reviews,closingIssuesReferences > <work>/pr-<N>.json
```

## 2. 差分を取り、hunk に分ける

カレントディレクトリが対象リポジトリなら手元で取る。`<diff_base>` と `<top_pr>` は `target.json` にある。

```bash
git fetch origin <diff_base>
git fetch origin pull/<top_pr>/head   # 別々に取る（まとめて取ると FETCH_HEAD の 1 行目が base 側になる）
git rev-parse FETCH_HEAD              # target.json の top_head_sha と一致すること
git diff origin/<diff_base>...FETCH_HEAD > <work>/diff.patch
python3 <skill>/scripts/split_hunks.py <work>/diff.patch --out <work>/hunks.json --index > <work>/hunks-index.txt
```

根拠のリンクがずれないよう、変更前の SHA（merge base）と head の SHA を固定して記録する。

```bash
printf '{"base_sha": "%s", "head_sha": "%s"}\n' "$(git merge-base origin/<diff_base> FETCH_HEAD)" "$(git rev-parse FETCH_HEAD)" > <work>/shas.json
```

`FETCH_HEAD` が `top_head_sha` と違えば、段階 0 のあとに PR が更新されている。`get_stack.py` を同じ引数で実行し直して
`target.json` を上書きしてから、この手順をやり直す（資料の対象 SHA と解説する差分をそろえるため）。

手元に無ければ、単体の PR は `gh pr diff <N> > <work>/diff.patch`、stack は
`gh api repos/<owner>/<repo>/compare/<diff_base>...<top_head_sha> -H "Accept: application/vnd.github.diff"` を使う。
`shas.json` の `base_sha` は `gh api repos/<owner>/<repo>/compare/<diff_base>...<top_head_sha> --jq .merge_base_commit.sha`、
`head_sha` は `top_head_sha` にする。

## 3. 変更グループの下書きを作る

`hunks-index.txt` を見て、hunk を**同じ意図で一緒に読むと分かる変更**のまとまりに振り分け、`<work>/groups.json` に書く。
書式は `<skill>/scripts/render_groups.py` の冒頭。この段階では `id`・`title`・`kind`・`hunks`（stack なら `prs` も）だけを書く。

- ファイル単位ではない。1 つのファイルの hunk が複数のグループに分かれてよい。迷ったら、変更行の中身を `diff.patch` で見る
- `title` は何をする変更かが分かる短い名前（「URL 生成の共通化」など）
- **読む順に並べる**: 土台（共通処理・型・スキーマ）→ それを使う側 → 周辺 → テスト・ドキュメント
- lockfile・生成物・スナップショットは `kind: "generated"` の 1 グループにまとめ、**最後に置く**（並び順がそのまま
  資料のグループ番号になるため）
- stack なら `prs` に、そのグループの hunk がどの PR の変更か（各 `pr-<N>.json` の `files` と突き合わせる）を入れる
- 書いたら検査し、エラーが無くなるまで直す

  ```bash
  python3 <skill>/scripts/render_groups.py --hunks <work>/hunks.json --groups <work>/groups.json --check draft
  ```

## 4. 関連するチケットを取る

前に作った資料のチケットが残らないよう、先に `rm -rf <work>/ticket.json <work>/ticket-images` で消す。そのうえで `<skill>/references/ticket.md` に従い、
PR に紐づくチケット（Linear・Notion・Jira・GitHub Issue など）を探す。見つかって中身が取れれば `ticket.json` に書く。
見つからなければ何もしない。

## 5. 引き継ぎメモを書く

`<work>/notes.md` に、段階 2 がコードを読む場所を絞れるよう、事実だけを箇条書きで書く。推測は「推測」と書く。

```markdown
# 目的・背景

- PR 本文・関連 issue・チケットに書かれた目的、受け入れ条件（引用は短く）

# 議論になっている点

- レビューコメントで出ている論点（誰が・何を）

# 変更の入口

- 画面・API・ジョブなど、変更が始まる場所と、そのファイル

# 関係する画面

- 変更が関わる画面の名前・URL（ルーティングの定義のファイルと行）・その画面のファイル

# 関係するテーブル

- 関係する画面に出るデータのテーブル・リレーション（モデル・スキーマ定義のファイル）

# 変更前のコードで読むべき場所

- 前提（今の機能）を説明するのに読むべき base 側のファイルと関数（なぜ読むか 1 行）

# スキーマ・API・設定の変更

- migration、API の入出力、設定値、feature flag、権限の変更（無ければ「なし」）

# 動かし方

- アプリの起動コマンド・ポート（README・package.json の scripts・mise の task から）、必要な設定・データ

# 規約

- CLAUDE.md・AGENTS.md・docs のうち、変更箇所に関係するもの（ファイル名と要点）
```

## 終わり方

最後に 1 行だけ返す: `files=<数> hunks=<数> lines=<追加+削除> groups=<数>`。
