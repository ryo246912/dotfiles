# PRの動作確認（pr-reviewer-behavior）

起動済みのlocalhostやpreviewでPRの変更を操作して確認する自作スキルです。
確認用データを準備し、対象画面へ到達する作業を補助します。自動操作できない場合も、
準備したデータのID・URL・手動確認手順を残します。

## 配布と呼び出し

ソースは `config/rulesync/.rulesync/skills/pr-reviewer-behavior/` です。
既存のrulesync同期でClaude CodeとCodex CLIに配布します（[rulesync](rulesync.md)）。

```text
# Claude Code
/pr-reviewer-behavior https://github.com/<owner>/where/pull/123

# Codex CLI
$pr-reviewer-behavior PR #123。準備したデータは手動確認用に残して
```

番号だけの場合はカレントリポジトリまたはローカル設定から解決します。
stack内のPRなら最上位PRの環境を使い、原則として入力PRの変更を確認します。
stack全体を確認したい場合はその旨を指定します。

## リポジトリごとの設定

1. スキル内の `.gitignore.example` の内容を、対象リポジトリの `.gitignore` または
   `.git/info/exclude` に追加します。
2. スキル内の `.pr-reviewer.local.example.md` を、対象リポジトリ直下の
   `.pr-reviewer.local.md` にコピーします。
3. 起動済みURL、ログイン方法、ロール・テナント、データ作成の許可範囲と既存手順を記入します。

exampleはGit管理します。実際のURLやパスワードを記入するローカル設定と、実行時の成果物は
Git管理しません。既に追跡済みのファイルはignoreだけでは保護されないため、秘密値を記入しないでください。
別の設定パスを指定した場合はそのファイルもGit管理から外します。

## 確認結果と手動での引き継ぎ

`.pr-reviewer-artifacts/<PR番号>/<実行識別子>/report.md` に以下を残します。

- 入力PRと最上位PR、head SHA、検証URLと環境との対応確認状況
- 準備済みデータのID・表示名・状態・開くURL
- 使用するアカウント別名・ロール、画面上の文言を使った操作手順、入力例、期待結果
- PASS / FAIL / BLOCKED / NOT RUNと証拠、未確認事項、データの削除手順

秘密値はレポートへ転記しません。作成した専用データは、設定に別の指定がなければ手動確認用に残します。

## 対象外

環境構築・依存導入・サーバー起動・checkout・migration・feature flag変更・base比較は行いません。
実装修正やGitHubへの投稿も別途依頼がなければ行いません。
ブラウザ操作には利用環境の既存スキル・ツールを使います。

## 参考にした公開スキル

- [OpenAI Playwright](https://github.com/openai/skills/tree/main/skills/.curated/playwright)
- [Microsoft Playwright CLI](https://github.com/microsoft/playwright-cli/tree/main/skills/playwright-cli)
- [Anthropic webapp-testing](https://github.com/anthropics/skills/tree/main/skills/webapp-testing)
- [Vercel agent-browser](https://github.com/vercel-labs/agent-browser/tree/main/skills/agent-browser)
