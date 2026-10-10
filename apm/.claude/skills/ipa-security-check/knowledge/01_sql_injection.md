---
name: sql_injection
ipa_document: 安全なウェブサイトの作り方 改訂第7版
ipa_section: "1.1 SQLインジェクション"
ipa_page: "6-12"
ipa_url: https://www.ipa.go.jp/security/vuln/websecurity/sql.html
cwe: CWE-89
---

# SQL インジェクション (SQL Injection)

## 出典

- 文書名: 安全なウェブサイトの作り方 改訂第7版（IPA, 2021年3月31日）
- 章節: 1.1 SQLインジェクション
- ページ: p.6〜12
- URL: https://www.ipa.go.jp/security/vuln/websecurity/sql.html
- PDF: https://www.ipa.go.jp/security/vuln/websecurity/ug65p900000196e2-att/000017316.pdf
- 詳細は別冊「安全なSQLの呼び出し方」（`safe_sql_details.md` 参照）

## 概要

データベースと連携したウェブアプリケーションにおいて、利用者からの入力情報を基に SQL 文を組み立てる際、その組み立て方法に問題があると発生する脆弱性。

**発生原理**: ウェブアプリケーションで直接、文字列連結処理によって SQL 文を組み立てる際、特別な意味を持つ記号文字（`'`、`\`、`;`、`--` など）が適切にエスケープ処理されないまま埋め込まれると、攻撃者による入力値の改変によって SQL 文の意味（構文構造）が変化し、データベースに対して意図しない命令が実行される。

CWE-89 に該当。届出受付開始から2014年第4四半期までで、ウェブサイトの届出件数のおよそ 11% を占める、最も頻出する重大脆弱性の一つ。

## 脅威・被害

| 区分 | 内容 |
|---|---|
| 情報漏えい | データベースに蓄積された非公開情報（個人情報・認証情報等）の閲覧 |
| 改ざん・破壊 | データベース内情報の改ざん・消去（ウェブページ改ざん、パスワード変更、システム停止） |
| 認証回避 | 認証回避による不正ログイン（ログインユーザに許可された全操作が不正実行される） |
| サーバ乗っ取り | ストアドプロシージャ等を経由した OS コマンド実行による、システム乗っ取り・他システム攻撃の踏み台化 |

## 根本的解決策

### 1-(i)-a プレースホルダによる SQL 文組み立て（推奨）

**SQL 文の組み立ては全てプレースホルダで実装する**。

- **静的プレースホルダ（推奨）**: プレースホルダのまま SQL 文をコンパイルし、データベースエンジン側で値を割り当てる方式。ISO/JIS 規格では「準備された文（Prepared Statement）」。原理的に SQL インジェクションの可能性がなくなる。
- **動的プレースホルダ**: アプリ側の DB 接続ライブラリ内で値をエスケープしてプレースホルダにはめ込む方式。静的より劣る。

### 1-(i)-b 文字列連結による SQL 文組み立て時の対策（やむを得ない場合）

- 文字列型値の埋め込み: シングルクォートで囲み、`'` → `''`、`\` → `\\` 等、DB エンジン提供のリテラル生成専用 API を用いる
- 数値型値の埋め込み: 数値リテラルであることを保証する処理（数値型キャスト等）を実施
- 外部入力の影響を受ける値だけでなく、**SQL 文を構成するすべてのリテラル生成**で行う
- DB エンジンの種類・設定により処理が異なるため、それぞれに応じた実装が必須

### 1-(ii) パラメータへの SQL 文直接指定の禁止

hidden 等のパラメータに SQL 文を指定する実装は「論外」（IPA 明記）。

## 保険的対策

### 1-(iii) エラーメッセージの非表示

DB の種類・テーブル構造・実行エラーを起こした SQL 文等を含むエラーメッセージは、攻撃のヒントとなり、UNION-based / Error-based SQLi の結果表示の手段にもなる。ブラウザ上に表示させない。

### 1-(iv) データベースアカウントの権限最小化

