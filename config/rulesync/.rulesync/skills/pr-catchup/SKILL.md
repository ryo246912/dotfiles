---
name: pr-catchup
description: >-
  GitHub PR の URL か番号を受け取り、コードベースに詳しくないレビュアーでも短時間で内容をつかめる HTML の
  キャッチアップ資料を作る skill。前提となる機能・データモデル・用語、変更前後の振る舞い、読む順番、画面での
  動作確認手順をまとめ、オプションで Playwright で Preview 環境のスクリーンショットを撮って手順に貼る。
  stack PR（分割した PR の連なり）は 1 つの PR とみなして全体を説明し、各 PR は短くまとめる。
  「この PR の解説を作って」「PR の前提から分かるようにまとめて」「stack 全体を把握したい」など、レビュー前に
  内容をつかみたいときに使う。指摘の洗い出しや draft レビューの投稿は pr-reviewer-comment を使う。
targets:
  - claudecode
  - codexcli
---

# pr-catchup — PR のキャッチアップ資料を HTML で作る

レビューに入る前に、**その PR が何を変え、なぜ変え、どう確かめるか**を、コードベースを知らない人にも分かる形で
1 枚の HTML にまとめる。この skill は**説明に徹する**。良し悪しの指摘はしない（気づいた懸念は「重点的に見る箇所」に
事実として書くだけ）。GitHub への投稿・ラベル変更・push もしない。

全体の流れ:

1. 引数を読み、対象の PR（と stack）を確定する
2. PR の情報と差分を集める
3. 前提知識（今の機能・データモデル・用語）を調べる
4. 変更内容を整理する
5. 動作確認手順を書く（オプション: スクリーンショットを撮る）
6. HTML を書き出し、場所を伝える

## 引数

`/pr-catchup <PR の URL か番号> [オプション]`

| オプション               | 意味                                                                                  |
| ------------------------ | ------------------------------------------------------------------------------------- |
| `--screenshots`          | Preview 環境で動作確認手順のスクリーンショットを撮り、手順に貼る（5 を参照）          |
| `--preview-url <url>`    | Preview 環境の URL。省略時は PR のコメント・deployment から探す                       |
| `--storage-state <file>` | ログイン済みの Playwright storage state（`playwright codegen --save-storage` で作る） |
| `--no-stack`             | stack を辿らず、指定した PR だけを対象にする                                          |
| `--single-file`          | スクリーンショットを HTML に埋め込み、1 ファイルで共有できるようにする                |
| `--auto`                 | 非対話モード。ユーザーに質問せず最後まで進める（定期実行用。下の「非対話モード」）    |
| `--out <dir>`            | 出力先ディレクトリ（既定は 6 を参照）                                                 |

番号だけなら、カレントディレクトリのリポジトリ（`gh repo view --json nameWithOwner`）の PR とみなす。
ユーザーが自然文で「スクショも撮って」などと言った場合も、対応するオプションが指定されたものとして扱う。

## 1. 対象の PR と stack を確定する

`--no-stack` が無ければ、まず stack かどうかを調べる。

```bash
python3 <この skill のディレクトリ>/scripts/find_stack.py --pr <N> [--repo owner/name]
```

base / head ブランチの連なり（PR の base が別の PR の head になっている）を上下に辿り、下（default branch 側）から
上への順で JSON を返す。`prs` が 2 件以上なら stack として扱う。

- `warnings` に分岐（1 つの PR の上に複数の PR が乗っている）があれば、`--auto` でなければユーザーにどの枝を
  対象にするか聞く。`--auto` なら指定した PR を含む枝だけを対象にし、残りは「未確認事項」に書く
- merge 済みの PR は stack の一部として表に載せるが、差分は base に入っているので全体の差分には含めない
- Graphite などの stack ツールが PR 本文に stack の一覧を書いていれば、それと突き合わせる。食い違えば本文の一覧を
  優先し、食い違ったことを「未確認事項」に書く

**stack の扱い方**: stack 全体を 1 つの PR とみなして読む。資料の主役は stack 全体の説明で、各 PR は
「スタック構成」の表で 1〜2 行にまとめるだけにする。ユーザーが指定した PR は表で強調する。

## 2. PR の情報と差分を集める

各 PR について:

```bash
gh pr view <N> --json number,title,url,state,author,body,baseRefName,headRefName,headRefOid,files,additions,deletions,labels,comments,reviews,closingIssuesReferences
gh pr checks <N>
```

