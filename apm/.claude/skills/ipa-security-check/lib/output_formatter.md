# Output Formatter — Markdown / SARIF 生成

集約済み findings[] (snippet_hash / fp_verdict / status などのトリアージ属性を含む) を Markdown レポートと SARIF 2.1.0 に変換する。

## 入力

```yaml
findings: [...]      # snippet_hash, fp_verdict, fp_confidence, fp_reason,
                     # status, triaged_at, triaged_by, note を含む
files_scanned: 247
errors: [...]
output_files:
  - ipa-security-report.md
  - ipa-security-report.sarif
scope:
  paths: ["src/"]
  diff_mode: false
filter:
  categories: [...]
  severity_min: "low"
```

## findings の振り分け

`lib/triage_state.md` Step 6.3 の規則で 3 セクションに振り分ける。

```python
detect_section = []        # 通常の検出結果
fp_section     = []        # 偽陽性候補
triaged_section= []        # トリアージ済み (抑止)

for f in findings:
    if f.fp_verdict == "likely_false_positive" and f.status != "対応する":
        fp_section.append(f)
    elif f.status in ("問題なし", "保留"):
        triaged_section.append(f)
    else:
        detect_section.append(f)
```

サマリ件数は `detect_section` のみで計上する。

## Markdown 生成

`templates/report.md.tmpl` を読み、以下の変数を埋め込む。

| 変数 | 値 |
|---|---|
| `{{scan_date}}` | 実行日時 ISO 8601 |
| `{{scope_summary}}` | スコープ要約 (パス/差分モード) |
| `{{files_scanned}}` | スキャンファイル数 |
| `{{total_findings}}` | detect_section の件数 |
| `{{count_critical}}` 〜 `{{count_info}}` | severity 別件数 (detect_section のみ) |
| `{{count_fp}}` | fp_section の件数 |
| `{{count_not_an_issue}}` | triaged_section のうち `問題なし` |
| `{{count_deferred}}` | triaged_section のうち `保留` |
| `{{findings_by_category}}` | detect_section をカテゴリ別にブロック化 |
| `{{findings_false_positive}}` | fp_section をブロック化 |
| `{{findings_triaged}}` | triaged_section をブロック化 |
| `{{errors_section}}` | エラー一覧 (あれば) |

### finding ブロックの形式 (全セクション共通)

すべての finding ブロックは **triage ブロック (HTML コメント) を直下に必ず置く**。
これがないと次回スキャンでトリアージが引き継げない。

```markdown
### [CRITICAL] IPA-SWS-1-SQLI-001 — 文字列連結によるSQL組み立て

<!-- ipa-triage:begin
status: {{status}}
snippet_hash: {{snippet_hash}}
triaged_at: {{triaged_at}}
triaged_by: {{triaged_by}}
note: {{note}}
ipa-triage:end -->

**Status**: {{status}}

- **File**: `src/users.php:45:12`
- **Category**: SQL Injection (CWE-89)
- **IPA**: [安全なウェブサイトの作り方 改訂第7版 1.1 SQLインジェクション (p.6-12)](https://www.ipa.go.jp/security/vuln/websecurity/about.html)
- **Remediation Type**: 根本的解決
- **Remediation**: プレースホルダによる SQL 文の組み立て

**問題箇所**:
\`\`\`php
$sql = "SELECT * FROM users WHERE id = " . $_GET['id'];
\`\`\`

**修正例**:
\`\`\`php
$stmt = $pdo->prepare("SELECT * FROM users WHERE id = :id");
$stmt->execute([':id' => $_GET['id']]);
\`\`\`
```

#### 偽陽性候補セクション固有の追加表記

`{{findings_false_positive}}` に出すブロックは、上記に加え以下を追加する:

```markdown
**FP 判定**: likely_false_positive (confidence: medium)
**FP 理由**: 直前で htmlspecialchars($v, ENT_QUOTES | ENT_HTML5, 'UTF-8') が適用済み。検出ルールは関数名のみで第2引数の有無を見ていない
```

