# PRの動作確認（pr-reviewer-behavior）

起動済みのlocalやstaging（preview）でPRの変更を操作して確認する自作スキルです。
確認用データを準備し、対象画面へ到達する作業を補助します。
自動操作できない場合も、準備したデータのID・URL・手動確認手順を残します。

## 配布と呼び出し

ソースは `config/rulesync/.rulesync/skills/pr-reviewer-behavior/` です。
既存のrulesync同期でClaude CodeとCodex CLIに配布します（[rulesync](rulesync.md)）。
Playwright MCPまたはClaude in Chromeで、AIが接続しているChromeを使います。
独立したブラウザをCLIから起動することは想定しません。

```text
# Claude Code
/pr-reviewer-behavior https://github.com/<owner>/<repository>/pull/123

# Codex CLI
$pr-reviewer-behavior PR #123。localで確認して、準備したデータは残して
```

番号だけの場合はカレントリポジトリから解決します。
stack内のPRなら最上位PRの環境を使い、原則として入力PRの変更を確認します。
stack全体を確認したい場合はその旨を指定します。

## 設定と教訓の蓄積

スキルの `config.example.md` を、同じディレクトリに `config.md` としてコピーして使います。
初回起動時はスキルがコピーを作り、以後も未記入項目を補完します。

- リポジトリごとの見出しを何件でも追加でき、各リポジトリにlocalとstaging（preview）を分けて記載します。
- 環境ごとにアカウント、データ準備手順、画面・データの見出しを何件でも追加できます。
- AIはPR・コード・接続済みChromeから判明した内容を追記し、続行に必要な不明項目だけ確認します。
- 既存のログインセッションで進められる場合は、メールやパスワードの記入は不要です。
- 実行を通じて得た再利用できる教訓は、同じ `config.md` の末尾に日付・対象・適用条件・根拠付きで追記します。

exampleはGit管理します。実際の設定ファイルと `.pr-reviewer-artifacts/` は、
`config/git/gitignore` のglobal ignoreで除外します。対象リポジトリのignore設定の追加は不要です。
別名の `config.md` 全般を除外せず、`pr-reviewer-behavior/config.md` に限定します。
既に追跡されているファイルはignoreでは保護できないため、秘密値を記入しないでください。

rulesyncで配布したClaude Code用・Codex用のディレクトリは別々の設定になり得ます。
設定の補完・教訓追記は実行中に参照した同じ `config.md` に行い、別の配布先へ自動転記しません。
exampleの更新で既存の `config.md` は上書きしません。

## スクリーンショット付きHTML

結果は `.pr-reviewer-artifacts/<PR番号>/<実行識別子>/<PR番号>-<PRタイトル>.html` に出力します。
例: `123-検索条件を追加.html`。

- 入力PRと最上位PR、head SHA、検証URLと環境との対応確認状況
- 準備済みデータのID・表示名・状態・開くURL
- 手動確認の操作手順、入力例、期待結果
- PASS / FAIL / BLOCKED / NOT RUNと、確認した各項目の結果画面のスクリーンショット
- 未確認事項、データの削除手順、設定補完・教訓追記の要点

画像はHTMLに埋め込み、HTML単体で確認できます。撮影できない場合は理由を明記します。
認証情報はHTMLや教訓へ転記しません。
作成した専用データは、設定に別の指定がなければ手動確認用に残します。

## 対象外

環境構築・依存導入・サーバー起動・checkout・migration・feature flag変更・base比較は行いません。
実装修正やGitHubへの投稿も別途依頼がなければ行いません。

## 参考にした公開スキル

- [OpenAI Playwright](https://github.com/openai/skills/tree/main/skills/.curated/playwright)
- [Microsoft Playwright CLI](https://github.com/microsoft/playwright-cli/tree/main/skills/playwright-cli)
- [Anthropic webapp-testing](https://github.com/anthropics/skills/tree/main/skills/webapp-testing)
- [Vercel agent-browser](https://github.com/vercel-labs/agent-browser/tree/main/skills/agent-browser)
