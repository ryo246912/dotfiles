---
name: access_control
ipa_document: 安全なウェブサイトの作り方 改訂第7版
ipa_section: "1.11 アクセス制御や認可制御の欠落"
ipa_page: "45-47"
ipa_url: https://www.ipa.go.jp/security/vuln/websecurity/access-control.html
cwe: CWE-264 / CWE-287
---

# アクセス制御や認可制御の欠落 (Missing Access Control / Broken Authorization / IDOR)

## 出典

- 文書名: 安全なウェブサイトの作り方 改訂第7版（IPA, 2021年3月31日）
- 章節: 1.11 アクセス制御や認可制御の欠落
- ページ: p.45〜47 付近
- URL: https://www.ipa.go.jp/security/vuln/websecurity/access-control.html

## 概要

ウェブアプリケーションにおいて、

- **アクセス制御（認証, Authentication）**: パスワード等の秘密情報の入力を必要とすることで、利用者が本人であることを確認するプロセス。
- **認可制御（認可, Authorization）**: 認証後、ログイン中の利用者に「どの操作」「どのリソース」へのアクセスを許可するかを制御する処理。

このいずれか／両方が欠落していると、他人の情報を閲覧・変更されたり、なりすましを許してしまう。

代表的なパターンは **IDOR（Insecure Direct Object Reference）**: URL や POST パラメータで渡された ID（ユーザ ID・注文番号など）をそのまま DB 検索キーとし、所有者チェックを行わずにレコードを返してしまう実装。

なお、メールアドレスのみでログインを許す実装は、IPA ページの脚注で「不正アクセス行為の禁止等に関する法律」第二条第二項の「識別符号」に該当しない可能性があると指摘されており、**アクセス制御機能が欠落した状態**とみなされる可能性がある。

## 脅威・被害

- 他人の個人情報の閲覧・改変
- 他ユーザーの注文情報・取引データ・カルテ等への不正アクセス
- なりすましによる不正操作（送金・購入・退会など）
- 管理画面への無権限アクセス
- データの改ざん・削除
- 機密情報・営業秘密の漏洩

## 発生パターン

### パターン1: URL や POST パラメータの利用者 ID をそのまま使う

外部から与えられる利用者 ID（`?user_id=123`）をキーに DB 検索する実装。ログイン済みなら他ユーザーになりすませる。

### パターン2: 注文番号などの検索キーの所有者検証不足（IDOR）

注文番号・伝票番号・ファイル ID などを URL/POST で受け取り、所有者がログインユーザーか確認しない実装。連番の ID なら総当たりも可能。

### パターン3: URL 直アクセスでの認証チェック漏れ

メニューからリンクを張っていない管理画面/内部ページが、URL を直接叩くと認証なしで閲覧できる（"hidden by obscurity"）。

### パターン4: 機能単位の認可チェック漏れ

一般ユーザーが管理者専用エンドポイント（`/admin/...`）をリクエストすると処理が通ってしまう。

### パターン5: クライアント側のみでのアクセス制御

「ボタンを非表示にしている」「JS で遷移を止めている」だけで、サーバ側に同等チェックがない。

## 根本的解決策

### 11-(i) 認証機能の実装

パスワード等（みだりに第三者に知らせてはならないものとして一般に考えられている情報）の入力を必要とするように設計・実装する。メールアドレスのみのログインは原則避ける。

### 11-(ii) 認可制御の実装

データベースを検索するための利用者 ID が、**ログイン中の利用者 ID と一致しているかを常に確認**する。または、**利用者 ID を外部から与えられるパラメータから取得せず、セッション変数から取得**するように実装する。

具体的には:

- 利用者 ID は **セッション変数からのみ** 取得する
- 注文番号等の他リソース ID は、必ず「ログインユーザーが所有するものか」を WHERE 句や事前チェックで検証する
- 機能単位での権限ロール（admin / user / guest 等）をサーバ側で必ず検証する
- すべてのエンドポイントでログイン状態を確認する（ホワイトリスト方式で「認証不要なページ」を限定）

## 保険的対策

- アクセスログの取得・監視（誰が・いつ・どのリソースにアクセスしたか）
- 異常なアクセスパターン（短時間での大量 ID アクセス、連番アクセスなど）の検出
- レート制限（rate limiting）
- API 呼び出しの監査ログ
- 直接参照されにくい ID（UUID / ランダム値）の採用（IDOR の総当たり対策の保険）
- 不正アクセス検知時の管理者通知 / アカウントロック

## NG コードパターン (検出対象)

### PHP（IDOR）
```php
// NG: URL パラメータをそのまま DB 検索キーに使用
$user_id  = $_GET['user_id'];
$user     = db_query("SELECT * FROM users WHERE id = ?", [$user_id]);
echo $user['email'];

// NG: 注文番号の所有者検証なし
$order_id = $_GET['order_id'];
$order    = db_query("SELECT * FROM orders WHERE id = ?", [$order_id]);

// NG: 認証チェックなし
// /admin/users.php の冒頭で is_logged_in() / is_admin() を呼んでいない
include 'header.php';
$users = db_query("SELECT * FROM users");
```

