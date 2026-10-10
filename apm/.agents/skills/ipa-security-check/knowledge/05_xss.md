---
name: xss
ipa_document: 安全なウェブサイトの作り方 改訂第7版
ipa_section: "1.5 クロスサイト・スクリプティング"
ipa_page: "26-32"
ipa_url: https://www.ipa.go.jp/security/vuln/websecurity/cross-site-scripting.html
cwe: CWE-79
---

# クロスサイト・スクリプティング (Cross-Site Scripting / XSS)

## 出典

- 文書名: 安全なウェブサイトの作り方 改訂第7版（IPA, 2021年3月31日）
- 章節: 1.5 クロスサイト・スクリプティング
- ページ: p.26〜32
- URL: https://www.ipa.go.jp/security/vuln/websecurity/cross-site-scripting.html

## 概要

ウェブアプリケーションが、検索のキーワード表示画面、個人情報登録時の確認画面、掲示板、ウェブログ統計画面等、利用者からの入力内容や HTTP ヘッダの情報を処理し、ウェブページとして出力する際、ウェブページへの出力処理に問題がある場合、そのウェブページにスクリプト等を埋め込まれてしまう脆弱性。

XSS の影響は、ウェブサイト自体に対してではなく、そのウェブサイトのページを閲覧している利用者に及ぶ。

XSS は出力先（コンテキスト）によって以下のように分類される（自動チェックの観点で重要）。

- **HTML 要素内容（body 内テキスト）への出力**
- **HTML 属性値への出力**
- **URL 属性値（`href`, `src`, `action` 等）への出力**
- **JavaScript（`<script>` 要素内、イベントハンドラ属性内）への出力**
- **CSS（`<style>` 要素内、`style` 属性内）への出力**
- **DOM Based XSS**（クライアントサイドの `document.write` / `innerHTML` / `eval` 等で発生）

## 脅威・被害

1. **本物サイト上に偽のページが表示される**
   - 偽情報の流布、フィッシング詐欺
2. **ブラウザが保存している Cookie を取得される**
   - セッション ID なら利用者へのなりすまし、Cookie の個人情報の漏えい
3. **任意の Cookie をブラウザに保存させられる**
   - セッション ID 固定化攻撃に悪用される

## 根本的解決策

### 5-(i) ウェブページに出力する全ての要素にエスケープ処理を施す

- ウェブページを構成する全ての出力要素にエスケープ処理を行う
- エスケープ: `<`, `>`, `&` を `&lt;`, `&gt;`, `&amp;` に置換
- HTML タグの属性値は必ず `"`（ダブルクォート）で括り、属性値中の `"` を `&quot;` にエスケープ
- 「必須かどうかにかかわらず、テキストとして出力する全てに対してエスケープ処理を施す」
- `document.write` や `innerHTML` 等で動的に変更する場合も同様

### 5-(ii) URL を出力するときは、`http://` や `https://` で始まる URL のみを許可する

- 外部入力に依存する URL にはホワイトリスト方式を採用
- `javascript:` スキーム等のスクリプト実行型 URL を排除

### 5-(iii) `<script>...</script>` 要素の内容を動的に生成しない

- 外部入力に依存して `<script>` 要素の内容を生成すると、任意スクリプトを埋め込まれる
- 「危険スクリプトだけを排除する」ブラックリスト方式は避ける

### 5-(iv) スタイルシートを任意のサイトから取り込めるようにしない

- スタイルシートには `expression()` 等でスクリプトを記述できる

### 5-(vi) HTML 入力を許可する場合、構文解析木からスクリプトを含まない要素のみ抽出

- 掲示板等で HTML 入力を許可する場合、ホワイトリスト方式で許可要素のみ抽出
- 実装には複雑なコーディング・処理負荷が伴う

### 5-(viii) HTTP レスポンスヘッダの Content-Type に文字コード (charset) を指定

- `Content-Type: text/html; charset=UTF-8` のように明示
- 省略するとブラウザが推定し UTF-7 攻撃で `+ADw-script+AD4-...` が `<script>` として実行され得る
- W3C の優先順位: (1) HTTP ヘッダの charset、(2) `<meta http-equiv>`、(3) 外部リソース要素の charset。1 が望ましい

## 保険的対策

### 5-(v) 入力値の内容チェック

- 仕様に合わない入力は処理を進めず再入力させる
- 完全な対策にはならない

### 5-(vii) スクリプトに該当する文字列を排除（HTML 入力許可時）

- `<script>` や `javascript:` を `<xscript>`, `xjavascript:` のように無害な文字列へ「置換」（削除は危険）
- `java&#09;script:`、`java\nscript:` 等のバイパスがあるためブラックリスト単独では不十分

### 5-(ix) Cookie の HttpOnly 属性付与と TRACE メソッドの無効化

