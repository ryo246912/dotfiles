---
name: http_header_injection
ipa_document: 安全なウェブサイトの作り方 改訂第7版
ipa_section: "1.7 HTTPヘッダ・インジェクション"
ipa_page: "39-41"
ipa_url: https://www.ipa.go.jp/security/vuln/websecurity/http-header.html
cwe: CWE-113
---

# HTTP ヘッダ・インジェクション (HTTP Header Injection / HTTP Response Splitting)

## 出典

- 文書名: 安全なウェブサイトの作り方 改訂第7版（IPA, 2021年3月31日）
- 章節: 1.7 HTTP ヘッダ・インジェクション
- ページ: p.39〜41
- URL: https://www.ipa.go.jp/security/vuln/websecurity/http-header.html

## 概要

リクエストに対して出力する HTTP レスポンスヘッダのフィールド値を、外部から渡されるパラメータの値等を利用して動的に生成するウェブアプリケーションにおいて、ヘッダ出力処理に問題があると発生する脆弱性。

HTTP ヘッダは改行コード（CRLF, `\r\n`, `%0d%0a`）で区切られる構造を持つ。攻撃者が改行コードを含むパラメータを送り込むと、任意のヘッダフィールドや任意のレスポンスボディを注入できる。2 つの改行を含めれば、ヘッダとボディを区切って 1 リクエストに対して複数レスポンスを作り出すこともでき、これを **HTTP Response Splitting** と呼ぶ。

CWE-113 (Improper Neutralization of CRLF Sequences in HTTP Headers) に該当。

## 脅威・被害

| 区分 | 内容 |
|---|---|
| XSS 相当 | 任意のレスポンスボディを注入され、偽情報表示や任意スクリプト実行 |
| Cookie 操作 | `Set-Cookie` を注入され、任意の Cookie を被害者ブラウザに保存（セッション固定攻撃等） |
| キャッシュ汚染 | 複数レスポンスに分割し、リバースプロキシ等にキャッシュさせて広範囲・永続的なウェブページ改ざん |
| リダイレクト悪用 | Location ヘッダ書き換えによる任意 URL への誘導（フィッシング） |

特にキャッシュ汚染は影響が広く永続的になりやすい。

## 発生原因

外部入力をそのままレスポンスヘッダのフィールド値に埋め込むコードが原因。

- `Location` ヘッダ: リダイレクト先 URL をパラメータから取得して直接埋め込む
- `Set-Cookie` ヘッダ: 名前等の入力値をそのまま Cookie 値に使う
- 任意のカスタムヘッダに入力をそのまま出力

入力に CR (`%0d`) / LF (`%0a`) / `\r\n` が含まれていると、ヘッダ行を区切る改行として解釈される。

## 根本的解決策

### 7-(i)-a ヘッダ出力 API を使用する

実行環境・言語に用意されているヘッダ出力用 API を使用する。多くのモダンな API は CRLF を検出して例外を投げる、もしくはエンコードする。

**注意**: 一部の実行環境では「ヘッダ出力 API が改行コードを適切に処理しない」既知脆弱性が存在する。該当する場合は修正パッチを適用する。

### 7-(i)-b 開発者による改行処理

ヘッダ出力 API が改行を適切に処理しない場合の代替:

- 改行の後に空白を入れて継続行（folded header）として処理する
- 改行コード以降の文字を削除する
- 改行が含まれていたらウェブページ生成処理を中止する

## 保険的対策

### 7-(ii) 入力全体の改行除去

外部からの入力すべてについて、改行コードを削除する（あるいは制御コード全体を削除する）。

**注意**: TEXTAREA 等で改行コードを含みうる入力を受け付ける必要がある場合、一律に削除すると業務動作に支障が出るため、適用範囲を慎重に設計する。

## NG コードパターン (検出対象)

### PHP
```php
// NG: パラメータをそのままヘッダに
header('Location: ' . $_GET['url']);
header('Set-Cookie: name=' . $_POST['name']);
```

### Java (Servlet)
```java
// NG
response.setHeader("Location", request.getParameter("url"));
response.addHeader("X-Custom", request.getParameter("v"));
```

### Perl
```perl
# NG
print "Location: $url\r\n\r\n";
```

### ASP.NET
```csharp
// NG
Response.Redirect(Request.QueryString["url"]);
Response.AppendHeader("X-Custom", Request.QueryString["v"]);
```

### Ruby / Rails
```ruby
# NG
redirect_to params[:url]
```

