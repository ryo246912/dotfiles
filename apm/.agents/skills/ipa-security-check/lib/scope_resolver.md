# Scope Resolver — 対象ファイル列挙ロジック

`/ipa-security-check` の引数を解釈し、検査対象ファイル一覧を作る。

## 入力

```yaml
paths: ["src/"]        # 引数で渡されたパス/glob 配列。空なら ["."]
diff_mode: false       # --diff が指定されたか
categories: [...]      # --categories で絞られたカテゴリ
```

## 出力

```yaml
files:
  - path: src/users.php
    language: php
    size_bytes: 4231
  - path: src/lib/db.java
    language: java
    size_bytes: 2980
  ...
```

## アルゴリズム

### 1. パス展開

- `paths` が空なら `["."]` を使う
- 各要素がディレクトリなら再帰的に走査
- 各要素が glob なら shell の `find` または Read で展開
- 各要素がファイルなら単独で対象

`--diff` の場合は以下に置き換え:

```bash
git diff --name-only main...HEAD -- '*.php' '*.java' '*.rb' '*.py' '*.js' '*.jsx' '*.ts' '*.tsx' '*.vue' '*.cs' '*.go' '*.conf' '*.xml' '*.yaml' '*.yml' '*.htaccess' '*.cshtml' '*.aspx' 'Dockerfile' 'nginx.conf'
```

### 2. 除外パターン

以下は常に除外:

```
node_modules/
vendor/
.git/
.next/
.nuxt/
dist/
build/
out/
target/
__pycache__/
.venv/
venv/
*.min.js
*.min.css
*.map
**/test/**         # ※ ユーザー指定があれば外す
**/tests/**
**/__tests__/**
**/spec/**
```

`.gitignore` も考慮 (`git check-ignore -v` で確認)。

### 3. 言語判定

| 拡張子 | language |
|---|---|
| `.php` | php |
| `.java`, `.jsp` | java |
| `.rb`, `.erb` | ruby |
| `.py` | python |
| `.js`, `.jsx` | javascript |
| `.ts`, `.tsx`, `.vue` | typescript |
| `.cs`, `.cshtml`, `.aspx` | csharp |
| `.go` | go |
| `.conf`, `.htaccess`, `nginx.conf` | webserver-config |
| `web.xml` | java-webapp-config |
| `*.yaml`, `*.yml` | yaml |
| `Dockerfile` | dockerfile |

判定不能な拡張子はスキップ。

### 4. ファイルサイズフィルタ

- 1 ファイル 500KB 超は除外 (生成物の可能性が高い)
- 0 バイトは除外

### 5. カテゴリ別マッピング

`--categories` で絞られている場合、関係ないファイル種別を除外:

| カテゴリ | 対象言語 |
|---|---|
| sqli, oscmd, traversal, xss, csrf, http-header, mail-header, bof, access-control, safe-sql | php, java, ruby, python, javascript, typescript, csharp, go |
| session | php, java, ruby, python, javascript, typescript, csharp, go (+ 設定ファイル) |
| clickjacking, ops, whc | すべて (特に webserver-config, dockerfile, yaml) |

## 実装メモ

Bash で `find` を使う場合の例:

```bash
find <paths> -type f \
  \( -name '*.php' -o -name '*.java' -o -name '*.jsp' -o \
     -name '*.rb' -o -name '*.erb' -o -name '*.py' -o \
     -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o \
     -name '*.tsx' -o -name '*.vue' -o -name '*.cs' -o \
     -name '*.cshtml' -o -name '*.aspx' -o -name '*.go' -o \
     -name '*.conf' -o -name '*.yaml' -o -name '*.yml' -o \
     -name '*.xml' -o -name 'Dockerfile' -o -name '*.htaccess' \) \
  -not -path '*/node_modules/*' \
  -not -path '*/vendor/*' \
  -not -path '*/.git/*' \
  -not -path '*/dist/*' \
  -not -path '*/build/*' \
  -not -name '*.min.js' \
  -not -name '*.min.css' \
  -size -500k
```

ファイル数を数えた上で、`lib/shard_planner.md` に渡す。
