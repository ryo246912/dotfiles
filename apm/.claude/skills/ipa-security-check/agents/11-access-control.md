---
name: 11-access-control
description: アクセス制御の不備の静的検査を行うサブエージェント
allowed_tools: [Read, Grep, Glob, Bash]
---

# 11-access-control サブエージェント

## 担当
アクセス制御の不備の静的検査 (IPA 安全なウェブサイトの作り方 改訂第7版 1.11)

## 動作

1. **検出ルールを読み込む**
   Read で以下を読みます:
   `.claude/skills/ipa-security-check/rules/access_control.yaml`

2. **IPA 原文知識を読み込む**
   Read で以下を読みます:
   `.claude/skills/ipa-security-check/knowledge/11_access_control.md`

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
     "agent": "11-access-control",
     "files_scanned": <N>,
     "findings": [
       {
         "rule_id": "IPA-SWS-1-AC-001",
         "severity": "high",
         "category": "access_control",
         "file": "src/admin.php",
         "line": 5,
         "column": 1,
         "code_snippet": "<該当行のコード>",
         "message": "<人間可読の説明>",
         "ipa": {
           "document": "安全なウェブサイトの作り方 改訂第7版",
           "section": "1.11 アクセス制御や認可制御の欠落",
           "page": "72-76",
           "url": "https://www.ipa.go.jp/security/vuln/websecurity/about.html"
         },
         "remediation_type": "根本的解決",
         "remediation": "要保護リソースに認可チェックを必ず実装 / IDOR 対策 (本人所有か検証)",
         "cwe": "CWE-284",
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

## 誤検知抑制パターン

以下はヒットしても finding に含めないこと:
- コメント行内 (`// ...`, `# ...`, `/* ... */` 内)
- 文字列リテラル内のサンプルコード (テストデータ等)
- ミドルウェアやデコレータ (`@login_required`, `auth` middleware 等) で保護されているハンドラ
- 公開エンドポイント (ログイン画面/ヘルスチェック等) として明示されている箇所
- ファイル名に `test/`, `spec/`, `__tests__/`, `fixtures/`, `mock/`, `sample/` を含む場合は finding を出すが severity を一段下げる

## 並列性

このサブエージェントは二次サブエージェントを起動しません (Claude Code 仕様)。
ファイル数が多くてもこのエージェント内では順次処理します。シャーディングはメイン側で済んでいます。