### Node.js (Express)
```js
// NG
res.setHeader('Location', req.query.url);
res.redirect(req.query.url);
```

## OK コードパターン (修正例)

### PHP
```php
$url = $_GET['url'];
if (preg_match('/[\r\n]/', $url)) {
    http_response_code(400); exit;
}
if (!preg_match('#^/[A-Za-z0-9_/.-]*$#', $url)) {
    http_response_code(400); exit;
}
header('Location: ' . $url);

// setcookie() は改行混入時に warning を出す（実装依存）
setcookie('name', $value, ['httponly' => true, 'secure' => true]);
```

### Java (Servlet)
```java
String url = request.getParameter("url");
if (url == null || url.contains("\r") || url.contains("\n")) {
    response.sendError(400); return;
}
response.sendRedirect(url);
```

### Perl
```perl
$url =~ s/[\r\n]//g;
print $cgi->redirect($url);
```

### ASP.NET
```csharp
var url = Request.QueryString["url"];
if (string.IsNullOrEmpty(url) || url.IndexOfAny(new[]{'\r','\n'}) >= 0) {
    Response.StatusCode = 400; return;
}
Response.Redirect(url);
```

### Ruby (Rails)
```ruby
url = params[:url].to_s
raise ActionController::BadRequest if url =~ /[\r\n]/
redirect_to url, allow_other_host: false
```

### Node.js (Express)
```js
const url = String(req.query.url || '');
if (/[\r\n]/.test(url)) return res.sendStatus(400);
res.redirect(url);
```

## 自動チェック観点

### 静的解析でカバー可能（○）

- 外部入力が `header()`, `setHeader()`, `addHeader()`, `setcookie()`, `Response.Redirect()`, `sendRedirect()`, `redirect_to` の引数に直接（または文字列連結で）渡されている
- `print "Header: $value\r\n"` のように生のヘッダを書き出している
- 入力に対する `\r` / `\n` / `%0d` / `%0a` チェックがない
- `Location` ヘッダにオープンリダイレクト相当の任意 URL を許容
- `Set-Cookie` の値・属性に外部入力を直接含めている

### 検出正規表現候補

```
# PHP
\bheader\s*\(\s*["'](Location|Set-Cookie|Refresh|Content-Disposition)[^"']*["']\s*\.\s*\$
\bheader\s*\(\s*[^)]*\$_(GET|POST|REQUEST|COOKIE)
\bsetcookie\s*\(\s*[^,]+,\s*\$_(GET|POST|REQUEST|COOKIE)

# Java Servlet
response\.(setHeader|addHeader|addCookie)\s*\([^)]*request\.getParameter\(
response\.sendRedirect\s*\(\s*request\.getParameter\(

# ASP.NET
Response\.(Redirect|AppendHeader|AddHeader)\s*\(\s*Request\.

# Ruby / Rails
redirect_to\s+params\[
response\.headers\[[^\]]+\]\s*=\s*params\[

# Node.js / Express
res\.(setHeader|writeHead|redirect)\s*\([^)]*req\.(query|body|params|headers)
res\.cookie\s*\([^,]+,\s*req\.(query|body|params|headers)

# Perl: 生 print でのヘッダ書き出し
print\s+["'][^"']*(Location|Set-Cookie):[^"']*\$\w+

# 入力中の CRLF パターン (検査ロジック側)
%0d%0a|%0D%0A|%0a%0d

# OK signal: 改行検査
/\[\\r\\n\]/.test\(|contains\(["']\\r["']\)|contains\(["']\\n["']\)
preg_match\s*\(\s*['"]/\[\\r\\n\]
```

## 関連ルール ID

- IPA-SWS-7-HHI-001: ヘッダ出力 API への外部入力直渡し（7-(i)-a 違反）
- IPA-SWS-7-HHI-002: 改行検出処理なし（7-(i)-b 違反 / 7-(ii) 違反）
- IPA-SWS-7-HHI-003: 生 print/echo でのヘッダ書き出し
- IPA-SWS-7-HHI-004: Set-Cookie に外部入力直接埋め込み
- IPA-SWS-7-HHI-005: Location にオープンリダイレクト相当の許容

## 参考

- IPA「安全なウェブサイトの作り方 - 1.7 HTTP ヘッダ・インジェクション」: https://www.ipa.go.jp/security/vuln/websecurity/http-header.html
- CWE-113: https://cwe.mitre.org/data/definitions/113.html
- 届出事例: JVNDB-2012-000099 Pebble / JVNDB-2012-000002 Cogent DataHub / JVNDB-2010-000050 Active! mail 6
