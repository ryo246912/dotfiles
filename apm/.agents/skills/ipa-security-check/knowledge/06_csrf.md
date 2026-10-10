---
name: csrf
ipa_document: 安全なウェブサイトの作り方 改訂第7版
ipa_section: "1.6 CSRF（クロスサイト・リクエスト・フォージェリ）"
ipa_page: "33-38"
ipa_url: https://www.ipa.go.jp/security/vuln/websecurity/csrf.html
cwe: CWE-352
---

# CSRF (クロスサイト・リクエスト・フォージェリ / Cross-Site Request Forgery)

## 出典

- 文書名: 安全なウェブサイトの作り方 改訂第7版（IPA, 2021年3月31日）
- 章節: 1.6 CSRF（クロスサイト・リクエスト・フォージェリ）
- ページ: p.33〜38
- URL: https://www.ipa.go.jp/security/vuln/websecurity/csrf.html

## 概要

CSRF の脆弱性とは、ログイン機能を備えたウェブサイトにおいて、**ログインした利用者からのリクエストについて、その利用者が意図したリクエストであるかどうかを識別する仕組みを持たない**ために、外部サイトを経由した悪意のあるリクエストを受け入れてしまう脆弱性。

攻撃者が罠サイト（あるいは罠メール／罠スクリプト）を用意することで、被害者が正規サイトにログイン中のブラウザを使って、被害者が意図しない処理（送金、設定変更、パスワード変更、退会など）を実行させられる。

### 攻撃が成立する前提条件

ブラウザがリクエスト時に**自動的に認証情報を付与する**方式で CSRF 攻撃が成立しやすい。

- Cookie を用いたセッション管理（秘密情報の追加検証なし）
- Basic 認証
- SSL（TLS）クライアント認証

### XSS との違い

XSS が「正規サイト上で攻撃者のスクリプトを実行させる」のに対し、CSRF は「**正規サイト外から、利用者のブラウザに正規サイトへリクエストを発行させる**」攻撃。

## 脅威・被害

### ログイン後の利用者のみが利用可能なサービスの悪用

- 不正な送金、利用者が意図しない商品購入、退会処理

### ログイン後の利用者のみが編集可能な情報の改ざん、新規登録

- 各種設定の不正な変更（管理者画面、パスワード、メールアドレス等）
- 掲示板への不適切な書き込み

### 特に被害が大きくなるサイト

- ネットバンキング、ネット証券、ショッピング、オークション
- 管理画面、会員専用サイト、日記サイト
- ネットワーク対応 HDD 等の組み込み製品のウェブ管理画面

## 根本的解決策

### 対策 A（6-(i)-a）: 秘密情報（CSRF トークン）の埋め込みと検証

「入力画面 → 確認画面 → 登録処理」のようなページ遷移において:

1. 確認画面として出力する際、秘密情報を `<input type="hidden">` パラメータに出力
2. 秘密情報の生成方法:
   - セッション ID を用いる方法
   - セッション ID とは別の「第2セッション ID」をログイン時に生成する方法
   - **暗号論的擬似乱数生成器（CSPRNG）** を用い、第三者に予測困難な値にする
3. 登録処理リクエスト時、hidden パラメータの値とサーバ側保持の秘密情報を比較
4. **HTTP メソッドは POST**（GET は Referer 経由で秘密情報が漏洩しうるため）

### 対策 B（6-(i)-b）: 処理実行直前の再認証

- 処理の実行前にパスワード認証（重要操作前の再入力）を行う
- 画面設計の仕様変更が必要

### 対策 C（6-(i)-c）: Referer ヘッダの確認

- Referer ヘッダが正しいリンク元かを確認し、正しい場合のみ処理を実行
- **Referer が確認できない（空）場合は処理を実行しない**
- 注意点:
  - 攻撃者がそのサイト上に罠を設置できる場合（投稿型サイト等）、Referer チェックは無効化されうる
  - Referer 送信を無効化している利用者がサイトを利用できなくなる不都合がある
  - Origin ヘッダの併用が推奨される

## 保険的対策

### 6-(ii) 重要操作後のメール通知