- `Set-Cookie: ...; HttpOnly`
- 古い環境では TRACE を無効化（Cross-Site Tracing 対策）

### 5-(x) ブラウザ機能を有効化するレスポンスヘッダを返す

- `X-XSS-Protection: 1; mode=block`
- `Content-Security-Policy`

## NG コードパターン (検出対象)

### HTML 要素内容への出力
- PHP: `echo $_GET[...]`, `<?= $var ?>` （htmlspecialchars を介していない）
- JSP: `<%= request.getParameter("x") %>`（`<c:out>` 不使用）
- ERB: `<%= raw ... %>`, `.html_safe`
- Twig/Blade: `{{ ... | raw }}`（Twig）, `{!! ... !!}`（Blade）
- Mustache/Handlebars: `{{{ ... }}}`（triple stash）
- Pug/Jade: `!= userInput`
- React: `dangerouslySetInnerHTML`
- Vue: `v-html`
- Angular: `[innerHTML]`, `bypassSecurityTrust*`

### 属性値への出力
- unquoted attribute への動的出力: `<input value=<%= ... %>>`
- イベントハンドラ属性（`onclick="..."`）への外部入力埋め込み

### URL 属性への出力
- `href`/`src`/`action`/`formaction` への動的出力でスキーム検証なし
- `javascript:` `data:` `vbscript:` を許容する処理

### JavaScript 内
- `eval(`, `Function(`, `setTimeout(<string>, ...)`, `setInterval(<string>, ...)`
- `document.write(`, `document.writeln(`
- `.innerHTML =`, `.outerHTML =`, `insertAdjacentHTML(`
- `location.hash` / `window.name` を未検証で DOM へ書き込み

### CSS 内
- 外部入力で `style` 属性／`<style>` 要素を動的生成
- ユーザ指定 URL の `<link rel="stylesheet" href="...">`

### HTTP ヘッダ
- `Content-Type` で `charset` を指定していない
- `Set-Cookie` に `HttpOnly` がない

## OK コードパターン (修正例)

### PHP
```php
echo htmlspecialchars($value, ENT_QUOTES | ENT_HTML5, 'UTF-8');

if (preg_match('/\Ahttps?:\/\//i', $url)) {
    echo '<a href="' . htmlspecialchars($url, ENT_QUOTES, 'UTF-8') . '">link</a>';
}
```

### Java
```java
// OWASP Java Encoder
out.println(Encode.forHtml(value));
out.println("<a href=\"" + Encode.forHtmlAttribute(url) + "\">");
out.println("<script>var x = '" + Encode.forJavaScript(value) + "';</script>");
```

```jsp
<c:out value="${param.q}" />
```

### Perl
```perl
use HTML::Entities;
print encode_entities($value, q{<>&"'});
```

### ASP.NET
```csharp
@Html.Encode(model.Value)
HttpUtility.HtmlEncode(value)
HttpUtility.JavaScriptStringEncode(value)
```

### Ruby on Rails
```erb
<%= user_input %>              <%# ERB は自動エスケープ %>
<%= sanitize html_text %>      <%# 許可タグのみ %>
```

### Node.js (Express)
```js
const escape = require('escape-html');
res.send(escape(value));

const u = new URL(input);
if (!['http:', 'https:'].includes(u.protocol)) throw new Error('invalid scheme');
```

### React / Vue
```jsx
// React: {value} は自動エスケープ
<div>{value}</div>
```

### レスポンスヘッダ
```
Content-Type: text/html; charset=UTF-8
Set-Cookie: name=value; Secure; HttpOnly; SameSite=Lax
Content-Security-Policy: default-src 'self'; script-src 'self'; object-src 'none'; base-uri 'self'
X-XSS-Protection: 1; mode=block
```

## 自動チェック観点

### 静的解析でカバー可能（◎）

- テンプレートの生出力タグ
- `innerHTML`/`document.write`/`eval` 系（DOM Based XSS）
- React の `dangerouslySetInnerHTML`、Vue の `v-html`、Angular の `[innerHTML]`/`bypassSecurityTrust*`
- `<script>` 要素内への変数埋め込み
- `Content-Type` で `charset` を指定していない箇所
- Cookie の `HttpOnly` 欠落

### 静的解析でカバーしにくい

- DOM Based XSS の複合経路（HTTP レスポンスに現れない）
- 複数ステップの reflection（DB 保存 → 別画面で出力）
- mXSS (mutation XSS)

### 検出正規表現候補

