# pulls.review CLI

`pulls-review` はPR番号1つからGitHubのstack所属情報を調べ、stackなら全体を、単体ならそのPRを
公式レビューCLI `pulls.review` で開きます。引数省略時は現在のbranchのPRを使います。
Node.js 20以上、Python 3、認証済みの `gh` が必要です。git repository内で実行してください。

## 導入

```bash
# dotfiles checkoutのルートで実行
mise install npm:pulls.review
mise bootstrap dotfiles apply --yes "~/.local"
pulls.review --help
"$HOME/.local/bin/pulls-review" --help
```

旧copy方式の `~/.local/bin` が残っている環境ではapplyが衝突する場合があります。
その場合は配置先だけにある編集を先にdotfilesへ取り込み、対象を限定して再実行します。

```bash
mise bootstrap dotfiles apply --force --yes "~/.local"
```

公式packageにも `pulls-review` aliasがあります。zshでは同名functionで `~/.local/bin/pulls-review` を
優先します。設定反映後にshellを開き直してください。ほかのshellでは `~/.local/bin` をmise shimsより前に
PATHへ置くか、補助コマンドを絶対パスで呼びます。`command -v pulls-review` で確認できます。
`pulls.review` は0.3.4に固定しています。mise lockfile更新はネットワークが利用できる環境で行ってください。

## 使い方

```bash
pulls-review                          # 現在のbranchのPRからstackを自動検出
pulls-review 124                      # stackのどの段のPRでも全体を開く
pulls-review owner/repo#124
pulls-review 124 --dry-run            # 検出結果・比較対象だけ確認
pulls-review 124 --diff > stack.diff  # 統合diffを保存
pulls-review 124 --no-open --port 3000
```

例: `main <- feature-a (#123) <- feature-b (#124) <- feature-c (#125)` なら、
`pulls-review 124` だけで #123/#124/#125 を取得し、stackのultimate base SHAから
最上段のhead SHAまでの `base...head` 比較を開きます。各PRのpatchを単純連結する方法ではないため、
同じファイルが複数段で変更されても最終的な差分になります。GitHub compareのmerge-base基準です。

PRのREST resourceの `stack.number` と `GET /repos/{owner}/{repo}/stacks/{number}` を使います。
branch名からの推測ではなく、GitHub上で登録されたstackが対象です。未登録のbranch chainは単体PRとして扱います。
stack取得エラーは停止し、単体扱いに切り替えません。stack内のclosed/merged PRを勝手に取り除かず、
APIが返す全memberの最上段とstack baseを使います。既にbaseへmerge済みの変更はcompareの差分から消えます。

stack全体のcompare画面では個別PRのreview threadへ対応付けることはできません。
個々のPRへのコメント・reviewは単体PR画面から行ってください。

## Local agentで解析

この構成はログイン済みの **Codex / Claude Code** を使う前提です。
モデルAPIキーの追加設定は不要です。使用するagentの認証・契約が必要です。
`codex` または `claude` がCLIを起動するshellのPATHにあることを確認してください。

初回は `pulls-review` で開いたブラウザ画面の **Settings** で次を設定します。

1. AI providerに **Local agent** を選ぶ。
2. Agentに **Codex** または **Claude Code** を選ぶ。
3. 必要に応じてモデルと言語（日本語）を選び、解析を実行する。

これらはブラウザのlocalStorageに保存されます。補助コマンドからproviderを設定する公式CLI引数は
ないため、初回の選択は画面で行います。設定はブラウザのorigin単位なので、毎回同じportを使うと
再利用できます（例: `pulls-review --port 3000`）。起動時にLocal agentの案内も表示します。

Local agentは差分のmanifestと必要なpatchを読み、変更の意味・目的ごとにグループと要約を作ります。
各ファイルの割り当てを構造化出力で検証します。解析と追加質問は選択したagentを通して行います。
stack全体でも単体PRでも同じ操作です。

APIキーが必要な `@pulls.review/actions` は導入対象から外し、補助コマンドの `--post` /
`--provider` / `--model` / `--locale` オプションも削除しています。言語とモデルはUIで設定します。

GitHubへのアクセスには別途 `gh` の認証を使います。認証は `PULLS_REVIEW_GITHUB_TOKEN`、
`GITHUB_TOKEN`、`GH_TOKEN`、`gh auth token` の順で利用します。
`--dry-run` / `--diff` はagentの呼び出し・コメント投稿を行いません。

公式仕様:

- <https://github.com/antfu/pulls.review/tree/main/packages/cli>
- <https://github.com/github/gh-stack/blob/main/docs/src/content/docs/reference/rest-api.md>