アプリが DB 接続に使うアカウントの権限が必要以上に高いと被害が深刻化する。必要最小限の権限のみ付与する。

## NG コードパターン (検出対象)

### PHP

```php
// NG: 文字列連結
$pdo->query("SELECT * FROM users WHERE id = '" . $_GET['id'] . "'");

// NG: 変数展開
$sql = "SELECT * FROM users WHERE name='$name'";

// NG: PDO::prepare に文字列連結
$stmt = $pdo->prepare("SELECT * FROM users WHERE name='" . $name . "'");

// NG: addslashes だけで対処
$name = addslashes($_POST['name']);
$sql  = "SELECT * FROM users WHERE name='$name'";
```

### Java

```java
// NG: Statement + 文字列連結
Statement st = conn.createStatement();
st.executeQuery("SELECT * FROM users WHERE id = " + request.getParameter("id"));

// NG: String.format
String sql = String.format("SELECT * FROM users WHERE id=%s", id);
```

### Python

```python
# NG: f-string / % / .format
cursor.execute(f"SELECT * FROM users WHERE id={user_id}")
cursor.execute("SELECT * FROM users WHERE id=%s" % user_id)
cursor.execute("SELECT * FROM users WHERE id={}".format(user_id))
```

### Ruby / Rails

```ruby
# NG: 文字列補間
User.where("id = '#{params[:id]}'")
sql = "SELECT * FROM users WHERE id=" + params[:id]
```

### Node.js

```js
// NG: テンプレートリテラル / + 連結
db.query(`SELECT * FROM users WHERE id = ${userId}`);
connection.query("SELECT * FROM users WHERE id = " + req.query.id);
```

### .NET (C#)

```csharp
// NG: 文字列連結 / 補間
var cmd = new SqlCommand("SELECT * FROM Users WHERE Id = '" + id + "'", conn);
string sql = $"SELECT * FROM Users WHERE name='{name}'";
```

### 識別子 (テーブル名・カラム名・ORDER BY)

```php
// NG: 識別子を直接連結（プレースホルダは識別子には効かない）
$sql = "SELECT * FROM users ORDER BY " . $_GET['sort'];
```

### hidden パラメータに SQL 文（IPA 明記の論外パターン）

```html
<input type="hidden" name="sql" value="SELECT * FROM users WHERE ...">
```

## OK コードパターン (修正例)

### PHP (PDO)

```php
// OK: 静的プレースホルダ
$stmt = $pdo->prepare('SELECT * FROM users WHERE id = :id');
$stmt->bindValue(':id', $id, PDO::PARAM_INT);
$stmt->execute();
```

### Java (JDBC)

```java
// OK: PreparedStatement
PreparedStatement ps = conn.prepareStatement("SELECT * FROM users WHERE id = ?");
ps.setInt(1, id);
ResultSet rs = ps.executeQuery();
```

### Perl (DBI)

```perl
# OK: bind value
my $sth = $dbh->prepare('SELECT * FROM users WHERE id = ?');
$sth->execute($id);
```

### Ruby (ActiveRecord)

```ruby
# OK: ハッシュ条件 / 配列形式
User.where(id: params[:id])
User.where('id = ?', params[:id])
```

### ASP.NET (ADO.NET)

```csharp
// OK: 名前付きパラメータ
var cmd = new SqlCommand("SELECT * FROM Users WHERE Id = @id", conn);
cmd.Parameters.AddWithValue("@id", id);
```

### Python (DB-API)

```python
# OK: パラメータ化クエリ
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
```

### 識別子のホワイトリスト検証

```php
$allowed = ['id', 'name', 'created_at'];
$col = in_array($_GET['sort'], $allowed, true) ? $_GET['sort'] : 'id';
$sql = "SELECT * FROM users ORDER BY $col";
```

## 自動チェック観点

### 静的解析でカバー可能（◎）