重要な操作（送金、パスワード変更、退会等）を行った際、登録済みメールアドレスに通知メールを自動送信する。
事後処理のため CSRF 攻撃そのものは防げないが、利用者が異変に気付くきっかけになる。
メール本文には、プライバシーに関わる重要情報（変更後のパスワード等）は含めない。

### SameSite Cookie 属性

セッション Cookie に `SameSite=Lax` または `SameSite=Strict` を設定。クロスサイトからのリクエストに Cookie が付与されにくくなる（トークン検証の代替にはならない）。

## NG コードパターン (検出対象)

### GET で状態変更
```html
<!-- NG -->
<a href="https://bank.example.com/transfer?to=attacker&amount=10000">送金</a>
<form method="GET" action="/delete">...</form>
```

### hidden トークン無しのフォーム
```html
<form action="/change_password" method="POST">
  <input type="password" name="new_password">
  <button type="submit">変更</button>
</form>
```

### サーバ側でトークン検証なし
```php
// NG
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    update_password($_SESSION['user_id'], $_POST['new_password']);
}
```

| 観点 | 危険コード例 |
|------|-------------|
| GET で状態変更 | `app.get('/delete', ...)` / `Route::get('/delete', ...)` / `@GetMapping("/transfer")` |
| トークン未埋め込み | POST フォーム内に `csrf_token` / `_token` / `__RequestVerificationToken` / `authenticity_token` / `_csrf` の hidden がない |
| サーバ側検証なし | `@ValidateAntiForgeryToken` / `protect_from_forgery` / CSRF middleware がない |
| 推測可能トークン | `md5($user_id)` / `time()` / `uniqid()` ベース |
| Referer/Origin 未確認 | `$_SERVER['HTTP_REFERER']` を一切参照していない |
| SameSite 未指定 | Cookie 発行で `samesite` が `None` / 未指定 |
| CSRF 保護の無効化 | Rails `skip_before_action :verify_authenticity_token`、Django `@csrf_exempt`、Laravel `$except`、Spring `http.csrf().disable()` |

## OK コードパターン (修正例)

### PHP (自前実装)
```php
session_start();
$token = bin2hex(random_bytes(32));
$_SESSION['csrf_token'] = $token;
?>
<form action="/confirm.php" method="POST">
  <input type="hidden" name="csrf_token"
         value="<?= htmlspecialchars($token, ENT_QUOTES, 'UTF-8') ?>">
  <input type="submit" value="登録">
</form>
```

```php
// 登録処理
if (!isset($_POST['csrf_token'], $_SESSION['csrf_token']) ||
    !hash_equals($_SESSION['csrf_token'], $_POST['csrf_token'])) {
    http_response_code(400);
    exit('CSRF token invalid');
}
unset($_SESSION['csrf_token']);
```

### Laravel
```blade
<form method="POST" action="/profile">
    @csrf
    <input type="text" name="name">
</form>
```

### Django
```html
<form method="post">
  {% csrf_token %}
</form>
```

### Spring Security
```java
// デフォルトで有効
http.csrf();
```

### ASP.NET MVC
```cshtml
<form asp-action="ChangeEmail" method="post">
    @Html.AntiForgeryToken()
</form>
```

```csharp
[HttpPost]
[ValidateAntiForgeryToken]
public IActionResult ChangeEmail(string email) { ... }
```

### Rails
```ruby
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
end
```

### Express (csurf)
```js
const csurf = require('csurf');
app.use(csurf());
```

## 自動チェック観点

### 静的解析でカバー可能（○）

- 重要処理（POST/PUT/DELETE）にトークン検証コードがない
- フレームワークの CSRF 保護が無効化されている（`csrf_exempt`/`http.csrf().disable()` 等）
- トークン生成が `md5(user_id)`/`time()`/`uniqid()` 等の推測可能値
- GET で状態変更（`app.get('/delete', ...)` 等）
- timing-safe でないトークン比較
- SameSite 属性未指定

### 静的解析でカバーしにくい

- トークン暗号強度の実測評価
- ランタイムのフレームワーク設定（条件付きで `csrf_exempt` 等）

### 検出正規表現候補