```
# PHP: エスケープなしの直接出力
\becho\s+\$_(GET|POST|REQUEST|COOKIE|SERVER)\b
<\?=\s*\$_(GET|POST|REQUEST|COOKIE|SERVER)

# PHP: htmlspecialchars 引数不足
\bhtmlspecialchars\s*\([^,)]+\)\s*;

# JSP: scriptlet による未エスケープ出力
<%=\s*(request\.|param\.|session\.).*?%>

# ERB / Rails: html_safe / raw
\.html_safe\b
\braw\s*\(

# React: dangerouslySetInnerHTML
dangerouslySetInnerHTML\s*=

# Vue: v-html
\bv-html\s*=

# Angular: innerHTML / bypassSecurityTrust
\[innerHTML\]\s*=
bypassSecurityTrust(Html|Script|Style|Url|ResourceUrl)\b

# DOM Based XSS
\.innerHTML\s*=
\.outerHTML\s*=
\binsertAdjacentHTML\s*\(
\bdocument\.write(ln)?\s*\(
\beval\s*\(
\bnew\s+Function\s*\(
\bsetTimeout\s*\(\s*["'`]
\bsetInterval\s*\(\s*["'`]
location\.(hash|search|href).*\.(innerHTML|outerHTML|src)

# URL スキーム検証なしで href / src に代入
\.(href|src|action|formaction)\s*=\s*[^;]+(location|input|param|query)
href\s*=\s*["']?javascript:
src\s*=\s*["']?javascript:

# 属性値の unquoted 出力
<[a-zA-Z][^>]*\s(value|href|src|alt|title)\s*=\s*<%=

# Content-Type charset 未指定
Content-Type:\s*text/html(?!.*charset)
header\s*\(\s*["']Content-Type:\s*text/html["']\s*\)

# Cookie HttpOnly 欠落
Set-Cookie:(?!.*HttpOnly)
```

#### 推奨パターンの検出（OK signal）

```
htmlspecialchars\s*\([^,]+,\s*ENT_QUOTES
Encode\.(forHtml|forHtmlAttribute|forJavaScript|forUriComponent)
HttpUtility\.(HtmlEncode|JavaScriptStringEncode|UrlEncode)
<c:out\s+value=
Content-Security-Policy
X-XSS-Protection:\s*1;\s*mode=block
charset=UTF-8
HttpOnly
```

### 出力先別チェックリスト

| 出力先 | 検出すべき構文 | 推奨対策 |
|---|---|---|
| HTML 本文 | `echo`, `print`, `<%= %>`, `{{{}}}`, `v-html`, `dangerouslySetInnerHTML` | HTML エスケープ |
| 属性値 | unquoted attribute, シングルクォート属性 | ダブルクォート＋`&quot;` エスケープ |
| URL 属性 | `href`/`src` への動的値 | スキームをホワイトリスト検証 |
| イベントハンドラ属性 | `onclick`, `onload` 等への外部入力 | 原則禁止／JS エスケープ |
| `<script>` 内 | scriptlet で JS 文字列生成 | JSON エンコード／JS エスケープ |
| CSS / `style` 属性 | 外部入力で CSS 生成、ユーザ指定の外部 CSS リンク | CSS 文脈エスケープ／許可しない |
| DOM 操作 | `innerHTML`, `document.write`, `eval` 系 | `textContent`, DOM API |
| HTTP ヘッダ | `Content-Type` charset 未指定、`Set-Cookie` HttpOnly/Secure 欠落 | 明示設定 |

## 関連ルール ID

- IPA-SWS-5-XSS-001: HTML 本文への未エスケープ出力（5-(i) 違反）
- IPA-SWS-5-XSS-002: URL 属性のスキーム未検証（5-(ii) 違反）
- IPA-SWS-5-XSS-003: `<script>` 要素内への動的変数埋め込み（5-(iii) 違反）
- IPA-SWS-5-XSS-004: CSS への外部入力／外部 CSS 動的取り込み（5-(iv) 違反）
- IPA-SWS-5-XSS-005: HTML サニタイザ未使用（5-(vi) 不実施）
- IPA-SWS-5-XSS-006: Content-Type charset 未指定（5-(viii) 違反）
- IPA-SWS-5-XSS-007: Cookie HttpOnly 属性なし（5-(ix) 違反）
- IPA-SWS-5-XSS-008: CSP / X-XSS-Protection 未設定（5-(x) 違反）
- IPA-SWS-5-XSS-009: DOM Based XSS 危険 API 使用 (`innerHTML`/`document.write`/`eval`)
- IPA-SWS-5-XSS-010: React `dangerouslySetInnerHTML`/Vue `v-html`/Angular `[innerHTML]`

## 参考

- IPA「安全なウェブサイトの作り方 - 1.5 XSS」: https://www.ipa.go.jp/security/vuln/websecurity/cross-site-scripting.html
- CWE-79: https://cwe.mitre.org/data/definitions/79.html
- W3C HTML 4.0.1 文字コード: http://www.w3.org/TR/html401/charset.html#h-5.2.2
- Content Security Policy Level 2: http://w3c.org/TR/CSP2/
- IPA テクニカルウォッチ「DOM Based XSS」レポート
