---
name: safe_sql_details
ipa_document: 安全なSQLの呼び出し方（「安全なウェブサイトの作り方」別冊）
ipa_section: "全章（第1〜5章 + 付録A）"
ipa_page: "1-40"
ipa_url: https://www.ipa.go.jp/security/vuln/websecurity/ug65p900000196e2-att/000017320.pdf
cwe: CWE-89
---

# 安全な SQL の呼び出し方（IPA 別冊）

## 出典

- 文書名: 安全なSQLの呼び出し方（「安全なウェブサイトの作り方」別冊）
- 版: 第1版 / 40ページ / 2010年3月18日
- 発行者: 独立行政法人 情報処理推進機構（IPA）
- 執筆者: 徳丸 浩、永安 佑希允、相馬 基邦、勝海 直人、高木 浩光（産業技術総合研究所）
- PDF URL: https://www.ipa.go.jp/security/vuln/websecurity/ug65p900000196e2-att/000017320.pdf
- 関連 URL: https://www.ipa.go.jp/security/vuln/websecurity.html

本ファイルは「安全な SQL の呼び出し方」全章を、自動チェック観点向けに統合・整理したもの。

---

## 1. SQL の構造とリテラル（第1〜2章）

### 1.1 SQL 文の構成要素

```sql
SELECT a,b,c FROM atable WHERE name='YAMADA' and age>=20
```

| 要素 | 例 |
|---|---|
| キーワード（予約語） | `SELECT`, `FROM`, `WHERE`, `AND` |
| 演算子など | `=`, `>=`, `,` |
| 識別子 | `a`, `b`, `c`, `atable`, `name`, `age` |
| リテラル | `'YAMADA'`, `20` |

### 1.2 リテラルの種類

- **文字列リテラル**: `'情報処理推進機構'`、`'052312'`、`'O''Reilly'`
- **数値リテラル**: `20`、`-17`、`0`、`3.14159`、`6.0221415E+23`
- **日時リテラル**: `DATE '2009-11-04'`、`TIME '13:59:26'`
- **論理値リテラル**

### 1.3 文字列リテラルのエスケープ

文字列リテラル中にシングルクォートが現れる場合、シングルクォートを重ねて表現するのが SQL の文法。

```sql
-- NG: 構文エラー
SELECT * FROM employee WHERE name = 'O'Reilly'

-- OK
SELECT * FROM employee WHERE name = 'O''Reilly'
```

エスケープが必要な文字は **データベースエンジンの種類や設定によって異なる**。

### 1.4 数値リテラル

数値リテラルはクォートしない。JIS X 3005 / ISO/IEC 9075 規格では、数値リテラルの次には記号・空白・コメントが続かなければならない。

```sql
-- 規格準拠
SELECT * FROM employee WHERE age >= 25--comment

-- 規格違反（ただし Microsoft SQL Server や PostgreSQL は受け入れる）
SELECT * FROM employee WHERE age >= 25and age <= 60
```

### 1.5 SQL インジェクションの原因

#### 文字列リテラルに対するインジェクション

```perl
$q = "SELECT * FROM atable WHERE id='$id'";
```

`$id` に `';DELETE FROM atable--` を与えると:
```sql
SELECT * FROM atable WHERE id='';DELETE FROM atable--'
```

#### 数値リテラルに対するインジェクション

```perl
$q = "SELECT * FROM atable WHERE id=$id";
```

`$id` に `0;DELETE FROM atable` を与えると:
```sql
SELECT * FROM atable WHERE id=0;DELETE FROM atable
```

### 1.6 安全な SQL 呼び出しの要件

- **文字列リテラルに対しては、エスケープすべき文字をエスケープする**
- **数値リテラルに対しては、数値以外の文字を混入させない**

### 1.7 SQL 呼び出し方の分類

| 方式 | 評価 |
|---|---|
| 文字列連結 + エスケープなし | 危険 |
| 文字列連結 + quote メソッド | DB 連動が正しいライブラリでは可。ただし数値型のサポート不十分な実装あり |
| 動的プレースホルダ | ライブラリの実装に依存。文字エンコーディング起因の脆弱性が発生し得る |
| 静的プレースホルダ | SQL 構文がバインド前に確定する原理的に最も安全な方式（**推奨**） |

