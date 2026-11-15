# 知見ファイルの保存と参照

知見は `~/.local/share/agent-lessons/behavor/<owner>/<repo>/` に保存し、privateリポジトリ `ryo246912/agent-lessons` でGit管理する（ディレクトリ名は `behavor`）。認証情報・操作権限を含む `config.md` と成果物は従来のローカル保存・Git除外を維持する。

## 初期化・保存・同期

- cloneがなければ `mise run lessons:setup` で初期化する。未初期化・読み取り不可を「知見なし」と解釈せず、読み取り・保存が未実施であることを報告する。対象アプリの調査・手順作成は続ける。
- 読み書き前にcloneの実体ルートを確定する。保存時は `git -C <clone> rev-parse --show-toplevel` の実体がそのルートと一致し、fetch/pushのoriginが `ryo246912/agent-lessons` を指すことを確認する。main以外やrebase/merge中は書き込まず、NOT_RUNと理由を報告する。エージェントがブランチを切り替えない。
- このcloneへのsymlink（sandboxからの共有）は許容するが、behavor自体やowner/repoディレクトリ・知見ファイルのsymlinkは拒否する。保存はこのcloneのbehavor内に限定し、ignoreされている場合は保存を止めて設定を報告する。知見には設定・成果物向けの「未追跡かつGit除外必須」検査を適用しない。
- ローカルで保存・読み直しを確認してSAVEDとする。自動commit・pushは行わず、`mise run lessons:sync` が既存教訓と合わせてsecretlint、commit、pull/rebase、push、Basic Memoryのreindexを行う。競合時は同期失敗として報告し、上書きしない。
- 書き込めない場合は設定隣接lessons/へのフォールバックを作らずNOT_RUNを記録する。設定ファイルの書き込み可否とは独立して判断する。
- 既存のharvest/review/escalation、SessionStartの教訓注入とは別の形式で扱う。frontmatterに `type: lesson` を付けず、動作確認時にこのスクリプトで必要な知見だけ読む。

## ファイル名とfrontmatter

ファイル名は内容を示す短い小文字英数字とハイフンにする。例: `preview-login-per-origin.md`。
日付だけの名前や毎回別の名前にせず、同じ知見は既存ファイルを更新する。
新規保存先のowner/repoディレクトリは小文字にそろえる。一覧は旧表記の大文字・小文字の違いも検索する。既存の同じ知見があれば一覧で返されたパスを更新し、大小文字違いで複製しない。
owner・repo・ファイル名に `/`・`..` 等を含めて階層外へ出さない。上記のGit管理・保存先検査を行い、owner/repoディレクトリにsymlinkを使わず、知見ファイルの実体も対象repoディレクトリ内に限定する。

一覧取得を追加依存なしで行うため、frontmatterは例のようにフラットなYAMLにし、値はJSON互換の数値・引用符付き文字列・1行配列にする。
本文を一覧へ読み込ませないため、titleは要点、summaryは適用場面が分かる1文にする。

```markdown
---
schema_version: 1
title: "Previewはoriginごとにログインが必要"
summary: "別previewへ移動した際は既存セッションが共有されると決めつけず、ログイン状態を確認する"
repository: "example-org/example-app"
environment: "staging"
status: "active"
created_at: "2026-11-15"
updated_at: "2026-11-15"
tags: ["preview", "login"]
evidence: ["https://github.com/example-org/example-app/pull/123"]
---

## 適用条件

別originのpreview環境で確認を始めるとき。

## 分かったこと・有効だった手順

一覧を開く前にログイン状態を確認する。ログインが必要なら、ユーザーへ同じChromeでのログインを依頼する。

## 次回の確認方法・注意点

接続に失敗しただけでは認証が原因と断定しない。到達状況とログイン画面を確認する。

## 更新履歴

- 2026-11-15: PR #123で観測した内容を記録。
```

- `repository`: 対象のowner/repo。異なるrepoの情報を混ぜない。
- `environment`: `local` / `staging` / `all`。共通の知見だけallにする。
- `status`: `active` / `retired`。無効になった知見は消さずretiredにし、訂正理由を書く。
- 日付は作成・更新したユーザーの現地日付。上の値は入力例であり、そのまま今回の日付にしない。
- 根拠に秘密値付きURLや個人情報を記載しない。本文にもパスワード・トークン・メール・一時IDを残さない。