- 文字列連結／文字列補間／テンプレートリテラル／f-string による SQL 構築
- `mysql_query`, `mysqli_query`, `pg_query`, `Statement#executeQuery`, `cursor.execute(... % ...)` 等のシンクに連結結果を渡している
- `addslashes`, `mysql_real_escape_string`, `htmlspecialchars` のみで対処（プレースホルダ未使用）
- ORM の `where` に raw SQL / 文字列補間
- hidden に SQL 文をクライアントに渡している
- `Statement.createStatement()` の使用（`PreparedStatement` を使うべき）
- MySQL Connector/J の `characterEncoding=sjis` / `ujis` + `useServerPrepStmts` 未指定（JVN#59748723）

### 静的解析でカバーしにくい

- 実行時に変数化されるテーブル名・ORDER BY カラム（taint analysis が必要）
- ストアドプロシージャ内の動的 SQL
- ORM の `raw()` / `execute()` 経由

### 検出正規表現候補

```
# 文字列連結による SQL 組み立て (汎用)
(SELECT|INSERT|UPDATE|DELETE|FROM|WHERE|VALUES)\b[^;]{0,200}([+.]|\|\|)\s*(\$|params|request|input|user|req\.)

# PHP: クエリ系関数に文字列連結
(mysql_query|mysqli_query|mysqli->query|pg_query|->query|->exec)\s*\([^)]*(\.|\${)[^)]*\)

# Python: cursor.execute with % or .format or f-string
\.execute\(\s*[fF]?["'].*(%s|\{|\+).*["'].*\)

# Java: Statement#execute* に + 連結
(executeQuery|executeUpdate|execute)\s*\([^)]*\+[^)]*\)
createStatement\s*\(\s*\)

# Ruby on Rails: where に文字列補間
\.where\(\s*["'][^"']*#\{

# Node.js: テンプレートリテラルや + で SQL 組立
(query|execute)\s*\(\s*`[^`]*\$\{
(query|execute)\s*\([^)]*\+[^)]*\)

# 危険なエスケープ関数のみへの依存
(addslashes|mysql_escape_string|mysql_real_escape_string)\s*\(

# hidden パラメータに SQL 文
<input[^>]+type=["']?hidden["']?[^>]+value=["'][^"']*(SELECT|INSERT|UPDATE|DELETE)\b

# OK signal: Prepared Statement / プレースホルダ
prepare\s*\(|PreparedStatement|bindValue|bindParam|Parameters\.Add|\:\w+
```

## 関連ルール ID

- IPA-SWS-1-SQLI-001: プレースホルダ未使用の SQL 構築（1-(i)-a 違反）
- IPA-SWS-1-SQLI-002: 文字列連結による SQL（1-(i)-b 違反 / `addslashes` 等のみ依存）
- IPA-SWS-1-SQLI-003: hidden に SQL 文（1-(ii) 違反）
- IPA-SWS-1-SQLI-004: DB エラーメッセージのブラウザ表示（1-(iii) 違反）
- IPA-SWS-1-SQLI-005: DB アカウントの過剰権限（1-(iv) 違反）
- IPA-SWS-1-SQLI-006: 識別子 (ORDER BY 等) への入力直接埋め込み
- IPA-SWS-1-SQLI-007: MySQL Connector/J で characterEncoding=sjis/ujis + 動的プレースホルダ
- IPA-SWS-1-SQLI-008: Perl DBD::mysql で `quote($v, SQL_INTEGER)` の使用

## 参考

- IPA「安全なウェブサイトの作り方 - 1.1 SQLインジェクション」: https://www.ipa.go.jp/security/vuln/websecurity/sql.html
- IPA「知っていますか？脆弱性 1. SQLインジェクション」: https://www.ipa.go.jp/security/vuln/vuln_contents/sql.html
- CWE-89: https://cwe.mitre.org/data/definitions/89.html
- JVNDB CWE-89: https://jvndb.jvn.jp/ja/cwe/CWE-89.html
- 詳細: 別冊「安全なSQLの呼び出し方」（`safe_sql_details.md` 参照）