---

## 2. バインド機構（第3章）

### 2.1 静的プレースホルダ（Prepared Statement）

JIS/ISO 規格における「準備された文（Prepared Statement）」。

**仕組み**:

1. プレースホルダ記号 `?` のままの SQL 文を、DB エンジン側に事前に送信
2. DB エンジン側で構文解析などを完了
3. SQL 実行時に、実際のパラメータの値だけを DB エンジンに送信
4. DB エンジン側でバインド処理

**セキュリティ上の利点（最も安全）**:

- SQL 文の構文が**バインド前に確定**しているため、後から SQL 構文が変化することがない
- パラメータの値がリテラルの外にはみ出す現象が起きない
- プレースホルダに渡す文字列をクォートして記述する必要がない（**シングルクォートのエスケープ処理も不要**）
- 数値リテラルもそのまま適切にバインドされる

→ **原理的に SQL インジェクションの脆弱性が生じない**

**注意事項**:

- DB エンジンやライブラリによってはサポートされていない場合がある
- ライブラリによっては `prepare` のような名称でも実体が動的プレースホルダになっているケースがあるため、設定（明示指定）に注意

### 2.2 言語別の静的プレースホルダ指定方法

| 環境 | 静的プレースホルダ指定 |
|---|---|
| Java + Oracle (ojdbc6) | 常に静的（指定不要） |
| Java + MySQL | 接続 URL に `useServerPrepStmts=true` |
| Perl + DBD::mysql | 接続文字列に `mysql_server_prepare=1` |
| PHP + MDB2 + PostgreSQL | 常に静的（指定不要） |
| ASP.NET + SQL Server | 常に静的（指定不要） |

### 2.3 動的プレースホルダ

プレースホルダ機能はあるが、バインド処理を**データベースエンジン側ではなく、アプリケーション側のライブラリ内で実行**する方式。

俗に「クライアントサイドのプリペアドステートメント」と呼ばれるが、JIS/ISO で規定された「準備された文」ではない。

**特徴**:

- プレースホルダを用いることで、文字列連結に比べてエスケープ漏れを防止できる
- バインド処理を実現するライブラリの実装によっては、**SQL 構文を変化させる SQL インジェクションを許してしまう脆弱な実装**の可能性は否定できない
- 特に、**文字エンコーディングの扱いが不適切な実装**では、Shift_JIS や EUC-JP 使用時に SQL インジェクション脆弱性が発生し得る（付録 A.3 / 旧 MySQL Connector/J 5.1.7 以前）

### 2.4 静的 vs 動的 比較表

| 比較項目 | 静的プレースホルダ | 動的プレースホルダ |
|---|---|---|
| バインド処理の場所 | DB エンジン | クライアント側ライブラリ |
| SQL 構文の確定タイミング | バインド前 | バインド後 |
| 実行効率 | 高い | やや劣る |
| エスケープ漏れリスク | なし | ライブラリ依存 |
| 文字エンコーディング起因の脆弱性 | 発生しない | 発生し得る |
| 構文として安全か | 原理的に安全 | 実装が正しければ安全 |
| 推奨度 | **最推奨** | 静的が使えない時のみ |

---

## 3. エスケープ処理（第4章 / 付録 A.1）

### 3.1 データベース別エスケープ対象文字

#### 標準（JIS/ISO 規格に準拠）

| エスケープ対象 | エスケープ方法 |
|---|---|
| `'` | `''` |

#### MySQL のデフォルト設定 / PostgreSQL のデフォルト設定

| エスケープ対象 | エスケープ方法 |
|---|---|
| `'` | `''`（`\'` でもよい） |
| `\` | `\\` |

シングルクォート以外に **バックスラッシュ `\`** がエスケープ用のメタ文字として解釈されるため、文字列リテラル中にバックスラッシュが含まれる場合は、バックスラッシュ自身のエスケープも必要。

#### バックスラッシュをメタ文字扱いしない設定

| DB | オプション | 効果 |
|---|---|---|
| MySQL | `NO_BACKSLASH_ESCAPES` | バックスラッシュをエスケープ用のメタ文字として扱わない |
| PostgreSQL | `standard_conforming_strings=on` | バックスラッシュをエスケープ用のメタ文字として扱わない |

### 3.2 バックスラッシュエスケープを怠った場合の脆弱性例

入力 `\';DELETE FROM atable--` に対してシングルクォートだけエスケープすると:

