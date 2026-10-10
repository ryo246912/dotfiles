---
name: session_management
ipa_document: 安全なウェブサイトの作り方 改訂第7版
ipa_section: "1.4 セッション管理の不備"
ipa_page: "19-25"
ipa_url: https://www.ipa.go.jp/security/vuln/websecurity/session-management.html
cwe: CWE-330 / CWE-384 / CWE-522 / CWE-614
---

# セッション管理の不備 (Session Management Flaws / Session Fixation)

## 出典

- 文書名: 安全なウェブサイトの作り方 改訂第7版（IPA, 2021年3月31日）
- 章節: 1.4 セッション管理の不備
- ページ: p.19〜25
- URL: https://www.ipa.go.jp/security/vuln/websecurity/session-management.html

## 概要

ウェブアプリケーションにおいて、利用者を識別するセッション ID の発行・管理に不備がある場合、攻撃者がセッション ID を不正に取得し、利用者になりすまして無認可アクセスを行える脆弱性。

主な攻撃手法：

- **セッション ID 推測攻撃**: 時刻情報など単純なアルゴリズムで生成されたセッション ID が予測可能
- **セッション ID 盗用攻撃**: Referer 送信機能による URL 露出、通信盗聴、XSS、ネットワーク傍受
- **セッション ID 固定化攻撃（Session Fixation）**: 攻撃者が用意したセッション ID を利用者に送り込む

## 脅威・被害

攻撃が成功すると、攻撃者は利用者になりすまし、その利用者本人に許可されている操作を不正に行うことが可能になる。

- **不正な金銭処理**: 不正な送金、利用者が意図しない商品購入、退会処理 等
- **情報の改ざん・登録**: 各種設定の不正な変更、掲示板への不適切な書き込み 等
- **非公開情報の不正閲覧**: 個人情報・ウェブメール・会員専用掲示板の不正閲覧 等

### 特に注意が必要なウェブサイト

金銭処理サイト（ネットバンキング、ショッピング、オークション）、非公開情報サイト、ログイン機能を持つサイト全般。

## 根本的解決策

### 4-(i) セッション ID を推測困難なものにする

セッション ID は生成アルゴリズムに **暗号論的擬似乱数生成器（CSPRNG）** を用いるなどして、予測困難なものにする。可能な限り自前実装は避け、**ウェブアプリケーションサーバ製品の既存セッション管理機能を利用**することが推奨される。

### 4-(ii) セッション ID を URL パラメータに格納しない

セッション ID は **Cookie に格納**するか、POST メソッドの **hidden パラメータ**に格納して受け渡す。

URL Rewriting（Cookie 拒否時の自動切り替え機能）は無効化することを検討する。

### 4-(iii) HTTPS 通信で利用する Cookie には secure 属性を加える

HTTPS 通信で利用する Cookie には `Secure` 属性を必ず付与する。HTTP 通信で Cookie を利用する場合は、HTTPS で発行する Cookie とは別のものを発行する。あわせて、`HttpOnly` 属性、`SameSite` 属性（`Lax`/`Strict`）も付与することが望ましい。

### 4-(iv)-a ログイン成功後に、新しいセッションを開始する

ログイン成功した時点から新しいセッションを開始する（新しいセッション ID でセッション管理する）。新しいセッションを開始する際には、既存のセッション ID を無効化する。これによりセッション固定化攻撃を防止する。

### 4-(iv)-b ログイン成功後に、既存セッション ID とは別の秘密情報を発行

セッション ID とは別に、ログイン成功時に秘密情報を作成して Cookie にセットし、全てのページでこの秘密情報と Cookie の値が一致することを確認する。秘密情報の生成には暗号処理（CSPRNG）を用いる。

4-(iv)-a を採用している場合、または「セッション ID をログイン前には発行せず、ログイン成功後に発行する」実装の場合は、4-(iv)-b は不要。

## 保険的対策

### 4-(v) セッション ID を固定値にしない

利用者ごとに固定の値ではなく、ログインごとに新しく発行する（4-(iv)-a で実現される）。

### 4-(vi) セッション ID を Cookie にセットする場合、有効期限の設定に注意する

Cookie の有効期限を短く設定し、必要以上の期間ブラウザに残らないようにする。サーバ側のセッションタイムアウトも併用する。

### その他

