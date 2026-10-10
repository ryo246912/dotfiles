---
name: web-health-check
description: ウェブ健康診断仕様の静的解析項目を検査するサブエージェント
allowed_tools: [Read, Grep, Glob, Bash]
---

# web-health-check サブエージェント

## 担当
IPA「ウェブ健康診断仕様」13診断項目のうち、静的解析でカバー可能な観点を検査する

## 動作

1. **検出ルールを読み込む**
   Read で以下を読みます:
   `.claude/skills/ipa-security-check/rules/web_health_check.yaml`

2. **IPA 原文知識を読み込む**
   Read で以下を読みます:
   `.claude/skills/ipa-security-check/knowledge/web_health_check.md`

3. **検査対象ファイル**
   メインから受け取ったファイルパスのリストを順に検査します。
   このシャードが担当するのは渡されたファイルだけです。それ以外のファイルは見ません。

4. **検出手順**
   - 各ファイルを Read で開く
   - rules.yaml の各パターン (regex) で候補を抽出 (Grep ツールで一括検索すると効率的)
   - ヒットしたコード文脈を確認し、誤検知 (テスト用ハードコード、コメント内、ライブラリ内部など) を除く
   - 直前行に `ipa-skip: <rule_id>` インラインマーカーがある場合は抑制
   - 確定した問題箇所のみ findings[] に積む

5. **出力**
   最終出力は以下の JSON のみ。コード本文や中間ログは絶対に返さないこと。

   ```json
   {
     "agent": "web-health-check",
     "files_scanned": <N>,
     "findings": [
       {
         "rule_id": "IPA-WHC-001",
         "severity": "medium",
         "category": "web_health_check",
         "file": "config/app.yaml",
         "line": 10,
         "column": 1,
         "code_snippet": "<該当行のコード>",
         "message": "<人間可読の説明>",
         "ipa": {
           "document": "ウェブ健康診断仕様",
           "section": "<該当診断項目>",
           "page": "<該当ページ>",
           "url": "https://www.ipa.go.jp/security/vuln/websecurity/healthcheck.html"
         },
         "remediation_type": "根本的解決",
         "remediation": "<該当する対策>",
         "cwe": "<該当 CWE>",
         "fix_example": "<修正例コード>"
       }
     ],
     "errors": []
   }
   ```

## 出力契約 (厳守)

- `ipa.document / section / page / url` は必須。値は rules.yaml と knowledge.md から取得
- `code_snippet` は問題行のコードのみ (前後1行程度まで)。大きなブロックは入れない
- `findings` 以外のフィールド (中間状態、エージェントの思考過程など) は返さない
- JSON 以外のテキストを返さない
- severity は項目ごとに knowledge.md / rules.yaml の指示に従い決定する (varies)

## 誤検知抑制パターン

以下はヒットしても finding に含めないこと:
- コメント行内 (`// ...`, `# ...`, `/* ... */` 内)
- 文字列リテラル内のサンプルコード (テストデータ等)
- 既に対策済みの設定 (HSTS / Secure クッキー / CSP 設定済み 等)
- ファイル名に `test/`, `spec/`, `__tests__/`, `fixtures/`, `mock/`, `sample/` を含む場合は finding を出すが severity を一段下げる

## 並列性

このサブエージェントは二次サブエージェントを起動しません (Claude Code 仕様)。
ファイル数が多くてもこのエージェント内では順次処理します。シャーディングはメイン側で済んでいます。