```
\'';DELETE FROM atable--
```

このまま SQL に渡すと:

```sql
SELECT * FROM atable WHERE a='\'';DELETE FROM atable--'
```

`\'` が「シングルクォートのエスケープ」と見なされ、続くシングルクォートで文字列リテラルが終端し、`;DELETE` 以降がリテラル外にはみ出して実行される。

### 3.3 quote メソッドの活用

| 言語/ライブラリ | 関数/メソッド |
|---|---|
| Perl DBI | `$dbh->quote(...)` |
| PHP Pear::MDB2 | `$db->quote($v, 'text')` |
| PHP PDO | `$pdo->quote(...)` |

#### Pear::MDB2 quote メソッドの戻り値例

| データ | 型指定 | 戻り値 |
|---|---|---|
| `abc` | `'text'` | `'abc'` |
| `O'Reilly` | `'text'` | `'O''Reilly'` |
| `-123` | `'decimal'` | `-123` |
| `123abc` | `'decimal'` | `123` |
| `-123` | `'integer'` | `-123` (整数型) |
| `123abc` | `'integer'` | `123` (整数型) |

非数値文字を含む入力は、数値部分のみが抽出されて返るため、SQL 構文エラー＆SQL インジェクションを防止できる。

### 3.4 quote メソッドが正しく動作しないケース（注意）

- **Perl + DBD::mysql の quote メソッド（数値型指定）**: 入力文字列が数値として妥当かのチェックを行わず、数値変換もせず、**入力文字列をそのまま返す**。SQL インジェクション対策として使用できない。
  ```perl
  $dbh->quote("1 or 1=1", SQL_INTEGER); # → "1 or 1=1" を返す（NG）
  ```
- **Perl + DBD::PgPP (Pure Perl PostgreSQL driver) バージョン 0.08**: 動的プレースホルダと quote メソッドで、データベースエンジンの種類や設定に連動したエスケープが行われない。

### 3.5 識別子（テーブル名・カラム名・ソート順）の動的組み立て

本書には識別子の動的組み立てについての**専用節は無い**。ただし以下の重要な前提が読み取れる:

- 本書の「リテラル」「プレースホルダ」「quote メソッド」は **値（リテラル）** に対する仕組みであり、**識別子には適用できない**
- 識別子を動的に組み立てる必要がある場合、プレースホルダもエスケープ関数も使用できないため、**ホワイトリスト方式で検証することが必須**

#### 推奨実装

```php
// PHP: カラム名のホワイトリスト検証
$allowed_columns = ['id', 'name', 'created_at'];
$order_col = in_array($_GET['order'], $allowed_columns, true)
    ? $_GET['order']
    : 'id';
$sql = "SELECT * FROM users ORDER BY $order_col";
```

#### 危険な実装

```php
// NG
$sql = "SELECT * FROM users ORDER BY " . $_GET['order'];

// NG: プレースホルダは識別子には効かない
$stmt = $pdo->prepare("SELECT * FROM users ORDER BY ?");
$stmt->execute([$_GET['order']]);
```

### 3.6 LIKE 述語のエスケープ

```sql
-- ANSI 標準: ESCAPE 句で明示
SELECT * FROM atable WHERE name LIKE '50!%' ESCAPE '!'
```

### 3.7 エスケープ処理の落とし穴サマリ