差分は、単体の PR なら `gh pr diff <N>`。stack なら、一番下の PR の base から一番上の PR の head までを 1 つの差分として見る。
カレントディレクトリが対象リポジトリなら手元で取る（ファイルも読めるので、こちらを優先する）。

```bash
git fetch origin <stack_base> pull/<一番上の PR>/head
git diff --stat origin/<stack_base>...FETCH_HEAD
git diff origin/<stack_base>...FETCH_HEAD -- <path>
```

手元に無ければ `gh api repos/<owner>/<repo>/compare/<stack_base>...<一番上の headRefOid>` を使う。

- **head の SHA** を控える（stack なら一番上の PR の SHA）。ファイルへのリンクと行番号はすべてこの SHA で書く
- PR 本文・関連 issue（`closingIssuesReferences`）・関連チケットから、目的・背景・受け入れ条件を拾う
- 既存のレビューコメントで議論になっている点があれば、「重点的に見る箇所」の材料にする
- リポジトリの `CLAUDE.md`・`AGENTS.md`・`README`・`docs/`・ADR のうち、変更箇所に関係する部分だけを読む

## 3. 前提知識を調べる

この章が、コードベースを知らない人向けの資料の中心になる。**base 側（変更前）のコード**を読み、次を調べる。

- **今の機能**: 変更が関わる機能が、今どの画面で、ユーザーの何の操作で、内部のどこを通って動いているか。
  画面名・ボタン名は i18n の文言などコード上の表示名で書く
- **データモデル**: 関わるテーブル・型・API のスキーマ。カラムや項目は、この PR の理解に要るものだけに絞る
- **用語集**: ドメイン用語と、コード上の名前（クラス名・テーブル名など）の対応

書き方の決まり:

- 「今はこう動く」という説明には、根拠のファイルと行（base 側）を必ず添える。根拠が無い説明は書かない。
  推測で補うなら「推測」と明記する
- データモデルの図（mermaid の `erDiagram`）は、スキーマが変わる PR か、テーブル間の関係が分からないと変更を
  読めない PR のときだけ描く。スキーマが変わるなら変更前と変更後を並べ、増えた・変わった項目を本文で示す

## 4. 変更内容を整理する

ファイル単位ではなく、**振る舞いの単位**で整理する。

- **TL;DR**: 3 行以内。誰の・何の課題を・どう変えるか
- **変更前と変更後**: ユーザーから見える振る舞い・内部の振る舞いを比較表にする
- **主な変更点**: 変更をテーマごとにまとめ、それぞれ「何を・なぜ・どのファイルで」を書く
- **スキーマ・API・設定の差分**: migration、API の入出力、設定値、feature flag、権限。無ければ「なし」と書く
- **読む順番**: entry point → 中心のロジック → 周辺 → テストの順に、ファイルと役割を並べる。各ファイルは head の SHA の
  GitHub のリンクにする。生成物・lockfile・スナップショットは「読まなくてよいファイル」にまとめる
- **重点的に見る箇所**: 互換性、データ移行、境界条件、権限、PR 本文に書かれていない副作用など、レビュアーが
  時間をかけるべき場所。評価はせず、なぜ見るべきかを事実で書く
- **未確認事項**: 調べきれなかったこと、`--auto` で置いた仮定

### シーケンス図は原則描かない

シーケンス図は、**本文だけでは順序や関係が追えない難しいやりとり**があるときだけ描く。目安:

- 3 者以上（画面・API・ジョブ・外部サービスなど）が絡み、呼ぶ順番が結果を左右する
- 非同期処理・リトライ・コールバック・状態遷移があり、どこで何が起きるかが分かりにくい

画面 → API → DB の素直な一往復なら描かない。描くときも、難しい部分だけに絞り、変わった箇所を `Note` などで示す。

## 5. 動作確認手順を書く

ユーザーがそのまま手を動かせる粒度で、**URL と操作を 1 つずつ**書き下す。

- **環境**: どこで確かめるかと、その理由。FE だけの変更なら Preview、BE を含み API の Preview が無ければローカル
  （起動コマンド、PR の head への切り替え、ポート、必要な設定）。stack なら一番上の PR の環境で確かめる
- **前提**: feature flag、権限・ロール、必要なデータ、アカウント
- **不具合修正なら**、修正前の環境で不具合を再現する手順を先に置く
- **各手順**: 開く URL → 操作（押すボタンの表示名、入力値）→ 期待結果（画面の表示、メッセージの文言、Network タブで
  見る API とステータス）。ボタンが押せる条件（例: 変更が無いと保存が無効）もコードで確かめて書く
