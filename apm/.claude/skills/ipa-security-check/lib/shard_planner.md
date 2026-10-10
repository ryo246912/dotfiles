# Shard Planner — シャーディング設計

サブエージェントは二次サブエージェントを起動できない (公式制約) ため、対象ファイル数が多いカテゴリはメイン側で事前にシャーディングする。

## 入力

`lib/scope_resolver.md` の出力 (ファイル一覧 + 言語) + `--categories` フィルタ。

## 出力

```yaml
shards:
  - agent: 01-sql-injection
    shard_id: 1
    files: [src/a.php, src/b.php, ...]   # 最大 shard_size 件
    rule_file: rules/sql_injection.yaml
    knowledge_file: knowledge/01_sql_injection.md
  - agent: 01-sql-injection
    shard_id: 2
    files: [...]
  - agent: 05-xss
    shard_id: 1
    files: [...]
  ...
```

## アルゴリズム

### 1. カテゴリごとに対象ファイルをフィルタ

各サブエージェントの担当言語マッピング:

| エージェント | 担当言語 | rule_file | knowledge_file |
|---|---|---|---|
| 01-sql-injection | php, java, ruby, python, javascript, typescript, csharp, go | rules/sql_injection.yaml | knowledge/01_sql_injection.md |
| 02-os-command-injection | 同上 | rules/os_command_injection.yaml | knowledge/02_os_command_injection.md |
| 03-directory-traversal | 同上 | rules/directory_traversal.yaml | knowledge/03_directory_traversal.md |
| 04-session-management | 同上 + webserver-config | rules/session_management.yaml | knowledge/04_session_management.md |
| 05-xss | php, java, ruby, python, javascript, typescript, csharp, go (テンプレート含む) | rules/xss.yaml | knowledge/05_xss.md |
| 06-csrf | 同上 | rules/csrf.yaml | knowledge/06_csrf.md |
| 07-http-header-injection | 同上 | rules/http_header_injection.yaml | knowledge/07_http_header_injection.md |
| 08-mail-header-injection | 同上 | rules/mail_header_injection.yaml | knowledge/08_mail_header_injection.md |
| 09-clickjacking | php, java, ruby, python, javascript, typescript, csharp, go, webserver-config | rules/clickjacking.yaml | knowledge/09_clickjacking.md |
| 10-buffer-overflow | c, cpp, go (一部) | rules/buffer_overflow.yaml | knowledge/10_buffer_overflow.md |
| 11-access-control | php, java, ruby, python, javascript, typescript, csharp, go | rules/access_control.yaml | knowledge/11_access_control.md |
| safe-sql-details | php, java, ruby, python, javascript, typescript, csharp, go | rules/safe_sql_details.yaml | knowledge/safe_sql_details.md |
| web-health-check | すべて | rules/web_health_check.yaml | knowledge/web_health_check.md |
| operation-checklist | すべて (特に config 系) | rules/operation_checklist.yaml | knowledge/operation_checklist.md |

### 2. シャードサイズの決定

デフォルト `shard_size = 10` ファイル/shard。

ただし以下で動的調整:

| 条件 | shard_size |
|---|---|
| ファイル平均サイズ < 5KB | 20 |
| ファイル平均サイズ 5-50KB | 10 |
| ファイル平均サイズ > 50KB | 5 |

1 カテゴリ合計が `shard_size` 以下なら 1 shard。

### 3. シャード生成

```python
def make_shards(category_files, shard_size):
    shards = []
    for i in range(0, len(category_files), shard_size):
        shards.append({
            "agent": category.agent_name,
            "shard_id": (i // shard_size) + 1,
            "files": category_files[i:i+shard_size],
            "rule_file": category.rule_file,
            "knowledge_file": category.knowledge_file,
        })
    return shards
```

### 4. 並列度の制限

- 1 メッセージ内の Agent ツール並列発行上限: **8 並列**
- カテゴリ shard 合計 > 8 の場合は複数フェーズに自然分割

例: SQLi 5 shards + OS コマンド 3 shards + トラバーサル 2 shards = 10 shards
→ Phase 1 を 2 サブフェーズに分割 (前半 8 並列、後半 2 並列)

## 想定例

20 ファイルの小さいリポジトリ:
```
Phase 1: 01-sql-injection × 2 shards + 02-os-command-injection × 1 + 03-directory-traversal × 1 = 4 並列
```

200 ファイルの大きいリポジトリ:
```
Phase 1 (SQLi 20 shards) を 3 サブフェーズに分割 (8 + 8 + 4)
```

## 制約

- ファイル数 0 のカテゴリは shard 化しない
- `--categories` で対象外のカテゴリも shard 化しない
- shard_id は 1 始まり