| 落とし穴 | 対策 |
|---|---|
| シングルクォートのみエスケープし、バックスラッシュをエスケープしない | DB エンジンの設定に応じて両方をエスケープ。`quote` メソッドを使う |
| バックスラッシュ不要環境で `\\` にエスケープし、二重 `\` が DB に格納される | DB エンジンの設定を確認 |
| 数値リテラルを文字列としてエスケープのみ実施 | 数値はキャスト/型検証で混入させない |
| `addslashes()` 等の言語汎用エスケープ関数を使う | DBMS 連動の `quote` / `mysqli_real_escape_string` 等を使う |
| Shift_JIS 環境で多バイト文字の2バイト目に `0x5C` を含む場合の誤エスケープ | UTF-8 にする・DBMS 連動のエスケープ関数を使う |
| 識別子（テーブル名・カラム名）にエスケープ関数を適用 | ホワイトリスト検証 |

---

## 4. 言語別・DB 別実装ガイド（第5章）

### 調査結果サマリ表

| 観点 | Java + Oracle | PHP + MDB2 + PostgreSQL | Perl + MySQL | Java + MySQL | ASP.NET + SQL Server |
|---|---|---|---|---|---|
| プレースホルダの実装 | 静的のみ | 静的のみ | 静的または動的 | 静的または動的 | 静的のみ |
| 動的プレースホルダの処理 | - | - | 正しく処理される | 正しく処理（古いバージョン除く） | - |
| quote 処理（文字列） | - | 正しく処理される | 正しく処理される | - | - |
| quote 処理（数値） | - | 正しく処理される | **正しく処理されない** | - | - |
| 文字エンコーディング | UTF-8 固定 | 指定可能 | UTF-8 を明示可能 | 指定可能 | UTF-16 固定 |

### 4.1 Java + Oracle（OK 例）

```java
String sql = "SELECT * FROM atable WHERE name=?";
PreparedStatement stmt = con.prepareStatement(sql);
stmt.setString(1, param);
ResultSet rs = stmt.executeQuery();
```

### 4.2 PHP + Pear::MDB2 + PostgreSQL（OK 例）

```php
$db = MDB2::connect('pgsql://username:password@hostname/dbname?charset=utf8');
$stmt = $db->prepare('SELECT * FROM atable WHERE name=? and num=?',
                     array('text', 'integer'),
                     array('text', 'text', 'integer'));
$rs = $stmt->execute(array($name, $num));
```

ポイント:

1. `charset=utf8` を指定（Shift_JIS は SQL インジェクション問題が発生しやすいため避ける）
2. プレースホルダの**型を指定**する

### 4.3 Perl + DBI + DBD::mysql + MySQL（OK 例）

```perl
my $db = DBI->connect(
    'DBI:mysql:database=xxxx;host=xxxx;mysql_server_prepare=1;mysql_enable_utf8=1',
    'xxxx', 'xxxx');
my $sql = 'SELECT * FROM antable WHERE num=? AND name=?';
my $sth = $db->prepare($sql);
$sth->bind_param(1, $num, SQL_INTEGER);
$sth->bind_param(2, $name, SQL_VARCHAR);
my $rt = $sth->execute();
```

ポイント:

1. `mysql_server_prepare=1` で静的プレースホルダを指定
2. `mysql_enable_utf8=1` で UTF-8 統一
3. `bind_param` で型を明示する

### 4.4 Java + JDBC (MySQL Connector/J) + MySQL（OK 例）

```java
String url = "jdbc:mysql://HOSTNAME/DBNAME"
    + "?user=USERNAME&password=PASSWORD"
    + "&useUnicode=true&characterEncoding=utf8&useServerPrepStmts=true";
Connection con = DriverManager.getConnection(url);
PreparedStatement stmt = con.prepareStatement("SELECT * FROM atable WHERE name=?");
stmt.setString(1, param);
```

接続 URL の重要パラメータ:

| パラメータ | 説明 |
|---|---|
| `useUnicode=true` | Unicode を使用 |
| `characterEncoding=utf8` | 接続の文字エンコーディングを UTF-8 に |
| `useServerPrepStmts=true` | 静的プレースホルダ（サーバサイド）を使用 |

### 4.5 ASP.NET + ADO.NET + Microsoft SQL Server（OK 例）

```vb
sqlStr = "select * from aTable where name=@s1"
dbcmd = New SqlCommand(sqlStr, dbcon)
Dim p1 As SqlParameter = New SqlParameter("@s1", param)
dbcmd.Parameters.Add(p1)
```

---

## 5. 文字エンコーディングの注意点（付録 A.2〜A.5）

### 5.1 Shift_JIS による SQL インジェクション（付録 A.2）

入力 `表';DELETE FROM atable--` の `表` (0x95 0x5C) が、文字エンコーディングを考慮しないエスケープで `0x5C` がバックスラッシュとして解釈され、Shift_JIS 解釈で:

```sql
SELECT * FROM atable WHERE a='表\'';DELETE FROM atable--'
```

`\'` が「シングルクォートのエスケープ」と解釈され、SQL インジェクションが成立。

**対策**:

- データベースエンジン、ライブラリ、プログラミング言語の文字列処理が文字エンコーディングを正しく扱えるものを使用
- **Shift_JIS の使用を避ける**

### 5.2 Unicode による SQL インジェクション（付録 A.3 / JVN#59748723）

**MySQL Connector/J 5.1.7 以前** で、以下の条件で SQL インジェクションが発生:

- MySQL Connector/J 5.1.7 以前
- 接続文字エンコーディングが **Shift_JIS あるいは EUC-JP**
- **動的プレースホルダ**を使用

`¥'or 1=1#` をバインドすると Unicode → Shift_JIS 変換で `¥` (U+00A5) が `\` (0x5C) に変換され、`\\'or 1=1#` として生成された SQL がインジェクション成立。

**対策（一つ以上、すべて推奨）**:

- 接続文字エンコーディングに **Unicode (UTF-8) を指定** (`characterEncoding=utf8`)
- **静的プレースホルダを使用** (`useServerPrepStmts=true`)
- MySQL Connector/J を **最新版に更新**

### 5.3 Oracle データベースを Unicode で作成（付録 A.4）

- Oracle はデータベース単位で文字エンコーディングを指定
- **既存データベースの文字エンコーディングは変更不可**
- デフォルト: `JA16SJISTILDE`（Shift_JIS）
- **推奨**: `AL32UTF8`（Unicode）

### 5.4 Microsoft SQL Server と文字コード（付録 A.5）

- Microsoft .NET 内部処理: UTF-16
- SQL Server テーブル文字列格納: サーバの動作環境のコードページ（日本語環境では CP932）
- Unicode 文字列の格納には `nchar`/`nvarchar` 型を使い、リテラルに `N'...'` 形式を前置

```sql
CREATE TABLE aTable (name NVARCHAR(30), city NVARCHAR(30));
INSERT INTO aTable VALUES (N'佐藤', N'横浜市');
```

### 5.5 文字エンコーディング推奨設定まとめ

| 環境 | 推奨設定 |
|---|---|
| 全般 | **Shift_JIS の使用を避ける**。UTF-8 / UTF-16 で統一 |
| PHP + PostgreSQL | DSN に `charset=utf8` |
| Perl + MySQL | 接続文字列に `mysql_enable_utf8=1` |
| Java + MySQL | 接続 URL に `useUnicode=true&characterEncoding=utf8` |
| Oracle DB | データベース作成時に `AL32UTF8` を指定 |
| Microsoft SQL Server | Unicode データは `nvarchar`/`nchar`、リテラルには `N'...'` |

---

## 6. データベースアカウントの権限

本書には専用節はないが、IPA「安全なウェブサイトの作り方」本編 1-(iv) の保険的対策。

### 一般原則（最小権限の原則）

- アプリが DB に接続する際のアカウントには、**業務上必要最小限の権限のみ付与する**
- `DROP TABLE`、`CREATE TABLE`、`GRANT` などの DDL/管理権限は通常付与しない
- 参照のみのアカウント、更新のみのアカウントなど、機能別にアカウントを分離する
- アプリケーションサーバと DB サーバ間の接続は信頼できるネットワーク経由とする

---

## 7. 自動チェック観点（重要・第6章相当）

### 7.1 検出すべき危険パターン（NG例）

#### 文字列連結による SQL 組み立て

**PHP**:
```php
// NG: 直接連結
$name = $_POST['name'];
$sql = "SELECT * FROM employee WHERE name='" . $name . "'";

// NG: 変数展開
$sql = "SELECT * FROM employee WHERE name='$name'";

// NG: sprintf
$sql = sprintf("SELECT * FROM employee WHERE id=%s", $_GET['id']);

// NG: PDO::prepare でも変数連結
$stmt = $pdo->prepare("SELECT * FROM users WHERE name='" . $name . "'");
```