- ログアウト機能を提供し、ログアウト時にサーバ側のセッションを破棄する
- 一定時間操作がない場合の自動セッションタイムアウト
- 重要操作前の再認証（パスワード再入力）

## NG コードパターン (検出対象)

### PHP

```php
// NG: 時刻ベースのセッション ID を自前で生成
$sid = md5($username . time());
setcookie('sid', $sid);

// NG: URL パラメータでセッション ID を引き回す
echo '<a href="/mypage.php?sid=' . $sid . '">マイページ</a>';

// NG: ログイン成功後にセッション ID を再生成していない
session_start();
if (authenticate($u, $p)) {
    $_SESSION['user_id'] = $u; // session_regenerate_id() を呼んでいない
}

// NG: Secure/HttpOnly/SameSite なしの Cookie 発行
setcookie('sid', $sid);
```

| 観点 | 危険コード例 |
|------|-------------|
| 自前のセッション ID 生成 | `md5(time())`, `sha1(microtime())`, `uniqid()` をセッション ID として使用 |
| URL Rewriting 利用 | `session.use_trans_sid=1`、URL に `;jsessionid=...`、`?sid=...` を出力 |
| ログイン後の ID 再生成なし | `authenticate(...)` 成功直後に `session_regenerate_id` / `invalidate()` / `Session.Abandon()` が呼ばれていない |
| Secure 属性なし | `setcookie('sid', $sid)`（Secure 指定なし） |
| HttpOnly 属性なし | `setcookie(...)` で `httponly` キーなし |
| SameSite 属性なし | Cookie 発行で `samesite` 未指定 |
| 長すぎる有効期限 | `setcookie(..., time()+60*60*24*365, ...)` のような1年超 |
| ログアウト未実装 | `session_destroy()` / `invalidate()` が呼ばれない |

## OK コードパターン (修正例)

### PHP

```php
// セッション Cookie 属性を ini 設定で固定（推奨）
ini_set('session.cookie_httponly', 1);
ini_set('session.cookie_secure', 1);
ini_set('session.cookie_samesite', 'Strict');
ini_set('session.cookie_lifetime', 1800);
ini_set('session.use_only_cookies', 1);
ini_set('session.use_trans_sid', 0);

session_start();

if (authenticate_user($username, $password)) {
    session_regenerate_id(true);     // ログイン成功時に必ず再生成
    $_SESSION['user_id'] = $user_id;
    $_SESSION['authenticated'] = true;
}

setcookie('sessionid', $session_id, [
    'secure'   => true,
    'httponly' => true,
    'samesite' => 'Strict',
    'expires'  => time() + 1800,
    'path'     => '/',
]);
```

### Java (Servlet)

```java
if (authenticateUser(username, password)) {
    HttpSession existing = request.getSession(false);
    if (existing != null) existing.invalidate();

    HttpSession newSession = request.getSession(true);
    newSession.setMaxInactiveInterval(30 * 60);

    response.addHeader("Set-Cookie",
        "JSESSIONID=" + newSession.getId() +
        "; Path=/; Secure; HttpOnly; SameSite=Strict");
}
```

```xml
<!-- web.xml -->
<session-config>
    <cookie-config>
        <http-only>true</http-only>
        <secure>true</secure>
    </cookie-config>
    <tracking-mode>COOKIE</tracking-mode>
</session-config>
```

### ASP.NET

```csharp
if (AuthenticateUser(username, password))
{
    Session.Abandon();
    Session.Clear();

    var authCookie = new HttpCookie("...")
    {
        Secure   = true,
        HttpOnly = true,
        SameSite = SameSiteMode.Strict,
        Expires  = DateTime.Now.AddMinutes(30),
    };
    Response.Cookies.Add(authCookie);
}
```

### Express (Node.js)

```js
app.use(session({
  name: 'sid',
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: true,
    httpOnly: true,
    sameSite: 'strict',
    maxAge: 1000 * 60 * 30,
  },
}));

req.session.regenerate(err => {
  req.session.userId = user.id;
});
```

## 自動チェック観点

### 静的解析でカバー可能（○）

- 自作の弱い乱数によるセッション ID 生成 (`md5(time())`, `uniqid()` 等)
- Cookie 発行で `Secure`/`HttpOnly`/`SameSite` 属性の欠落
- `session.use_trans_sid=1`/`session.use_only_cookies=0` の設定
- `session_regenerate_id` 等の再生成 API の不存在（フォルダ全体）
- ログアウト時に `session_destroy()`/`invalidate()` がない