### クライアント側のみのチェック
```js
// NG: サーバ側 /api/admin/users は誰でも叩ける
if (currentUser.role !== 'admin') {
  hideAdminButton();
}
```

| 観点 | 危険コード例 |
|------|-------------|
| 外部入力をそのままキーに | `$_GET['user_id']` / `request.args.get('user_id')` を WHERE 句に直接 |
| セッション無視 | DB アクセス前に `$_SESSION['user_id']` / `req.session.userId` を参照していない |
| 所有者チェック欠落 | `WHERE id = ?` のみで `AND user_id = ?` がない |
| URL 直アクセスチェック漏れ | コントローラ冒頭に `is_logged_in()` / `@login_required` / `[Authorize]` / `before_action :authenticate` がない |
| クライアント側のみで制御 | サーバ側エンドポイントに同等の認可チェックがない |
| 認可の無効化 | `@AllowAnonymous` / `permitAll()` / `skip_before_action :authenticate` が重要パスに付いている |
| Mass Assignment | `User::create($request->all())` のように外部入力を一括代入（特に `role` / `is_admin` フィールド） |

## OK コードパターン (修正例)

### PHP
```php
$current_user_id = $_SESSION['user_id'] ?? null;
if ($current_user_id === null) {
    http_response_code(401);
    exit('Unauthorized');
}

// 注文: WHERE 句で所有者を必ず縛る
$order_id = (int)$_GET['order_id'];
$order = db_query(
    "SELECT * FROM orders WHERE id = ? AND user_id = ?",
    [$order_id, $current_user_id]
);
if (!$order) {
    http_response_code(403);
    exit('Access Denied');
}
```

### Laravel
```php
class OrderPolicy
{
    public function view(User $user, Order $order): bool
    {
        return $user->id === $order->user_id;
    }
}

public function show(Order $order)
{
    $this->authorize('view', $order); // 失敗時 403
    return view('orders.show', compact('order'));
}
```

### Django
```python
from django.contrib.auth.decorators import login_required
from django.shortcuts import get_object_or_404

@login_required
def view_order(request, order_id):
    order = get_object_or_404(Order, id=order_id)
    if order.user_id != request.user.id:
        return HttpResponseForbidden()
    return render(request, 'order.html', {'order': order})
```

### Spring Security
```java
@GetMapping("/orders/{orderId}")
public ResponseEntity<?> getOrder(
        @PathVariable Long orderId,
        @AuthenticationPrincipal CustomUser user) {
    Order order = orderService.findById(orderId);
    if (order == null || !order.getUserId().equals(user.getId())) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
    }
    return ResponseEntity.ok(order);
}

@PreAuthorize("hasRole('ADMIN')")
@GetMapping("/admin/users")
public List<User> listUsers() { ... }
```

### ASP.NET Core
```csharp
[Authorize]
[ApiController]
[Route("orders")]
public class OrdersController : ControllerBase
{
    [HttpGet("{id}")]
    public IActionResult Get(int id)
    {
        var userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier).Value);
        var order = _db.Orders.FirstOrDefault(o => o.Id == id && o.UserId == userId);
        if (order == null) return Forbid();
        return Ok(order);
    }
}

[Authorize(Roles = "Admin")]
[HttpGet("/admin/users")]
public IActionResult List() { ... }
```

### Ruby on Rails
```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
end

class OrdersController < ApplicationController
  def show
    @order = current_user.orders.find(params[:id])
  end
end
```

### Express
```js
function requireAuth(req, res, next) {
  if (!req.session.userId) return res.status(401).send('Unauthorized');
  next();
}

function requireOwner(req, res, next) {
  if (parseInt(req.params.userId) !== req.session.userId) {
    return res.status(403).send('Forbidden');
  }
  next();
}

app.get('/users/:userId/orders', requireAuth, requireOwner, (req, res) => { ... });
```

## 自動チェック観点

### 静的解析でカバー可能（△ コンテキスト依存）

- 外部入力をそのままキーに DB 検索（IDOR 候補）
- `WHERE id = ?` のみで `user_id` 縛りがない
- 認証ガード未付与のコントローラ／ルート
- 認可の明示的無効化（`@AllowAnonymous` / `csrf_exempt` 等）
- クライアント側のみのロールチェック
- Mass Assignment（特に `role` / `admin` フィールド）

### 静的解析でカバーしにくい

- 業務ロジック上の権限境界（特定の部署のユーザのみ閲覧可能等）
- 動的なロール解決

### 検出正規表現候補