**Perl**:
```perl
# NG: 文字列連結 (IPA本書 2.5.1)
$q = "SELECT * FROM atable WHERE id='$id'";

# NG: 数値リテラル文字列連結 (IPA本書 2.5.2)
$q = "SELECT * FROM atable WHERE id=$id";
```

**Java**:
```java
// NG: 文字列連結
String sql = "SELECT * FROM users WHERE name='" + name + "'";

// NG: Statement.executeQuery で動的 SQL
Statement stmt = con.createStatement();
ResultSet rs = stmt.executeQuery("SELECT * FROM users WHERE id=" + userId);
```

**Ruby**:
```ruby
# NG: 文字列展開
sql = "SELECT * FROM users WHERE name='#{params[:name]}'"

# NG (Rails): where 句に文字列展開
User.where("name = '#{params[:name]}'")
```

**C#**:
```csharp
// NG: 文字列補間
string sql = $"SELECT * FROM users WHERE name='{name}'";
```

#### quote / エスケープ関数の誤用

```php
// NG: addslashes は DB エンジン連動でない、Shift_JIS 問題あり
$name = addslashes($_POST['name']);
$sql = "SELECT * FROM users WHERE name='$name'";

// NG: 数値型に文字列用エスケープを適用
$id = mysqli_real_escape_string($conn, $_GET['id']);
$sql = "SELECT * FROM users WHERE id=$id";    // クォートしないため id=1 or 1=1 が通る

// NG: htmlspecialchars は SQL 用エスケープではない
$name = htmlspecialchars($_POST['name']);
```

```perl
# NG: DBD::mysql の quote (数値型) は入力をそのまま返す
$dbh->quote("1 or 1=1", SQL_INTEGER);
```

#### 動的プレースホルダ + Shift_JIS / EUC-JP

```java
// NG: 古い MySQL Connector/J + Shift_JIS + 動的プレースホルダ (JVN#59748723)
Connection con = DriverManager.getConnection(
    "jdbc:mysql://HOST/DB?useUnicode=true&characterEncoding=sjis");
// useServerPrepStmts が指定されておらず動的プレースホルダ
```

#### 識別子の直接埋め込み

```php
// NG: ORDER BY の列名を直接埋め込み
$sql = "SELECT * FROM users ORDER BY " . $_GET['sort'];

// NG: テーブル名を直接埋め込み
$table = $_GET['table'];
$sql = "SELECT * FROM $table";
```

### 7.2 推奨パターン（OK例）

**PHP (PDO)**:
```php
$stmt = $pdo->prepare('SELECT * FROM users WHERE name = :name AND age = :age');
$stmt->execute(['name' => $name, 'age' => $age]);
```

**PHP (mysqli)**:
```php
$stmt = $mysqli->prepare('SELECT * FROM users WHERE id = ? AND name = ?');
$stmt->bind_param('is', $id, $name);    // i=integer, s=string
$stmt->execute();
```

**Java**:
```java
PreparedStatement stmt = con.prepareStatement("SELECT * FROM atable WHERE name=?");
stmt.setString(1, name);
stmt.setInt(1, id);
```

**ASP.NET**:
```csharp
var cmd = new SqlCommand("SELECT * FROM users WHERE name=@name AND id=@id", conn);
cmd.Parameters.AddWithValue("@name", name);
cmd.Parameters.Add("@id", SqlDbType.Int).Value = id;
```

**Ruby**:
```ruby
User.where("name = ?", params[:name])
User.where(name: params[:name])
```

**識別子のホワイトリスト**:
```php
$allowed = ['id', 'name', 'created_at'];
$col = in_array($_GET['sort'], $allowed, true) ? $_GET['sort'] : 'id';
$sql = "SELECT * FROM users ORDER BY $col";
```

**数値キャスト**:
```php
$id = (int)$_GET['id'];
$sql = "SELECT * FROM users WHERE id=$id";
```

### 7.3 grep / 正規表現での検出ルール候補

#### PHP