- **破壊的な操作**（削除など）には、テスト用のデータで行うよう注意を添える
- 1 つの手順は 1 つの確認に対応させ、手順ごとに `id`（`step-1` など）を振る。スクリーンショットとの対応に使う

### オプション: スクリーンショットを撮る（`--screenshots`）

1. **Preview の URL を決める**。`--preview-url` が無ければ、PR のコメント（Vercel などの bot）と
   `gh api repos/<owner>/<repo>/deployments?sha=<head SHA>` → 各 deployment の statuses の `environment_url` から探す。
   見つからなければ、`--auto` でなければユーザーに聞き、`--auto` なら撮らずに「未確認事項」に書く
2. **撮影計画の JSON を書く**。動作確認手順の各手順を、URL と操作に落とす。書式は `scripts/screenshot.py` の冒頭を参照

   ```json
   {
     "base_url": "https://pr-123.preview.example.com",
     "shots": [
       {
         "id": "step-1",
         "url": "/settings/profile",
         "actions": [
           { "type": "click", "selector": "role=button[name='編集']" },
           { "type": "wait_for", "selector": "text=プロフィールを編集" }
         ],
         "capture": { "selector": "main" },
         "mask": ["[data-testid='email']"]
       }
     ]
   }
   ```

3. **撮る**

   ```bash
   uv run <この skill のディレクトリ>/scripts/screenshot.py --plan <plan.json> --out-dir <出力先>/screenshots \
     [--storage-state <file>]
   ```

   結果は `<出力先>/screenshots/manifest.json` に、手順ごとの画像のパスと成否が出る。失敗した手順は、エラーを
   手順の下に書いて画像なしで載せる（撮り直しは 1 回まで）

撮影のときに守ること:

- **データを変える操作はしない**。保存・削除・送信など、Preview のデータを書き換えるボタンは押さず、押す直前の
  画面を撮る。ユーザーが明示的に許したときだけ押してよい
- 個人情報・トークンが映る要素は `mask` で隠す
- ログインが要る環境で `--storage-state` が無ければ、ログイン画面を撮らずに止め、作り方
  （`uvx playwright codegen --save-storage=auth.json <url>`）を伝える

## 6. HTML を書き出す

`assets/template.html` をコピーし、各 section を埋める。テンプレートのコメントに、各 section で書くことがある。
書くことが無い section（stack でない PR の「スタック構成」、図が要らないときの図など）は丸ごと消す。

- **出力先**: `--out` が無ければ `${PR_CATCHUP_DIR:-$HOME/.cache/pr-catchup}/<owner>__<repo>/<名前>/index.html`。
  `<名前>` は単体の PR なら `pr-<N>`、stack なら `stack-<一番下の N>-<一番上の N>`
- `<meta name="pr-catchup-head">` に head の SHA（stack なら一番上の PR の SHA）を入れる。定期実行で作り直しの要否を判断するのに使う
- 図は mermaid で書く（テンプレートが読み込む）。ER 図・シーケンス図以外の図は基本的に使わない
- `--single-file` なら、書き出したあとに画像を埋め込む

  ```bash
  python3 <この skill のディレクトリ>/scripts/embed_images.py <出力先>/index.html
  ```

書き出したら、ファイルのパスを伝え、ターミナルにも TL;DR と（stack なら）スタック構成の表を出す。
Claude Code で Artifact として公開できる環境なら、ユーザーに確認したうえで公開してよい。

## 非対話モード（`--auto`）

将来、立ち上がった PR に対して定期実行（cron など）で資料を作るためのモード。

- ユーザーに質問しない。決められないことは仮定を置いて進め、仮定を「未確認事項」に書く
- 出力先に同じ PR の `index.html` があり、`pr-catchup-head` が今の head の SHA と同じなら、何もせず終了する
- `--screenshots` が付いていても、Preview の URL やログイン情報が自動で得られなければ撮らない
- 終わったら、出力したファイルのパスを 1 行だけ出す

## してはいけないこと

- GitHub へ投稿しない（コメント・レビュー・ラベル・状態の変更を含む）。他人のブランチへ commit / push しない
- コードを編集しない（調べるための読み取り・テスト実行は可）
- 根拠のない「今はこう動く」を書かない
- スクリーンショットのために Preview のデータを書き換えない