```bash
# 1. 外部入力を直接 SQL に使っている（IDOR 候補）
grep -rEn "WHERE\s+id\s*=\s*\\\$_(GET|POST|REQUEST)" .
grep -rEn "WHERE\s+user_id\s*=\s*\\\$_(GET|POST|REQUEST)" .
grep -rEn "find\s*\(\s*params\[:id\]\s*\)" . | grep -v "current_user"
grep -rEn "Order\.objects\.get\s*\(\s*id\s*=\s*request\.(GET|POST)" .

# 2. user_id を外部入力から取得
grep -rEn "user_id\s*=\s*\\\$_(GET|POST|REQUEST)" .
grep -rEn "userId\s*=\s*req\.(query|body|params)" .

# 3. 認証ガード未付与のコントローラ／ルート
grep -rEn "@(Get|Post|Put|Delete)Mapping" . | grep -v -B2 "@PreAuthorize\|@Secured\|@Authorize"
grep -rEn "Route::(get|post|put|delete)" . | grep -v "middleware"

# 4. 認可の明示的無効化
grep -rEn "@AllowAnonymous|permitAll\(\)|csrf_exempt|skip_before_action\s*:authenticate" .
grep -rEn "\.AllowAnonymous|\[AllowAnonymous\]" .

# 5. クライアント側のみのロールチェック
grep -rEn "(role|is_admin|isAdmin)\s*===?\s*['\"]admin['\"]" . --include="*.js" --include="*.ts" --include="*.tsx"

# 6. Mass Assignment（特に role / admin フィールド）
grep -rEn "create\s*\(\s*request\(?\)?->all\(" .
grep -rEn "update\s*\(\s*request\(?\)?->all\(" .
grep -rEn "User\.objects\.create\s*\(\s*\*\*request" .

# 7. WHERE 句に user_id 縛りがないクエリ
grep -rEn "SELECT\s+.*\s+FROM\s+orders\s+WHERE\s+id\s*=" . | grep -v "user_id"
grep -rEn "SELECT\s+.*\s+FROM\s+messages\s+WHERE\s+id\s*=" . | grep -v "user_id"
```

## 関連ルール ID

- IPA-SWS-11-AC-001: 認証機能の欠落（11-(i) 違反）
- IPA-SWS-11-AC-002: 認可チェックの欠落（11-(ii) 違反）
- IPA-SWS-11-AC-003: IDOR（所有者検証なしのリソースアクセス）
- IPA-SWS-11-AC-004: 外部入力からの利用者 ID 取得
- IPA-SWS-11-AC-005: URL 直アクセス時の認証ガード未付与
- IPA-SWS-11-AC-006: 管理画面のロール検証なし
- IPA-SWS-11-AC-007: クライアント側のみの認可制御
- IPA-SWS-11-AC-008: Mass Assignment（`role`/`is_admin` 等の書き換え可能）
- IPA-SWS-11-AC-009: 認可の明示的無効化（`@AllowAnonymous`/`csrf_exempt` 等）
- IPA-SWS-11-AC-010: メールアドレスのみのログイン

## Skill チェックリスト

- [ ] すべての認証必須エンドポイントで、認証ガード（middleware / decorator / attribute）が付与されているか
- [ ] 利用者 ID はセッション（または認証コンテキスト）からのみ取得しているか
- [ ] リソース取得時に「ログインユーザーが所有しているか」を WHERE 句または事前チェックで検証しているか
- [ ] 管理者専用機能にロール検証が付与されているか
- [ ] フロントエンドで隠している機能のサーバ側エンドポイントにも同等の認可があるか
- [ ] Mass Assignment 対策（`fillable` / `guarded` / `strong_parameters` / DTO）が施されているか
- [ ] 認可失敗時のレスポンスがリソース存在を漏らさないか（404 vs 403 の使い分け）
- [ ] アクセスログ・監査ログが取得されているか
- [ ] 連番 ID の代わりに UUID 等を使う検討がされているか

## 参考

- IPA「安全なウェブサイトの作り方 - 1.11 アクセス制御や認可制御の欠落」: https://www.ipa.go.jp/security/vuln/websecurity/access-control.html
- 不正アクセス行為の禁止等に関する法律: https://elaws.e-gov.go.jp/document?lawid=411AC0000000128
- CWE-284 (Improper Access Control): https://cwe.mitre.org/data/definitions/284.html
- CWE-285 (Improper Authorization): https://cwe.mitre.org/data/definitions/285.html
- CWE-639 (Authorization Bypass Through User-Controlled Key): https://cwe.mitre.org/data/definitions/639.html
- CWE-862 (Missing Authorization): https://cwe.mitre.org/data/definitions/862.html
- CWE-863 (Incorrect Authorization): https://cwe.mitre.org/data/definitions/863.html
- OWASP Top 10 A01:2021 – Broken Access Control: https://owasp.org/Top10/A01_2021-Broken_Access_Control/