#### トリアージ済みセクション固有の追加表記

`{{findings_triaged}}` に出すブロックは追加表記なし (status と note で十分)。

### グルーピング順

- detect_section: severity 降順 → category 昇順 → file 昇順 → line 昇順
- fp_section / triaged_section: category 昇順 → file 昇順 → line 昇順

## SARIF 生成

`templates/sarif.json.tmpl` を読み、SARIF 2.1.0 仕様に変換。

### 出力対象

- `detect_section` の finding を `results[]` に展開 (通常)
- `triaged_section` の finding は `results[].suppressions[]` を埋めた上で `results[]` に含める (SARIF 標準の抑止表現)
- `fp_section` の finding も `results[].suppressions[]` (`kind: "external"`, `justification` に FP 理由) を埋めて出す

SARIF コンシューマ (GitHub Code Scanning など) は `suppressions` を尊重して非表示にする。

### マッピング

| finding フィールド | SARIF フィールド |
|---|---|
| `rule_id` | `results[].ruleId` |
| `severity` | `results[].level` (critical/high → error, medium → warning, low/info → note) |
| `message` | `results[].message.text` |
| `file` | `results[].locations[0].physicalLocation.artifactLocation.uri` |
| `line` | `results[].locations[0].physicalLocation.region.startLine` |
| `column` | `results[].locations[0].physicalLocation.region.startColumn` |
| `code_snippet` | `results[].locations[0].physicalLocation.region.snippet.text` |
| `snippet_hash` | `results[].partialFingerprints.snippetHash` |
| `status` | `results[].properties.triageStatus` |
| `note` | `results[].properties.triageNote` |
| `triaged_at` | `results[].properties.triagedAt` |
| `triaged_by` | `results[].properties.triagedBy` |
| `fp_verdict` | `results[].properties.fpVerdict` |
| `fp_reason` | `results[].properties.fpReason` |
| `ipa.url` | `tool.driver.rules[].helpUri` |
| `ipa.document + section + page` | `tool.driver.rules[].help.markdown` |
| `cwe` | `tool.driver.rules[].properties.tags[]` |
| `remediation` | `tool.driver.rules[].help.text` |

### suppressions の埋め方

```json
"suppressions": [
  {
    "kind": "external",
    "status": "accepted",      // status=問題なし のときは accepted, 保留 のときは underReview
    "justification": "<note または FP 理由>"
  }
]
```

| 元のステータス / FP | SARIF kind | SARIF status |
|---|---|---|
| status = 問題なし | `external` | `accepted` |
| status = 保留 | `external` | `underReview` |
| fp_verdict = likely_false_positive | `external` | `underReview` |

### tool.driver 情報

```json
{
  "driver": {
    "name": "IPA Security Check Skill",
    "version": "1.0.0",
    "informationUri": "https://www.ipa.go.jp/security/vuln/websecurity/about.html",
    "rules": [...]
  }
}
```

### rules[] の生成

`detect_section` + `triaged_section` + `fp_section` のすべてで使われた `rule_id` をユニーク抽出し、`rules/` 配下の YAML から定義を引いて `rules[]` を構築。

## 書き出し

```bash
# Markdown
Write(output.markdown_path, rendered_markdown)

# SARIF
Write(output.sarif_path, rendered_sarif)
```

`--output` で指定があれば該当パスへ書く。

## ユーザーへの最終報告

```
✅ IPA セキュリティチェック完了

スキャン: 247 ファイル / 14 カテゴリ
検出 (要対応):  18 件 (Critical 2 / High 6 / Medium 7 / Low 3)
偽陽性候補:     4 件 (本文外)
トリアージ済み: 5 件 (問題なし 3 / 保留 2)

出力: ipa-security-report.md
      ipa-security-report.sarif

要対応の Critical:
- src/users.php:45  IPA-SWS-1-SQLI-001 (SQL Injection)
- src/admin.php:88  IPA-SWS-1-OSCMD-002 (OS Command Injection)
```