```bash
# 1. GET で状態変更しているエンドポイント
grep -rEn "app\.get\s*\([^)]*(delete|remove|update|transfer|withdraw|change|logout)" .
grep -rEn "Route::get\s*\([^)]*(delete|update|transfer|change)" .
grep -rEn "@GetMapping\s*\([^)]*(delete|update|transfer|change)" .
grep -rEn "<form[^>]*method=[\"']get[\"']" .

# 2. CSRF トークンの存在確認
grep -rEn "csrf_token|_token|__RequestVerificationToken|authenticity_token|_csrf|@csrf" .

# 3. CSRF 保護の無効化
grep -rEn "csrf_exempt|skip_before_action\s*:verify_authenticity_token" .
grep -rEn "IgnoreAntiforgeryToken|ValidateAntiForgeryToken\s*=\s*false" .
grep -rEn "VerifyCsrfToken.*\$except" .
grep -rEn "http\.csrf\(\)\.disable\(\)" .

# 4. 推測可能なトークン生成
grep -rEn "(csrf|token).*=\s*md5\s*\(" .
grep -rEn "(csrf|token).*=\s*uniqid\s*\(" .
grep -rEn "(csrf|token).*=\s*time\s*\(" .

# 5. timing-safe ではない比較
grep -rEn "csrf_token.*===?\s*\\\$_POST" .

# 6. SameSite 属性未指定
grep -rEn "setcookie\s*\(" . | grep -v -iE "samesite"

# 7. Referer / Origin チェック
grep -rEn "HTTP_REFERER|getHeader\\(\"Referer\\)|req\.headers\.referer" .
grep -rEn "HTTP_ORIGIN|getHeader\\(\"Origin\\)|req\.headers\.origin" .
```

## 関連ルール ID

- IPA-SWS-6-CSRF-001: POST/PUT/DELETE でトークン検証なし（6-(i)-a 違反）
- IPA-SWS-6-CSRF-002: 推測可能な CSRF トークン（4-(i) 違反相当）
- IPA-SWS-6-CSRF-003: CSRF 保護の無効化（`csrf_exempt` 等）
- IPA-SWS-6-CSRF-004: GET メソッドで状態変更
- IPA-SWS-6-CSRF-005: 重要操作前の再認証なし（6-(i)-b 不実施）
- IPA-SWS-6-CSRF-006: Referer/Origin チェックなし（6-(i)-c 不実施）
- IPA-SWS-6-CSRF-007: SameSite Cookie 未指定
- IPA-SWS-6-CSRF-008: 重要操作後のメール通知なし（6-(ii) 不実施）
- IPA-SWS-6-CSRF-009: timing-safe でないトークン比較

## Skill チェックリスト

- [ ] 重要処理（更新・削除・送金・設定変更）は POST/PUT/PATCH/DELETE で受け付けているか
- [ ] それらのエンドポイント全てで CSRF トークンが検証されているか
- [ ] CSRF トークンは CSPRNG で生成され、セッション毎にユニークか
- [ ] トークン比較は timing-safe（`hash_equals` / `MessageDigest.isEqual` 等）か
- [ ] フレームワークの CSRF 保護が `csrf_exempt` 等で無効化されていないか
- [ ] 重要操作前にパスワード再認証が行われているか
- [ ] セッション Cookie に `SameSite=Lax`/`Strict` が設定されているか
- [ ] 重要操作後にメール通知が行われているか
- [ ] Referer / Origin のチェックが実装されているか

## 参考

- IPA「安全なウェブサイトの作り方 - 1.6 CSRF」: https://www.ipa.go.jp/security/vuln/websecurity/csrf.html
- 高木浩光「CSRF」と「Session Fixation」の諸問題について: https://www.ipa.go.jp/security/vuln/websecurity/ug65p900000197by-att/20060228_3.pdf
- RFC2616 15.1.3（GET を副作用のある処理に使うべきでない）: https://www.ietf.org/rfc/rfc2616.txt
- JPCERT/CC「HTML5 Web アプリケーションのセキュリティ問題に関する調査報告書」: https://www.jpcert.or.jp/research/html5.html
- CWE-352: https://cwe.mitre.org/data/definitions/352.html
- 届出事例: JVNDB-2015-000012（ASUS 無線 LAN ルータ）, JVNDB-2014-000064（Web 給金帳）, JVNDB-2013-000097（EC-CUBE）