### 静的解析でカバーしにくい

- セッション ID のエントロピー実測値
- ログイン成功後の状態遷移を伴うセッション再生成検証
- セッションタイムアウト値の妥当性判定

### 検出正規表現候補

```bash
# 1. セッション ID 自前生成（弱い乱数）
grep -rEn "md5\s*\(\s*(time\(\)|microtime|uniqid|date\()" .
grep -rEn "sha1\s*\(\s*(time\(\)|microtime|uniqid|date\()" .
grep -rEn "uniqid\s*\(" . | grep -iE "session|sid|token"

# 2. URL にセッション ID 露出
grep -rEn "\?(sid|sessionid|PHPSESSID|jsessionid)=" .
grep -rEn "session\.use_trans_sid\s*=\s*1" .

# 3. Cookie 属性不足
grep -rEn "setcookie\s*\(" . | grep -v -iE "secure|httponly|samesite"

# 4. ログイン後の再発行漏れ（要文脈確認）
grep -rEn "session_regenerate_id" .

# 5. ログアウト処理不足
grep -rEn "logout|signout|sign_out" . | grep -v -iE "session_destroy|invalidate|abandon"

# 6. PHP ini / web.config / web.xml の不備
grep -rEn "session\.cookie_secure" .
grep -rEn "session\.cookie_httponly" .
grep -rEn "session\.cookie_samesite" .
grep -rEn "httpCookies[^>]*requireSSL=\"false\"" .
grep -rEn "<http-only>\s*false\s*</http-only>" .

# 7. 長すぎる Cookie 有効期限（1年超など）
grep -rEn "time\(\)\s*\+\s*[0-9]{7,}" .
```

## 関連ルール ID

- IPA-SWS-4-SESS-001: 弱い乱数によるセッション ID 生成（4-(i) 違反）
- IPA-SWS-4-SESS-002: URL Rewriting でセッション ID 露出（4-(ii) 違反）
- IPA-SWS-4-SESS-003: Cookie の Secure 属性なし（4-(iii) 違反）
- IPA-SWS-4-SESS-004: Cookie の HttpOnly 属性なし
- IPA-SWS-4-SESS-005: Cookie の SameSite 属性なし
- IPA-SWS-4-SESS-006: ログイン後のセッション ID 再生成なし（4-(iv)-a 違反）
- IPA-SWS-4-SESS-007: 第2セッション ID/秘密情報の検証なし（4-(iv)-b 違反）
- IPA-SWS-4-SESS-008: セッション ID が固定値（4-(v) 違反）
- IPA-SWS-4-SESS-009: Cookie の有効期限が過剰に長い（4-(vi) 違反）
- IPA-SWS-4-SESS-010: ログアウト時のセッション破棄なし

## Skill チェックリスト

- [ ] セッション ID はフレームワーク標準（あるいは CSPRNG）で生成されているか
- [ ] セッション ID は Cookie のみで管理されているか（URL Rewriting 無効）
- [ ] ログイン成功直後にセッション ID が再発行されているか
- [ ] Cookie に `Secure`、`HttpOnly`、`SameSite` 属性が付与されているか
- [ ] HTTPS サイトで `Secure` 属性なしの Cookie が発行されていないか
- [ ] セッションタイムアウト（サーバ側 / Cookie 有効期限）が適切に設定されているか
- [ ] ログアウト処理でサーバ側セッションが確実に破棄されているか
- [ ] 重要操作前にパスワード再認証が行われているか

## 参考

- IPA「安全なウェブサイトの作り方 - 1.4 セッション管理の不備」: https://www.ipa.go.jp/security/vuln/websecurity/session-management.html
- 「CSRF」と「Session Fixation」の諸問題について（高木浩光, IPA）: https://www.ipa.go.jp/security/vuln/websecurity/ug65p900000197by-att/20060228_3.pdf
- CWE-330 (Insufficiently Random Values): https://cwe.mitre.org/data/definitions/330.html
- CWE-384 (Session Fixation): https://cwe.mitre.org/data/definitions/384.html
- CWE-522 (Insufficiently Protected Credentials): https://cwe.mitre.org/data/definitions/522.html
- CWE-614 (Sensitive Cookie in HTTPS Without 'Secure'): https://cwe.mitre.org/data/definitions/614.html
