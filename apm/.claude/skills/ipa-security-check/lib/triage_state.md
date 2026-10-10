## Triage State — トリアージ状態の保持と引き継ぎ

トリアージ状態は **Markdown レポート本体に埋め込んで保持** する (専用の状態ファイルは作らない)。
これにより `git` 管理・PR レビュー・人間の編集がすべて Markdown 上で完結する。

## 4 ステータス

| ステータス | 意味 | 次回スキャンでの扱い |
|---|---|---|
| `未対応` | 未着手。デフォルト | メインの検出結果セクションに表示 |
| `対応する` | 修正を予定 / 実施中 | メインの検出結果セクションに表示 (バッジで識別) |
| `問題なし` | 確認の上、本物の脆弱性ではない / 受容可能なリスク | `## トリアージ済み (抑止)` セクションへ移動。サマリ件数からも除外 |
| `保留` | 一旦保留。後で再判断 | `## トリアージ済み (抑止)` セクションへ移動。サマリ件数からも除外 |

新規 finding はすべて `未対応` で生成する。

## snippet_hash の計算

トリアージ済みかどうかの同定キー。同じファイル・同じルール・同じコード断片であれば、行番号が変動しても引き継げる。

### 計算式

```
key   = rule_id + "\n" + file_normalized + "\n" + code_normalized
hash  = sha256(key) の先頭 16 文字 (hex) に "sha256:" を冠したもの
```

### file の正規化

- リポジトリルートからの相対パス
- 区切り文字は `/` に統一 (Windows でも)

### code_snippet の正規化

1. 改行を `\n` に統一
2. 前後の空白行を除去
3. 各行末の空白を除去
4. 連続する空白 (スペース/タブ) を 1 つに圧縮
5. 行頭インデントは保持しない (圧縮対象)
6. 大文字小文字は保持 (識別子の比較に効くため)

> 行番号は **キーに含めない**。コード断片そのものが識別子。

## Markdown 内の Triage ブロック形式

各 finding 直下に **HTML コメントの triage ブロック** を埋め込む。ユーザーはこの中の `status:` と `note:` を直接編集する。

```markdown
#### [CRITICAL] IPA-SWS-1-SQLI-001 — 文字列連結による SQL 組み立て

<!-- ipa-triage:begin
status: 未対応
snippet_hash: sha256:1a2b3c4d5e6f7890
triaged_at: -
triaged_by: -
note: -
ipa-triage:end -->

**Status**: 未対応

- **File**: `src/users.php:45`
- **IPA**: ...
```

### 編集可能なフィールド (ユーザーが手で変える)

- `status` … 4 値のいずれか
- `note` … 自由記述 (理由・関連 PR 番号など)。複数行可。

### 編集不可なフィールド (orchestrator が機械的に書き込む)

- `snippet_hash` … 改変するとマッチング失敗するので変えない
- `triaged_at` … ステータスが変化した最後の日時 (ISO 8601)。ユーザー編集を検知したらタイムスタンプを更新
- `triaged_by` … 編集者名 (オプション、なくても良い)

## 既存レポートの読み込み

orchestrator は新レポートを書き出す **前** に、出力先と同じパス (デフォルト `./ipa-security-report.md`) を読み込む。

### 抽出ロジック

1. ファイルが存在しなければ空 dict を返す (初回スキャン)
2. ファイル全体に対し以下の正規表現で triage ブロックを全件抽出

```regex
<!-- ipa-triage:begin\s*\n
  ((?:.*\n)*?)
ipa-triage:end -->
```

3. 各ブロックの中身を YAML 風に行単位で `key: value` パース
4. `snippet_hash` をキーに dict 化

```python
{
  "sha256:1a2b3c4d5e6f7890": {
    "status": "問題なし",
    "triaged_at": "2026-05-10T12:34:00Z",
    "triaged_by": "alice",
    "note": "テストフィクスチャ用のダミー値で外部入力なし"
  },
  ...
}
```

### 不正ブロックの扱い

- `status` が 4 値以外 → 警告ログを出し `未対応` 扱い
- `snippet_hash` が `sha256:` で始まらない → スキップ
- パース失敗 → スキップして `errors[]` に記録

## 新規 findings との突き合わせ

新しい findings に対し:

```python
for f in new_findings:
    f["snippet_hash"] = compute_snippet_hash(f)
    prior = prior_state.get(f["snippet_hash"])
    if prior is None:
        f["status"] = "未対応"
        f["triaged_at"] = "-"
        f["triaged_by"] = "-"
        f["note"] = "-"
    else:
        f["status"] = prior["status"]
        f["triaged_at"] = prior["triaged_at"]
        f["triaged_by"] = prior["triaged_by"]
        f["note"] = prior["note"]
```

## 出力先の振り分け

`status` の値で出力セクションを決める:

| status | 出力先セクション | サマリへの計上 |
|---|---|---|
| `未対応` | `## 検出結果` (通常) | する |
| `対応する` | `## 検出結果` (通常、バッジ付き) | する |
| `問題なし` | `## トリアージ済み (抑止)` | しない |
| `保留` | `## トリアージ済み (抑止)` | しない |

加えて、`偽陽性 review` で `likely_false_positive` と判定された finding は **status に関係なく** `## 偽陽性候補` セクションへ移動する (検出結果セクションには出さない)。
ただし `likely_false_positive` でかつ既存トリアージで `対応する` になっているものは「ユーザーが対応すると明示した」ことを優先し、通常の `## 検出結果` に残す (誤判定耐性)。

## 既トリアージとの完全一致抑止

ユーザー要件: 「既にトリアージしているものと**全く同じ内容**の結果は抑止」

- `snippet_hash` 一致 + `status ∈ { 問題なし, 保留 }` → 通常レポートから抑止 (`## トリアージ済み (抑止)` に移す)
- `snippet_hash` 一致 + `status ∈ { 未対応, 対応する }` → 通常レポートに残す (まだトリアージが終わっていないため)

## ユーザーへの説明 (レポート末尾に常に記載)

`templates/report.md.tmpl` の脚注として以下を必ず出す:

```markdown
## トリアージの使い方

- 各 finding 直下の `<!-- ipa-triage:begin ... ipa-triage:end -->` ブロックの `status:` を編集してください
- 利用できる値: `未対応` / `対応する` / `問題なし` / `保留`
- `note:` には判断理由を自由に書けます (複数行可)
- 次回 `/ipa-security-check` 実行時、同じ snippet_hash の finding にステータスが引き継がれます
- `問題なし` / `保留` にした finding は次回以降「トリアージ済み (抑止)」セクションへ移動し、本文の検出結果やサマリから外れます
- `snippet_hash` 行は触らないでください (一致判定が壊れます)
```