```regex
# 変数展開 + シングルクォート
"\bSELECT\b.*'.*\$\w+.*'.*"

# 文字列連結による SQL 組み立て
"\"[^\"]*(SELECT|INSERT|UPDATE|DELETE)[^\"]*\"\s*\.\s*\$\w+"

# クエリ系関数への文字列連結引数
"(mysql_query|mysqli_query|pg_query)\s*\([^)]*\.\s*\$"

# addslashes / htmlspecialchars を経由した SQL 構築
"addslashes\s*\(.*\).*(SELECT|INSERT|UPDATE|DELETE)"

# PDO::prepare 引数に文字列連結
"->prepare\s*\(\s*\"[^\"]*\"\s*\.\s*\$"
```

#### Perl

```regex
# 文字列リテラル内変数展開（SQL 様）
"\"[^\"]*(SELECT|INSERT|UPDATE|DELETE)[^\"]*\\\$\w+"

# qq{...} 内変数展開
"qq[{(\[].*?(SELECT|INSERT|UPDATE|DELETE).*?\\\$\w+"

# $dbh->do / prepare に変数連結
"->(do|prepare)\s*\(.*\.\s*\\\$"

# quote(..., SQL_INTEGER) - DBD::mysql で危険
"->quote\s*\([^,]+,\s*SQL_INTEGER\s*\)"
```

#### Java

```regex
# SQL 文字列 + 変数連結
"\"[^\"]*(SELECT|INSERT|UPDATE|DELETE)[^\"]*\"\s*\+\s*\w+"

# Statement.executeQuery / executeUpdate に動的 SQL
"Statement\s+\w+\s*=\s*[^;]*createStatement"
"\.executeQuery\s*\(\s*\"[^\"]*\"\s*\+"

# String.format で SQL
"String\.format\s*\(\s*\"[^\"]*(SELECT|INSERT|UPDATE|DELETE)"

# 古い MySQL Connector/J で危険な設定
"characterEncoding=sjis"
"characterEncoding=ujis"
"jdbc:mysql:(?!.*useServerPrepStmts=true)"
```

#### Ruby

```regex
# 文字列展開 #{} を含む SQL 文字列
"\"[^\"]*(SELECT|INSERT|UPDATE|DELETE)[^\"]*#\{"

# Rails where に文字列展開
"\.where\s*\(\s*\"[^\"]*#\{"

# raw / unsafe な execute
"\.execute\s*\(\s*\"[^\"]*#\{"
"\.find_by_sql\s*\(\s*\"[^\"]*#\{"
```

#### C# / VB.NET

```regex
# C# 文字列連結
"\"[^\"]*(SELECT|INSERT|UPDATE|DELETE)[^\"]*\"\s*\+\s*\w+"

# C# 文字列補間
"\$\"[^\"]*(SELECT|INSERT|UPDATE|DELETE)[^\"]*\{"

# SqlCommand コンストラクタに動的 SQL
"new\s+SqlCommand\s*\(\s*\"[^\"]*\"\s*\+"
```

#### 識別子直接埋め込み（全言語共通）

```regex
# ORDER BY に変数
"ORDER\s+BY\s+[\$\#\{\+]"
"ORDER\s+BY\s+\"\s*\+"
"ORDER\s+BY\s*\"\s*\.\s*\$"

# FROM 句にユーザ入力
"FROM\s+\"\s*\.\s*\$"
"FROM\s+\$\w+"
"FROM\s+\"\s*\+\s*\w+"
```

### 7.4 自動チェックのレビューチェックリスト

#### SQL 構築箇所の検出

- [ ] `SELECT`/`INSERT`/`UPDATE`/`DELETE` を含む文字列リテラルがあるか
- [ ] その文字列に変数連結（`+`/`.`/`&`/`#{}`/`$var`）があるか
- [ ] その変数がユーザ入力（リクエストパラメータ・Cookie・ヘッダ等）由来か

#### プレースホルダ使用の確認

- [ ] `prepare()` / `PreparedStatement` / `SqlCommand` 等を使用しているか
- [ ] プレースホルダ位置に変数連結していないか
- [ ] `setString`/`setInt`/`bind_param` 等で型を明示しているか
- [ ] MySQL Connector/J の場合、`useServerPrepStmts=true` が設定されているか
- [ ] Perl + MySQL の場合、`mysql_server_prepare=1` が設定されているか

#### 識別子の動的組み立て

