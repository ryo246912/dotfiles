---
name: clickjacking
ipa_document: 安全なウェブサイトの作り方 改訂第7版
ipa_section: "1.9 クリックジャッキング"
ipa_page: "45-47"
ipa_url: https://www.ipa.go.jp/security/vuln/websecurity/clickjacking.html
cwe: "直接対応 CWE なし（補足: CWE-1021）"
---

# クリックジャッキング (Clickjacking / UI Redressing)

## 出典

- 文書名: 安全なウェブサイトの作り方 改訂第7版（IPA, 2021年3月31日）
- 章節: 1.9 クリックジャッキング
- ページ: p.45〜47 付近
- URL: https://www.ipa.go.jp/security/vuln/websecurity/clickjacking.html

## 概要

ログイン機能を設け、ログインしている利用者のみが使用可能な機能を提供しているウェブサイトにおいて、該当する機能がマウス操作のみで使用可能な場合、細工された外部サイトを閲覧し操作することにより、利用者が誤操作し、意図しない機能を実行させられる可能性がある脆弱性。

攻撃者は罠ページを作成し、正規のウェブサイトを `iframe`（または `frame`）で透過的に重ね、利用者を視覚的に騙して特定のボタン等をクリックさせる。

IPA「安全なウェブサイトの作り方」改訂第 7 版に直接対応する CWE はない（補足: 一般には CWE-1021 が用いられる）。

## 脅威・被害

ログイン後の利用者のみが利用可能なサービスの悪用：

- 利用者が意図しない情報発信（投稿等）
- 利用者が意図しない退会処理

ログイン後の利用者のみが編集可能な設定の変更：

- 利用者情報の公開範囲の意図しない変更

マウス操作のみで実行可能な処理が、利用者に紐づいた情報の公開範囲の変更処理等の場合、被害が大きくなるため特に注意が必要。

## 発生原因

直接的な「危険なコード」というより、**設計・サーバ設定上の不備**が原因となる。

- 外部ドメインからの `<iframe>` / `<frame>` による読み込みを制限していない（`X-Frame-Options` 等の未設定）
- マウス操作のみで重要な処理（投稿、退会、公開範囲変更、送金等）が実行可能（パスワード再入力や CAPTCHA がない）
- ログインセッションが長期間維持され、罠ページ訪問時にも自動的に有効になる

サンプル攻撃ページ（攻撃者側）:

```html
<style>
  iframe { opacity: 0.0; position: absolute; top: 0; left: 0; width: 800px; height: 600px; }
  .bait { position: absolute; top: 200px; left: 300px; }
</style>
<div class="bait">ここをクリック！</div>
<iframe src="https://victim.example.com/account/delete"></iframe>
```

## 根本的解決策

### 9-(i)-a HTTP レスポンスヘッダに `X-Frame-Options` を出力する

他ドメインのサイトからの `frame`/`iframe` 要素による読み込みを制限する。

| 設定値 | 動作 |
|---|---|
| `DENY` | すべてのウェブページにおいてフレーム内の表示を禁止 |
| `SAMEORIGIN` | 同一オリジンのウェブページのみフレーム内の表示を許可 |
| `ALLOW-FROM uri` | 指定したオリジンのウェブページのみフレーム内の表示を許可 |

注意点（原文）:

- Internet Explorer 7 は `X-Frame-Options` ヘッダに対応していないため、本対策を実施しても当該ブラウザでは攻撃を防げない
- `ALLOW-FROM` はブラウザによって適切に動作しない場合がある

### 9-(i)-b 処理を実行する直前のページで再度パスワードの入力を求める

再度入力されたパスワードが正しい場合のみ処理を実行。画面設計の仕様変更を要するため、画面設計を変えずに実装変更だけで対策する場合は 9-(i)-a を優先検討。

## 保険的対策

### 9-(ii) 重要な処理は、一連の操作をマウスのみで実行できないようにする

複雑な操作（文字列の入力、CAPTCHA 等）を要求することで攻撃の成功率を下げる。

## CSP frame-ancestors 指令（補足）

IPA 当該ページには `Content-Security-Policy: frame-ancestors` についての直接の記載はないが、現代のブラウザでは `X-Frame-Options` の後継として CSP の `frame-ancestors` 指令が標準となっており、両方を確認することが望ましい。

```
Content-Security-Policy: frame-ancestors 'none';
Content-Security-Policy: frame-ancestors 'self';
Content-Security-Policy: frame-ancestors 'self' https://trusted.example.com;
```

## NG コードパターン (検出対象)

- HTTP レスポンスに `X-Frame-Options` が設定されていない
- `X-Frame-Options: ALLOWALL` などの実効性のない値（仕様外）
- `Content-Security-Policy` に `frame-ancestors` ディレクティブが含まれていない
- `frame-ancestors *` のような任意ドメイン許可
- 重要な状態変更操作（POST/DELETE/PUT で副作用あり）に再認証や確認画面がない
- 大金移動／退会／設定変更などのフローがワンクリックで完結する画面設計
- アプリケーションコード／設定ファイル内に `X-Frame-Options` / `frame-ancestors` の設定が見当たらない

## OK コードパターン (修正例)

