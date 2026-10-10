---
name: directory_traversal
ipa_document: 安全なウェブサイトの作り方 改訂第7版
ipa_section: "1.3 パス名パラメータの未チェック／ディレクトリ・トラバーサル"
ipa_page: "16-18"
ipa_url: https://www.ipa.go.jp/security/vuln/websecurity/parameter.html
cwe: CWE-22
---

# パス名パラメータの未チェック／ディレクトリ・トラバーサル (Path Traversal)

## 出典

- 文書名: 安全なウェブサイトの作り方 改訂第7版（IPA, 2021年3月31日）
- 章節: 1.3 パス名パラメータの未チェック／ディレクトリ・トラバーサル
- ページ: p.16〜18
- URL: https://www.ipa.go.jp/security/vuln/websecurity/parameter.html

## 概要

ウェブアプリケーションが外部からのパラメータでウェブサーバ内のファイル名を直接指定する実装に問題がある場合に発生する脆弱性。攻撃者がパラメータを改変して `../` や絶対パスを送り込むことで、本来公開すべきでないファイルを閲覧・改ざん・削除できてしまう。

CWE-22 (Improper Limitation of a Pathname to a Restricted Directory) に該当。

### 脆弱性が生じやすい場面

- ウェブページのテンプレートをファイルから読み込む処理
- HTML の hidden パラメータでサーバ内ファイル名を直接指定する設計
- ユーザ入力を指定ファイルへ直接書き込む処理

## 脅威・被害

| 区分 | 内容 |
|---|---|
| 情報漏えい | サーバ内ファイルの閲覧（個人情報・認証情報・ソースコード・設定ファイル等の漏えい） |
| 改ざん・破壊 | 設定ファイル・データファイル・プログラムソースコードの改ざん・削除 |

## 根本的解決策

### 3-(i)-a 外部パラメータでサーバ内ファイル名を直接指定する実装を避ける

仕様設計段階で、外部パラメータがファイル名そのものを示す設計を避ける。ファイル本体は ID（連番・UUID 等）で参照させ、実体パスはサーバ側で固定的にマッピングする。

### 3-(i)-b 固定ディレクトリ + basename 化

```
open(dirname + basename(filename))
```