- [ ] テーブル名・カラム名・ソート順を変数化している箇所があるか
- [ ] その箇所でホワイトリスト検証を行っているか

#### 文字エンコーディング

- [ ] DB 接続文字列で `characterEncoding=sjis`/`ujis` 等の指定がないか
- [ ] PHP の `php.ini` 内部エンコーディングが Shift_JIS になっていないか
- [ ] 接続エンコーディングと内部エンコーディングが一致しているか
- [ ] DB 全体（Oracle: `AL32UTF8`、MySQL/PostgreSQL: UTF-8）が Unicode で統一されているか

#### quote/エスケープ関数の使用

- [ ] `addslashes`、`htmlspecialchars` を SQL エスケープとして使っていないか
- [ ] 数値リテラル箇所で文字列用 quote/エスケープのみ使用していないか
- [ ] Perl の `DBD::mysql` で `quote($v, SQL_INTEGER)` を使っていないか

### 7.5 検出シグネチャ優先度

| 優先度 | パターン | 理由 |
|---|---|---|
| Critical | SQL 文字列リテラル + ユーザ入力変数の連結 | 典型的な SQL インジェクション |
| Critical | 識別子(`ORDER BY` 等)へのユーザ入力直接埋め込み | プレースホルダで防げない |
| High | `Statement.executeQuery/Update` に動的 SQL | `PreparedStatement` を使うべき |
| High | MySQL Connector/J で `characterEncoding=sjis` または未指定 + 動的プレースホルダ | JVN#59748723 |
| High | Perl DBD::mysql で `$dbh->quote($v, SQL_INTEGER)` | 数値検証されない |
| Medium | `addslashes`、`htmlspecialchars` を SQL エスケープに使用 | DB 連動でない・安全でない |
| Medium | `prepare` 使用だが SQL 自体に文字列連結 | プレースホルダの意味がない |
| Low | エンコーディング不一致 | 副次的な脆弱性の温床 |
| Low | DB アカウントの過剰権限 | 影響範囲拡大要因 |

### 7.6 False Positive を避けるための補助判定

- 文字列リテラル中の `'` がペアになっているか確認（プレースホルダ `?` か検証）
- 連結される変数が定数 / リテラル / 関数の戻り値の場合は無視できる
- ORM/クエリビルダの内部実装（Rails の `Arel`、Django の `QuerySet` 等）は無視する
- テストコード / マイグレーション / シード等は除外可
- 環境変数や設定ファイル値（DB 接続文字列のホスト名等）は影響を受けない

---

## 関連ルール ID（safe_sql_details 専用補足）

- IPA-SSC-SAFESQL-001: 動的プレースホルダ + characterEncoding=sjis/ujis (JVN#59748723)
- IPA-SSC-SAFESQL-002: Perl DBD::mysql で quote($v, SQL_INTEGER) の使用
- IPA-SSC-SAFESQL-003: PHP MDB2 で型指定なしの prepare
- IPA-SSC-SAFESQL-004: Perl で mysql_server_prepare=0 (動的のみ)
- IPA-SSC-SAFESQL-005: Java MySQL で useServerPrepStmts=true 未指定
- IPA-SSC-SAFESQL-006: 識別子（テーブル/カラム/ORDER BY）への入力直接埋め込み
- IPA-SSC-SAFESQL-007: addslashes / htmlspecialchars を SQL エスケープに使用
- IPA-SSC-SAFESQL-008: 数値リテラルへの文字列用エスケープのみ
- IPA-SSC-SAFESQL-009: prepare 内 SQL 自体への文字列連結
- IPA-SSC-SAFESQL-010: DB 接続で Shift_JIS / EUC-JP 指定

## 参考

- IPA「安全な SQL の呼び出し方」 PDF: https://www.ipa.go.jp/security/vuln/websecurity/ug65p900000196e2-att/000017320.pdf
- IPA「安全なウェブサイトの作り方」: https://www.ipa.go.jp/security/vuln/websecurity.html
- JVN#59748723: MySQL Connector/J における SQL インジェクション脆弱性: http://jvn.jp/jp/JVN59748723/index.html
- マイクロソフト MSDN「Unicode データの使用」: http://msdn.microsoft.com/ja-jp/library/ms191200.aspx