### Apache (httpd)
```apache
Header always set X-Frame-Options "SAMEORIGIN"
Header always set Content-Security-Policy "frame-ancestors 'self'"
```

### Nginx
```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header Content-Security-Policy "frame-ancestors 'self'" always;
```

### IIS (web.config)
```xml
<system.webServer>
  <httpProtocol>
    <customHeaders>
      <add name="X-Frame-Options" value="SAMEORIGIN" />
      <add name="Content-Security-Policy" value="frame-ancestors 'self'" />
    </customHeaders>
  </httpProtocol>
</system.webServer>
```

### Java Servlet / Spring Security
```java
response.setHeader("X-Frame-Options", "DENY");
response.setHeader("Content-Security-Policy", "frame-ancestors 'none'");
```

```java
// Spring Security
http.headers(headers -> headers
    .frameOptions(frame -> frame.deny())
    .contentSecurityPolicy(csp -> csp.policyDirectives("frame-ancestors 'self'"))
);
```

### PHP
```php
header('X-Frame-Options: SAMEORIGIN');
header("Content-Security-Policy: frame-ancestors 'self'");
```

### ASP.NET Core
```csharp
app.Use(async (ctx, next) => {
    ctx.Response.Headers["X-Frame-Options"] = "SAMEORIGIN";
    ctx.Response.Headers["Content-Security-Policy"] = "frame-ancestors 'self'";
    await next();
});
```

### Ruby on Rails
```ruby
# config/application.rb
config.action_dispatch.default_headers.merge!(
  'X-Frame-Options' => 'DENY',
  'Content-Security-Policy' => "frame-ancestors 'none'"
)
```

### Node.js / Express
```js
const helmet = require('helmet');
app.use(helmet.frameguard({ action: 'deny' }));
app.use(helmet.contentSecurityPolicy({
  directives: { frameAncestors: ["'none'"] }
}));
```

## 自動チェック観点

### 静的解析でカバー可能（○）

設定の **存在** 検査と **危険値** 検査の両方を行う。

### 検出正規表現候補

```
# 設定が存在することを確認（正の検出 / 欠落で警告）
X-Frame-Options:\s*(DENY|SAMEORIGIN|ALLOW-FROM\s+\S+)
Content-Security-Policy:[^\n]*frame-ancestors

# 危険値の検出
X-Frame-Options:\s*ALLOWALL
X-Frame-Options:\s*ALLOW-FROM\s+\*
frame-ancestors\s+[^;]*\*

# PHP
header\s*\(\s*['"]X-Frame-Options:\s*(DENY|SAMEORIGIN)
header\s*\(\s*['"]Content-Security-Policy:[^'"]*frame-ancestors

# Java Servlet / Spring
setHeader\s*\(\s*["']X-Frame-Options["']
\.frameOptions\s*\(
contentSecurityPolicy\s*\(

# Node Express / helmet
helmet\.frameguard\s*\(
frameAncestors

# Rails
default_headers.*X-Frame-Options
config\.action_dispatch\.default_headers

# .NET
Response\.Headers\.(Add|Append).*X-Frame-Options
Headers\["X-Frame-Options"\]

# Apache
Header\s+(always\s+)?set\s+X-Frame-Options
Header\s+(always\s+)?set\s+Content-Security-Policy[^\n]*frame-ancestors

# Nginx
add_header\s+X-Frame-Options
add_header\s+Content-Security-Policy[^;]*frame-ancestors

# IIS web.config
<add\s+name="X-Frame-Options"
<add\s+name="Content-Security-Policy"
```

### Skill 運用ロジック

1. 各レスポンス出力箇所に `X-Frame-Options` または CSP `frame-ancestors` が**必ず一つ以上**設定されているか確認
2. 設定値が `DENY` / `SAMEORIGIN` または `frame-ancestors 'none'` / `'self'` 等の制限的なものか確認
3. 重要処理（パスワード変更、退会、決済、公開設定変更等のエンドポイント）に対し、確認ステップ・再認証ロジックがあるか確認
4. ない場合は警告／推奨修正案を提示

## 関連ルール ID

- IPA-SWS-9-CJ-001: `X-Frame-Options` ヘッダ未設定（9-(i)-a 違反）
- IPA-SWS-9-CJ-002: `X-Frame-Options` が `ALLOWALL` 等の危険値
- IPA-SWS-9-CJ-003: CSP `frame-ancestors` ディレクティブ未設定
- IPA-SWS-9-CJ-004: `frame-ancestors *` 等の任意ドメイン許可
- IPA-SWS-9-CJ-005: 重要操作の再認証なし（9-(i)-b 不実施）
- IPA-SWS-9-CJ-006: マウスのみで重要操作が完結（9-(ii) 不実施）

## 参考

- IPA「安全なウェブサイトの作り方 - 1.9 クリックジャッキング」: https://www.ipa.go.jp/security/vuln/websecurity/clickjacking.html
- RFC 7034「HTTP Header Field X-Frame-Options」: http://www.ietf.org/rfc/rfc7034.txt
- MDN CSP frame-ancestors: https://developer.mozilla.org/docs/Web/HTTP/Headers/Content-Security-Policy/frame-ancestors
- IPA テクニカルウォッチ「クリックジャッキング」レポート