1. あらかじめ固定ディレクトリ `dirname` を決め打ち
2. `basename()` 等の API を使い、入力からファイル名部分のみを抽出（パス区切り `/`, `\` を除去）
3. 結合したパスでファイルを開く

これにより、絶対パス指定と `../` トラバーサルの両方を回避できる。

## 保険的対策

### 3-(ii) アクセス権限の適切な管理

ウェブサーバプロセスがアクセスできるファイルを最小限に制限し、OS/ファイルシステムのパーミッションで意図しないファイル参照を拒否する。

### 3-(iii) ファイル名のチェック

入力パラメータから次のいずれかを検出したら処理を中止する:

- `/`
- `../`
- `..\`
- OS 固有のパス解釈でディレクトリ移動可能な文字列

#### URL エンコード・二重エンコード対策

- 1 重エンコード: `%2F` (`/`), `..%2F`, `..%5C`
- 2 重エンコード: `%252F`, `..%252F`, `..%255C`
- NULL バイト: `%00` （拡張子チェックバイパスに悪用）

## NG コードパターン (検出対象)

### PHP

```php
// NG: 入力直渡し
$content = file_get_contents($_GET['file']);
include($_GET['template']);
readfile($_REQUEST['file']);
```

### Java

```java
// NG
File f = new File(request.getParameter("file"));
FileInputStream fis = new FileInputStream(f);
```

### Python

```python
# NG
open(request.args.get('path'))
send_file(request.args.get('filename'))
```

### Ruby

```ruby
# NG
File.read(params[:file])
File.open(params[:name])
```

### Node.js

```js
// NG
fs.readFile(req.query.file, ...);
res.sendFile(userInput);
```

### .NET (C#)

```csharp
// NG
var content = File.ReadAllText(Request.QueryString["file"]);
```

## OK コードパターン (修正例)

### PHP

```php
$dir = '/var/www/templates/';
$file = basename($_GET['file']);        // パス区切りを除去
$path = realpath($dir . $file);          // 正規化
if ($path !== false && strpos($path, $dir) === 0) {
    $content = file_get_contents($path);
}
```

### Java

```java
Path base = Paths.get("/var/www/templates").toRealPath();
Path target = base.resolve(name).normalize().toRealPath();
if (!target.startsWith(base)) {
    throw new SecurityException();
}
```

### Perl

```perl
use File::Basename;
my $name = basename($input);
my $path = "/var/www/templates/$name";
open(my $fh, '<', $path) or die;
```

### C# (.NET)

```csharp
var baseDir = Path.GetFullPath(@"C:\app\templates\");
var name = Path.GetFileName(Request.QueryString["file"]);
var path = Path.GetFullPath(Path.Combine(baseDir, name));
if (!path.StartsWith(baseDir)) throw new SecurityException();
```

### Ruby

```ruby
base = '/var/www/templates'
name = File.basename(params[:file])
path = File.expand_path(File.join(base, name))
raise unless path.start_with?(base + '/')
File.read(path)
```

## 自動チェック観点

### 静的解析でカバー可能（◎）

- 外部入力が、ファイル open 系 API の引数（特に第1引数）に直接渡されている
- `include`, `require` (PHP) の引数に外部入力が混入
- `basename()` / `Path.GetFileName` / `File.basename` を経由していない
- ベースディレクトリと正規化済みパスの prefix 一致確認がない
- ファイル名チェックが「`../` だけ」しか見ていない（`..%2F`, `..%252F`, NUL バイト, `\` を考慮していない）

### 静的解析でカバーしにくい

- 内部 ID → ファイル名マッピングの整合性
- マッピングテーブルへの SQLi 経由の迂回

### 検出正規表現候補

```
# PHP: 入力直渡しのファイル系 API
\b(fopen|file_get_contents|file|readfile|file_put_contents|copy|unlink|include|include_once|require|require_once|SplFileObject)\s*\(\s*\$_(GET|POST|REQUEST|COOKIE|SERVER)\[

# Java
new\s+File\s*\(\s*request\.getParameter\(
new\s+FileInputStream\s*\(\s*request\.getParameter\(
\bPaths\.get\s*\(\s*request\.getParameter\(

# Python
\bopen\s*\(\s*(request\.|flask\.request\.|os\.environ|sys\.argv)
\b(send_file|send_from_directory)\s*\([^)]*request\.

# Ruby / Rails
\bFile\.(read|open|new|delete)\s*\(\s*params\[
\bsend_file\s*\(\s*params\[

# Node.js
\bfs\.(readFile|readFileSync|createReadStream|writeFile|writeFileSync|unlink)\s*\(\s*(req\.(query|body|params)|request\.)

# .NET
File\.(ReadAllText|ReadAllBytes|Open|OpenRead|WriteAllText|Delete)\s*\(\s*Request\.

# パスインジェクション系の入力検出
(\.\./|\.\.\\|%2e%2e%2f|%2e%2e/|\.\.%2f|\.\.%5c|%252e%252e%252f|%c0%ae%c0%ae/)

# OK signal: basename 系 API 使用
\b(basename|Path\.GetFileName|File\.basename|os\.path\.basename|path\.basename)\s*\(

# OK signal: 正規化 + prefix 確認
realpath\s*\(|toRealPath\s*\(|Path\.GetFullPath\s*\(|File\.expand_path\s*\(
(startsWith|StartsWith|start_with\?|strpos)\s*\(.*base
```

## 関連ルール ID

- IPA-SWS-3-PATH-001: ファイル系 API への入力直渡し（3-(i)-a 違反）
- IPA-SWS-3-PATH-002: basename / Path.GetFileName 等の未使用（3-(i)-b 違反）
- IPA-SWS-3-PATH-003: ベースディレクトリ prefix 確認なし
- IPA-SWS-3-PATH-004: `../` のみのチェック（エンコード/NULL バイト未対応 / 3-(iii) 不完全）
- IPA-SWS-3-PATH-005: `include`/`require` に外部入力（LFI 候補）

## 参考

- IPA「安全なウェブサイトの作り方 - 1.3 ディレクトリ・トラバーサル」: https://www.ipa.go.jp/security/vuln/websecurity/parameter.html
- CWE-22: https://cwe.mitre.org/data/definitions/22.html
- JVNDB CWE-22: https://jvndb.jvn.jp/ja/cwe/CWE-22.html
- 届出事例: JVNDB-2015-000006 シンクグラフィカ「ダウンロードログ CGI」 / JVNDB-2014-000054 Spring Framework / JVNDB-2013-000084 VMware ESX / ESXi