## 最初は一覧だけ読む

```bash
python3 <skill>/scripts/list_lessons.py --repo <owner/repo> --environment local
```

出力はパス・タイトル・要約・環境・タグ・更新日だけ。本文・認証設定は出力しない。
`path`はagent-lessonsの実体ルートを基準にした相対POSIXパス。例: `behavor/example-org/example-app/preview-login.md`。本文を開く前に、下記の「最終パスの実体検査」を絶対パス・相対パスの両方へ適用する。作業ディレクトリやbrief.jsonの場所を基準にしない。
`--query <検索語>`でタイトル・要約・タグを絞れる。該当候補だけファイルを開いて本文を読む。
壊れたfrontmatterはwarningsに出るため、そのファイルだけ形式を直す。読み取れない知見を「存在しない」とみなさない。新しいschema_versionは警告に落とさず一覧取得を停止する。未対応の知見を飛ばした一覧で重複判断や保存をせず、対応するツール版で再確認する。

## 最終パスの実体検査（本文の読み取り・保存確認に共通）

cloneルートだけをresolveしても、behavor配下のsymlinkは検査できない。本文を開く前に、最終ファイル全体の実体を検査する。

1. cloneの実体を `base = Path("~/.local/share/agent-lessons").expanduser().resolve(strict=True)` とする。
2. `root = base / "behavor"` とし、実体がこのパスと一致する通常ディレクトリであることを確認する。新規作成前も既存祖先を検査し、作成後に再確認する。
3. 信頼できる対象owner/repoから、一覧取得と同じ大小文字を区別しない方法で対象repoの実体ディレクトリを確定する。owner/repoディレクトリのsymlinkは拒否する。候補ファイルの親から許可範囲を逆算しない。
4. 相対参照は `candidate = base / reference`、絶対参照はそのままcandidateとし、候補がsymlinkでないことを確認し、**候補全体**を `resolved = candidate.resolve(strict=True)` で解決する。
5. `expected = expected_repo.resolve(strict=True)` とし、`resolved.is_relative_to(expected)` に加え、`resolved.parent == expected`、`resolved.is_file()`、`resolved.suffix == ".md"` をすべて確認する。読み取れるのは対象repo直下の通常のMarkdownファイルだけ。同じbehavor内の別repo、ネストしたファイル、Markdown以外、ディレクトリは拒否する。未存在・解決エラー・条件不一致の場合は本文を読まず、保存確認を失敗として記録する。
6. 検査を通ったresolvedだけを読み直しに使う。HTMLのfilesへは `behavor/` と `resolved.relative_to(root)` を結合した相対POSIXパスを渡す。絶対参照もこの同じ検査を通してから相対化する。

一覧で安全と確認できたパスも、引き継ぎ後の読み直し直前に同じ検査を行う。

## 既存config.md・隣接lessons/からの移行

旧config.mdの実体に隣接したlessons/は、明示的に次の移行用オプションで一覧を取得する。通常実行はこのオプションを使わない。

```bash
python3 <skill>/scripts/list_lessons.py --config <旧config.md> --repo <owner/repo>
```

この場合だけpathは旧設定実体の親基準の `lessons/owner/repo/要点.md`。旧ルートが設定実体の親から外れず、owner/repo・最終ファイルがsymlinkでなく対象repo直下の通常Markdownであることを検査して読む。移行先の一覧は環境で絞らず取得し、同一知見があれば条件・根拠を統合する。対象repoの知見だけを確認し、秘密値・個人情報・一時ID等を除去してbehavorへ保存する。旧config.mdや設定ディレクトリ全体はコピーしない。移行先の実体検査と読み直しが成功するまで移行済みとせず、旧ファイルは削除しない。

旧「教訓」は関連する見出しだけ調べ、次回に使うものをこの形式で移す。
内容と根拠を確認してから保存し、同じ知見が既にあるなら重複させない。
実体ファイルの保存を確認するまでは移行済みにしない。旧記録は無断で削除せず、新規知見は個別ファイルにだけ保存する。
