---
name: operation_checklist
ipa_document: "安全なウェブサイトの作り方 改訂第7版 / 安全なウェブサイトの運用管理に向けての20ヶ条"
ipa_section: "巻末セキュリティ実装チェックリスト + 20ヶ条"
ipa_page: "105-108 (実装チェックリスト) / N/A (20ヶ条)"
ipa_url: "https://www.ipa.go.jp/security/vuln/websecurity/ug65p900000196e2-att/000017316.pdf https://www.ipa.go.jp/security/vuln/websecurity/sitecheck.html"
cwe: 複数（各項目参照）
---

# IPA 運用管理20ヶ条 + 実装チェックリスト 統合ノート

## 出典

### A. セキュリティ実装チェックリスト
- 出典: 安全なウェブサイトの作り方 改訂第7版（IPA, 2021年3月31日）巻末「チェックリスト」（p.105〜108）
- PDF: https://www.ipa.go.jp/security/vuln/websecurity/ug65p900000196e2-att/000017316.pdf
- Excel: https://www.ipa.go.jp/security/vuln/websecurity/ug65p900000196e2-att/000044403.xlsx

### B. 安全なウェブサイトの運用管理に向けての20ヶ条
- 出典: IPA「安全なウェブサイトの運用管理に向けての20ヶ条」
- URL: https://www.ipa.go.jp/security/vuln/websecurity/sitecheck.html

---

# Part 1: セキュリティ実装チェックリスト（巻末 p.105〜）

## チェック方法（IPA 原典より）

各実施項目について、次の3つから選択:

| ステータス | 意味 |
|---|---|
| 対応済 | 対策を実施している |
| 未対応 | 対策の実施は必要であるが、未実施 |
| 対応不要 | そもそも脆弱性が存在しない実装である場合、または他の対策で代替済 |

「根本的解決」は **脆弱性の原因を作らない実装** で推奨される。
「保険的対策」は影響緩和。複数項目が「いずれかを実施すればよい」関係にある場合、まとめて 1 つのチェックとなる（※印付き）。

---

## 1. SQL インジェクション

| 項目 ID | 性質 | 実施項目 | 自動チェック観点 |
| --- | --- | --- | --- |
| 1-(i)-a | 根本 ※ | SQL 文の組み立ては全てプレースホルダで実装する | プレースホルダ使用検出。文字列連結 SQL の検出 |
| 1-(i)-b | 根本 ※ | SQL 文を文字列連結で行う場合は、変数を SQL 文のリテラルとして正しく構成する | エスケープ関数の併用検出 |
| 1-(ii) | 根本 | パラメータに SQL 文を直接指定しない | URL/フォーム入力を SQL 文として解釈する箇所の検出 |
| 1-(iii) | 保険 | エラーメッセージをそのままブラウザに表示しない | フレームワークの debug モード／詳細エラー表示の確認 |
| 1-(iv) | 保険 | データベースアカウントに適切な権限を与える | DB 接続ユーザの権限検査、`root` ユーザ使用の検出 |

詳細は `01_sql_injection.md` および `safe_sql_details.md` 参照。

---

## 2. OS コマンド・インジェクション

| 項目 ID | 性質 | 実施項目 | 自動チェック観点 |
| --- | --- | --- | --- |
| 2-(i) | 根本 | シェルを起動できる言語機能の利用を避ける | `system()`, `exec()` 等の使用検出 |
| 2-(ii) | 保険 | シェル起動機能を利用する場合、引数の全変数をチェックし許可した処理のみ実行 | コマンド引数のホワイトリスト検査の有無 |

詳細は `02_os_command_injection.md` 参照。

---

## 3. パス名パラメータの未チェック／ディレクトリ・トラバーサル

| 項目 ID | 性質 | 実施項目 | 自動チェック観点 |
| --- | --- | --- | --- |
| 3-(i)-a | 根本 ※ | 外部パラメータでウェブサーバ内のファイル名を直接指定する実装を避ける | ファイル操作関数の引数に外部入力が直接渡されていないか |
| 3-(i)-b | 根本 ※ | ファイルを開く際は、固定ディレクトリを指定し、ファイル名にディレクトリ名が含まれないようにする | ディレクトリ部分の固定とファイル名サニタイズ |
| 3-(ii) | 保険 | ウェブサーバ内のファイルへのアクセス権限の設定を正しく管理する | パーミッション、`open_basedir` 等 |
| 3-(iii) | 保険 | ファイル名のチェックを行う | `../` 検出、basename 化 |

詳細は `03_directory_traversal.md` 参照。

---

## 4. セッション管理の不備

| 項目 ID | 性質 | 実施項目 | 自動チェック観点 |
| --- | --- | --- | --- |
| 4-(i) | 根本 | セッション ID を推測困難なものにする | フレームワーク標準セッション機構の利用、自作の弱い乱数の検出 |
| 4-(ii) | 根本 | セッション ID を URL パラメータに格納しない | URL 中の `JSESSIONID`, `PHPSESSID`, `sid=` 等の使用検出 |
| 4-(iii) | 根本 | HTTPS 通信で利用する Cookie には secure 属性を加える | Cookie の `Secure` 属性付与 |
| 4-(iv)-a | 根本 ※ | ログイン成功後、新しいセッションを開始する | セッション再生成 API の呼び出し |
| 4-(iv)-b | 根本 ※ | ログイン成功後、既存のセッション ID とは別に秘密情報を発行し、ページ遷移ごとに確認する | トークン二重検証 |
| 4-(v) | 保険 | セッション ID を固定値にしない | 静的トークンの検出 |
| 4-(vi) | 保険 | セッション ID を Cookie にセットする場合、有効期限の設定に注意する | Cookie Max-Age / Expires の検査 |

詳細は `04_session_management.md` 参照。

---

## 5. クロスサイト・スクリプティング (XSS)

### HTML テキストの入力を許可しない場合

| 項目 ID | 性質 | 実施項目 | 自動チェック観点 |
| --- | --- | --- | --- |
| 5-(i) | 根本 | ウェブページに出力する全ての要素に対して、エスケープ処理を施す | テンプレートの自動エスケープ ON、生出力タグの検出 |
| 5-(ii) | 根本 | URL を出力するときは、`http://` や `https://` で始まる URL のみを許可する | リンク／リダイレクト先 URL 検査 |
| 5-(iii) | 根本 | `<script>...</script>` 要素の内容を動的に生成しない | スクリプトタグ内への変数埋込検出 |
| 5-(iv) | 根本 | スタイルシートを任意のサイトから取り込めるようにしない | CSS インクルードの動的化禁止 |
| 5-(v) | 保険 | 入力値の内容チェックを行う | 入力バリデーションの有無 |

### HTML テキストの入力を許可する場合

| 項目 ID | 性質 | 実施項目 | 自動チェック観点 |
| --- | --- | --- | --- |
| 5-(vi) | 根本 | 入力された HTML テキストから構文解析木を作成し、スクリプトを含まない必要な要素のみを抽出する | DOMPurify / sanitize-html / Bleach 等の利用 |
| 5-(vii) | 保険 | 入力された HTML テキストから、スクリプトに該当する文字列を排除する | 正規表現除去はアンチパターンとして警告 |

### 全アプリ共通

| 項目 ID | 性質 | 実施項目 | 自動チェック観点 |
| --- | --- | --- | --- |
| 5-(viii) | 根本 | HTTP レスポンスヘッダの Content-Type フィールドに文字コードを指定 | `Content-Type: text/html; charset=utf-8` の付与 |
| 5-(ix) | 保険 | Cookie 漏えい対策として HttpOnly 属性を加え、TRACE メソッドを無効化 | HttpOnly 属性確認、TRACE メソッド遮断 |
| 5-(x) | 保険 | ブラウザ機能を有効化するレスポンスヘッダを返す | CSP, X-Content-Type-Options, X-XSS-Protection 等 |

詳細は `05_xss.md` 参照。

---

## 6. CSRF

| 項目 ID | 性質 | 実施項目 | 自動チェック観点 |
| --- | --- | --- | --- |
| 6-(i)-a | 根本 ※ | POST メソッド + hidden パラメータに秘密情報を挿入し、実行ページで値が正しい場合のみ処理 | CSRF トークンの hidden フィールド検査 |
| 6-(i)-b | 根本 ※ | 処理を実行する直前のページで再度パスワードの入力を求める | 重要操作前の再認証実装 |
| 6-(i)-c | 根本 ※ | Referer が正しいリンク元かを確認し、正しい場合のみ処理 | Referer チェックの有無 |
| 6-(ii) | 保険 | 重要な操作を行った際に、その旨を登録済みメールアドレスに自動送信 | 通知メール実装 |

詳細は `06_csrf.md` 参照。

---

## 7. HTTP ヘッダ・インジェクション

| 項目 ID | 性質 | 実施項目 | 自動チェック観点 |
| --- | --- | --- | --- |
| 7-(i)-a | 根本 ※ | ヘッダの出力を直接行わず、ヘッダ出力用 API を使用する | 生のヘッダ出力検出 |
| 7-(i)-b | 根本 ※ | API を利用できない場合は、改行を許可しないよう開発者自身で適切な処理を実装 | 改行除去処理の検査 |
| 7-(ii) | 保険 | 外部からの入力すべてについて、改行コードを削除する | 入力サニタイズ |

詳細は `07_http_header_injection.md` 参照。

---

## 8. メールヘッダ・インジェクション

| 項目 ID | 性質 | 実施項目 | 自動チェック観点 |
| --- | --- | --- | --- |
| 8-(i)-a | 根本 ※ | メールヘッダを固定値にして、外部入力はすべてメール本文に出力する | 動的ヘッダ生成の検出 |
| 8-(i)-b | 根本 ※ | メール送信用 API を使用する | 安全な送信ライブラリ利用 |
| 8-(ii) | 根本 | HTML で宛先を指定しない | フォーム hidden での宛先指定検出 |
| 8-(iii) | 保険 | 外部からの入力すべてについて、改行コードを削除する | 入力サニタイズ |

詳細は `08_mail_header_injection.md` 参照。

---

## 9. クリックジャッキング

| 項目 ID | 性質 | 実施項目 | 自動チェック観点 |
| --- | --- | --- | --- |
| 9-(i)-a | 根本 ※ | HTTP レスポンスヘッダに X-Frame-Options を出力し、他ドメインからの frame/iframe を制限 | `X-Frame-Options` ヘッダ付与 |
| 9-(i)-b | 根本 ※ | 処理実行直前のページで再度パスワード入力を求める | 重要操作前の再認証 |
| 9-(ii) | 保険 | 重要な処理は一連の操作をマウスのみで実行できないようにする | 確認モーダルやキーボード必須化 |

詳細は `09_clickjacking.md` 参照。

---

## 10. バッファオーバーフロー

| 項目 ID | 性質 | 実施項目 | 自動チェック観点 |
| --- | --- | --- | --- |
| 10-(i)-a | 根本 ※ | 直接メモリにアクセスできない言語で記述する | 言語選択（C/C++ ネイティブ部分の存在検出） |
| 10-(i)-b | 根本 ※ | 直接メモリにアクセスできる言語で記述する部分を最小限にする | FFI / native binding の検出 |
| 10-(ii) | 根本 | 脆弱性が修正されたバージョンのライブラリを使用する | 既知 CVE のあるネイティブ依存検出 |

詳細は `10_buffer_overflow.md` 参照。

---

## 11. アクセス制御や認可制御の欠落

| 項目 ID | 性質 | 実施項目 | 自動チェック観点 |
| --- | --- | --- | --- |
| 11-(i) | 根本 | アクセス制御機能による防御措置が必要なサイトには、パスワード等の秘密情報の入力を必要とする認証機能を設ける | 認証要否レビュー |
| 11-(ii) | 根本 | 認証機能に加えて認可制御の処理を実装し、ログイン中の利用者が他人になりすましてアクセスできないようにする | 認可チェックの有無 |

詳細は `11_access_control.md` 参照。

---

# Part 2: 安全なウェブサイトの運用管理に向けての20ヶ条

URL: https://www.ipa.go.jp/security/vuln/websecurity/sitecheck.html

## 大分類

| カテゴリ | 該当条文 |
| --- | --- |
| 1. ウェブアプリケーションのセキュリティ対策 | 第1〜第8条 |
| 2. ウェブサーバのセキュリティ対策 | 第9〜第14条 |
| 3. ネットワークのセキュリティ対策 | 第15〜第18条 |
| 4. その他のセキュリティ対策 | 第19〜第20条 |

---

## A. ウェブアプリケーションのセキュリティ対策（第1〜第8条）

### 第1条: 公開すべきでないファイルを公開していない

- **推奨対策**: 設定ファイル／秘密情報を公開ディレクトリ外に保管、不要ファイルの削除
- **自動チェック観点**:
  - 公開ディレクトリ（`public/`, `static/`, `www/`, `htdocs/`, `wwwroot/`, `docroot/`）配下に存在しないか:
    - 機密設定ファイル: `.env`, `.env.local`, `.env.production`, `config.php`, `application.yml`, `web.config`, `database.yml`, `secrets.json`, `credentials.json`, `firebase-adminsdk*.json`
    - VCS ディレクトリ: `.git/`, `.svn/`, `.hg/`, `.DS_Store`
    - バックアップ／一時ファイル: `*.bak`, `*.swp`, `*.orig`, `*.old`, `*~`
    - ダンプ／ログ: `*.sql`, `*.dump`, `*.log`
    - IDE 設定: `.idea/`, `.vscode/`, `*.iml`
    - シークレット直書き: `AWS_SECRET`, `API_KEY=` 等のキーワード
  - `.gitignore` / `.dockerignore` に上記が含まれているか
  - Web サーバ設定で対象拡張子をブロック:
    - nginx: `location ~ /\.(git|env|svn|DS_Store) { deny all; }`
    - Apache: `<FilesMatch "^\.(git|env|ht)">` に `Require all denied`

### 第2条: 不要になったページやウェブサイトを公開していない

- **推奨対策**: 期間限定ページや管理不在ページを閉鎖
- **自動チェック観点**: 公開ディレクトリの最終更新日が古いコンテンツの抽出、`robots.txt`/`sitemap.xml` の整合性。主に人手確認推奨

### 第3条: 「安全なウェブサイトの作り方」記載の脆弱性に対策している

- **推奨対策**: 実装チェックリスト（本ファイルの Part 1）を網羅
- **自動チェック観点**: 各個別 knowledge ファイル参照

### 第4条: ウェブアプリ構成ソフトウェアの脆弱性対策を定期的に実施

- **推奨対策**: フレームワーク・ライブラリの CVE 対応
- **自動チェック観点**:
  - 依存関係ファイル: `package.json` + `package-lock.json`, `requirements.txt`, `Pipfile.lock`, `Gemfile.lock`, `pom.xml`, `build.gradle`, `composer.json`/`composer.lock`, `go.sum`, `Cargo.lock`
  - 脆弱性スキャナ統合: `npm audit`, `pip-audit`, `bundler-audit`, `OWASP Dependency-Check`, `Trivy`, `Snyk`, GitHub Dependabot
  - lock ファイル欠如の検出
  - 非保守バージョン: EOL リスト（Node.js 14 以下、Python 3.7 以下、PHP 7.4 以下 等）

### 第5条: 不必要なエラーメッセージを返していない

- **推奨対策**: 本番でスタックトレース・SQL 文・パス情報を返さない
- **自動チェック観点**:
  - フレームワーク設定:
    - Rails: `config.consider_all_requests_local = false`
    - Django: `DEBUG = False`、`ALLOWED_HOSTS` 設定
    - Spring Boot: `server.error.include-stacktrace=never`, `server.error.include-message=never`
    - Express.js: 本番で `errorhandler` が詳細を返していない
    - PHP: `display_errors = Off`, `display_startup_errors = Off`, `expose_php = Off`
    - ASP.NET: `<customErrors mode="On" />` または `<httpErrors errorMode="Custom">`
  - コード:
    - `e.printStackTrace()` / `traceback.print_exc()` をレスポンスに混入
    - `res.send(err.stack)` / `res.json({error: err})` の生エラー返却
    - SQL エラーオブジェクトの JSON.stringify
  - HTTP ヘッダ: `Server`, `X-Powered-By` を隠蔽（`server_tokens off;` / `expose_php = Off`）

### 第6条: ウェブアプリケーションのログを保管し定期的に確認

- **推奨対策**: アクセス・認証・トランザクション・例外を構造化ログ出力
- **自動チェック観点**:
  - ロガー初期化: `Log4j`, `Logback`, `winston`, `pino`, `python logging`, `Monolog`
  - 重要イベントログ: 認証成功／失敗、認可エラー、パスワード変更、権限変更、決済等
  - ログ出力先設定
  - **機微情報を出力していない**: `password`, `pwd`, `secret`, `token`, `authorization`, `cookie`, `cardNumber`, `cvv` をログ関数の引数に渡していないか
  - ログローテーション: `logrotate.conf`, `log4j` の `RollingFileAppender`

### 第7条: 通信内容の暗号化（HTTPS）ができている

- **推奨対策**: 全面 HTTPS、TLS 1.2 以上、HSTS、HTTPS リダイレクト
- **自動チェック観点**:
  - **HTTPS リダイレクト** (port 80 → 443):
    - nginx: `return 301 https://$host$request_uri;`
    - Apache: `RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]`
    - Spring Boot: `server.ssl.enabled=true` + `security.require-ssl=true`
    - Express: `if(!req.secure) return res.redirect('https://'+req.headers.host+req.url);`
  - **HSTS ヘッダ**:
    - `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`
    - nginx: `add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;`
    - アンチパターン: 未設定、`max-age=0`、過小な `max-age`（86400 等）
  - **TLS 設定**:
    - `ssl_protocols TLSv1.2 TLSv1.3;`（`SSLv2/3`, `TLSv1`, `TLSv1.1` はアンチパターン）
    - `ssl_ciphers` に `RC4`, `DES`, `3DES`, `MD5`, `NULL` を含まない
    - `ssl_prefer_server_ciphers on;`
  - **混在コンテンツ**: HTML/JS/CSS 中の `http://` 外部リソース URL

### 第8条: 不正ログインの対策ができている

- **推奨対策**: 強力なパスワード、ロックアウト、多要素認証、認証ログ
- **自動チェック観点**:
  - **パスワードハッシュ**:
    - 推奨: `bcrypt`, `scrypt`, `argon2`, `PBKDF2`
    - アンチパターン: `md5(`, `sha1(`, `sha256(password)` 等の単純ハッシュ／ソルトなし
  - **ログイン試行制限**: `express-rate-limit`, `django-axes`, `rack-attack`, `bucket4j` 等
  - **多要素認証**: `otplib`, `pyotp`, `devise-two-factor`
  - **Cookie 属性**: `Secure`, `HttpOnly`, `SameSite=Lax|Strict`
  - **セッション固定化対策**: ログイン成功後のセッション ID 再発行
  - **CAPTCHA / reCAPTCHA** 等のボット対策
  - **エラーメッセージ抽象化**: 「ユーザ ID またはパスワードが違います」

---

## B. ウェブサーバのセキュリティ対策（第9〜第14条）

### 第9条: OS・サーバソフトウェア・ミドルウェアをバージョンアップしている

- **自動チェック観点**:
  - Dockerfile: `FROM ubuntu:18.04` 等 EOL イメージ
  - `apt-get update` 後の `--no-install-recommends`
  - `:latest` タグの使用は警告
  - CI/CD で `trivy image`, `docker scan` 等のスキャン

### 第10条: 不要なサービス・アプリケーションがない

- **自動チェック観点**:
  - Dockerfile / docker-compose で公開ポートが必要最小限か
  - nginx/Apache の有効モジュール一覧
  - `apt-get install` パッケージリストの妥当性

### 第11条: 不要なアカウントが登録されていない

- **自動チェック観点**:
  - シードデータ・マイグレーションのテストアカウント: `admin / admin`, `test / test`, `root / root`, `guest / guest`
  - サンプルユーザ作成スクリプトの本番投入チェック
  - DB マイグレーションに `DEFAULT 'password'` のようなパターン

### 第12条: 推測されやすい単純なパスワードを使用していない

- **自動チェック観点**:
  - 環境変数／設定ファイル中のパスワード強度: `DB_PASSWORD=password`, `JWT_SECRET=secret`, `ADMIN_PASS=admin123`
  - ハードコードされた認証情報: `password = "..."`, `apiKey = "..."`, AWS アクセスキー `AKIA[0-9A-Z]{16}`、GitHub PAT 形式
  - パスワードポリシー実装

### 第13条: ファイル・ディレクトリのアクセス制御を適切に設定

- **自動チェック観点**:
  - Dockerfile での `USER` 指示（`USER root` のままはアンチパターン）
  - ファイルアップロード先ディレクトリでの実行権限禁止:
    - nginx: `location /uploads/ { location ~ \.(php|jsp|aspx|cgi)$ { deny all; } }`
    - Apache: `<Directory "/var/www/uploads"> php_admin_flag engine off </Directory>`
  - `chmod 777` のようなパーミッション設定
  - 静的ファイルディレクトリで `Options -Indexes`/`autoindex off;`

### 第14条: ウェブサーバのログを保管し定期的に確認

- **自動チェック観点**:
  - nginx: `access_log /var/log/nginx/access.log;` `error_log ... warn;`
  - Apache: `CustomLog`, `ErrorLog` 設定
  - `error_log` の `level` が `info` 以上
  - ログローテーション: `logrotate.d/*`
  - DB スローログ／監査ログ設定の有無

---

## C. ネットワークのセキュリティ対策（第15〜第18条）

### 第15条: 境界で不要な通信を遮断（ルータ等）

- **自動チェック観点**:
  - クラウド設定（IaC）:
    - Terraform / CloudFormation の Security Group で `0.0.0.0/0` 全開放（SSH 22, RDP 3389, DB 3306/5432）
    - `direction = "ingress"` + `cidr = "0.0.0.0/0"` + `port = 22`
  - Kubernetes NetworkPolicy

### 第16条: ファイアウォールで通信を適切にフィルタリング

- **自動チェック観点**: IaC の `egress` ルール過剰開放、WAF / Cloud Firewall 設定

### 第17条: ウェブサーバへの不正な通信を検知・遮断（IDS/IPS/WAF）

- **自動チェック観点**:
  - ModSecurity / OWASP CRS（nginx の `modsecurity on;`）
  - CloudFront/ALB + AWS WAF の関連付け
  - 「人手確認推奨」

### 第18条: ネットワーク機器のログを保管し定期的に確認

- **自動チェック観点**: VPC Flow Logs / ALB Access Logs / WAF Logs 設定の有無

---

## D. その他のセキュリティ対策（第19〜第20条）

### 第19条: クラウド利用における責任範囲を把握し対策を実施

- **自動チェック観点**:
  - クラウドプロバイダ別ベストプラクティス遵守:
    - S3 バケット: `BlockPublicAccess`, `Versioning`, `Encryption`
    - RDS: `StorageEncrypted`, `PubliclyAccessible=false`
    - IAM Role: 最小権限（`*` ワイルドカードの濫用検出）
  - IaC ツール: `tfsec`, `checkov`, `cfn-nag`

### 第20条: 定期的にセキュリティ検査（診断）・監査している

- **自動チェック観点**:
  - CI/CD パイプライン:
    - SAST: CodeQL, Semgrep, SonarQube
    - DAST: OWASP ZAP, Burp Suite
    - SCA: 依存関係スキャン
    - シークレットスキャン: gitleaks, truffleHog
  - ペネトレーションテスト実施記録（人手確認）

---

# Part 3: 自動チェック観点サマリ

## A. 設定ファイル検査で検出可能

| 観点 | 対象ファイル | 検出パターン例 |
| --- | --- | --- |
| HTTPS 強制 | `nginx.conf`, `.htaccess`, `web.config`, `application.yml` | `return 301 https://`, `RewriteRule ... https` |
| HSTS | `nginx.conf`, ミドルウェア | `Strict-Transport-Security` ヘッダ付与 |
| TLS バージョン | `nginx.conf`, `ssl.conf` | `ssl_protocols TLSv1.2 TLSv1.3` |
| 弱い暗号スイート | `ssl_ciphers` | `RC4`, `DES`, `MD5`, `NULL` を含まない |
| サーバ情報非表示 | `nginx.conf`, `php.ini` | `server_tokens off;`, `expose_php = Off` |
| ディレクトリリスティング無効 | `nginx.conf`, Apache | `autoindex off;`, `Options -Indexes` |
| Cookie Secure 属性 | フレームワーク設定 | `session.cookie_secure=1`, `cookie.secure=true` |
| Cookie HttpOnly | 同上 | `cookie.httpOnly=true` |
| Cookie SameSite | 同上 | `cookie.sameSite=Lax\|Strict` |
| エラー詳細非表示 | `php.ini`, `production.rb`, `application.properties` | `display_errors=Off`, `include-stacktrace=never` |
| シークレットの公開ディレクトリ排除 | `.gitignore`, ディレクトリ構造 | `.env` 等を `public/` 配下に置かない |
| 安全な SG | Terraform/CloudFormation | `0.0.0.0/0` + 重要ポートの組合せ検出 |

## B. ソースコード静的解析で検出可能

| 観点 | 検出パターン |
| --- | --- |
| 危険ハッシュ関数 | `md5(`, `sha1(`, `crypto.createHash('md5')` でパスワード処理 |
| 平文パスワード保存 | DB カラムへの `password` 直接保存 |
| プレースホルダ未使用 SQL | 文字列連結 SQL |
| シェル実行 | `exec()`, `system()`, `Runtime.exec()`, `subprocess.call(shell=True)` |
| パストラバーサル | `open(req.params.file)`, `File.read(userInput)` |
| XSS 危険関数 | `innerHTML =`, `document.write(`, `v-html`, `dangerouslySetInnerHTML` |
| エスケープ未使用 | `{{{ }}}`, `<%= raw %>`, `\| safe` |
| CSRF トークン未生成 | `csrf: false`, `csrf_exempt`, `http.csrf().disable()` |
| シークレットハードコード | API キー、AWS キー、JWT 秘密鍵 |
| ログ機微情報出力 | `logger.info(password)`, `console.log(token)` |

## C. 人手確認が必要な項目

| 項目 | 理由 |
| --- | --- |
| 1-(iv) DB アカウント権限の妥当性 | 業務要件次第 |
| 5-(vi) HTML サニタイザ設定の妥当性 | 許可タグ・属性のレビュー |
| 6-(ii) 重要操作の通知メール | 「重要操作」の定義レビュー |
| 9-(i)-b 重要操作前の再認証 | 業務要件依存 |
| 9-(ii) マウスのみ操作不可 | UI/UX 設計レビュー |
| 11-(i) 認証要否そのものの判断 | 機能仕様レビュー |
| 11-(ii) 認可ロジックの完全性 | データモデル・所有関係の理解必要 |
| 10 ネイティブ部分の最小化 | アーキテクチャレビュー |
| 第2条 不要ページの閉鎖判断 | 業務要件依存 |
| 第8条 MFA 適用方針／ロックアウト閾値 | 業務要件依存 |
| 第11条 アカウント棚卸し | 業務要件依存 |
| 第19条 責任分界点の理解 | 契約・運用 |
| 第20条 ペネトレーションテスト実施 | 運用プロセス |
| WAF/IDS の検知ルール妥当性 | セキュリティ運用 |
| DNS 設定の正当性（DNSSEC, SPF/DKIM/DMARC） | DNS 運用 |

---

# Part 4: HTTP セキュリティヘッダ推奨リスト

| ヘッダ | 推奨値 | 関連 |
| --- | --- | --- |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | 第7条 |
| `Content-Security-Policy` | プロジェクト個別。最低でも `default-src 'self'` | XSS（5-(x)） |
| `X-Content-Type-Options` | `nosniff` | 第3条 |
| `X-Frame-Options` | `DENY` または `SAMEORIGIN` | クリックジャッキング（9-(i)-a） |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | プライバシ |
| `Permissions-Policy` | 機能を必要分のみ許可 | プライバシ |
| `Cache-Control` | 機微ページで `no-store` | 情報漏洩 |
| `Server` / `X-Powered-By` | 出力しない | 第5条 |

---

# Part 5: 関連カテゴリ（Skill ルールタグ）

- `injection.sql` / `injection.os` / `injection.header` / `injection.mail`
- `path.traversal`
- `session.cookie` / `session.fixation`
- `xss.output_encoding` / `xss.csp`
- `csrf.token` / `csrf.referer`
- `clickjacking.frame_options`
- `buffer_overflow.lang`
- `access_control.authz`
- `tls.https` / `tls.hsts`
- `password.hash` / `password.policy`
- `error.message` / `log.audit`
- `file.upload` / `file.permission`
- `dependency.cve`

---

# Part 6: CWE 対応表（巻末 p.109〜）

| カテゴリ | 代表 CWE |
| --- | --- |
| SQL i | CWE-89 |
| OS コマンド i | CWE-78 |
| パストラバーサル | CWE-22 |
| セッション管理不備 | CWE-330 / CWE-384 / CWE-522 / CWE-614 |
| XSS | CWE-79 |
| CSRF | CWE-352 |
| HTTP ヘッダ i | CWE-113 |
| メールヘッダ i | CWE-93 |
| クリックジャッキング | 直接対応 CWE なし（CWE-1021） |
| バッファオーバーフロー | CWE-119 / CWE-787 |
| アクセス制御欠落 | CWE-264 / CWE-287 / CWE-639 |

---

# Part 7: 第7版で追加・更新された項目

- 第1章: クリックジャッキング、バッファオーバーフローの脆弱性解説を追加
- 第1章: XSS への対策方法、各脆弱性で紹介している届出状況、参考 URL を更新
- 第2章: ウェブサイトにおけるパスワードの管理方法を追加（ソルト付きハッシュ、ストレッチング）
- 第2章: 通信経路の暗号化（HSTS 含む）、DNS 対策、参考 URL を更新

---

# Part 8: 第2章「ウェブサイトの安全性向上のための取り組み」要点

20ヶ条と重複するが、より詳細な実装ガイダンスがある章。

## 2.3 ネットワーク盗聴への対策

- 重要情報を扱うページの **完全 HTTPS 化**
- HSTS（`Strict-Transport-Security`）の利用
- セッション Cookie の `secure` 属性
- メール通知ではなく HTTPS ページでの重要情報表示
- メール経路の暗号化（S/MIME, PGP）

## 2.4 フィッシング詐欺を助長しないための対策

- EV SSL 証明書の取得（運用面）
- 子フレームの URL を外部パラメータから動的生成しない
- リダイレクト先パラメータは **自サイトドメインのみ許可**
  - 自動チェック観点: `redirect_to params[:url]` のような外部入力→リダイレクト

## 2.5 パスワードに関する対策

| 項目 | 自動チェック観点 |
| --- | --- |
| 初期パスワードを推測困難な文字列で発行 | パスワード生成関数の `crypto`/`secrets` 系利用 |
| パスワード変更時の現行パスワード要求 | パスワード変更エンドポイントでの現行パスワード検証コード |
| 認証応答メッセージの抽象化 | エラーメッセージが「ユーザ ID またはパスワードが違います」 |
| パスワード入力フィールドの伏字 | HTML フォームの `<input type="password">` 使用 |
| **ソルト付きハッシュで保管** | bcrypt/argon2/scrypt/PBKDF2 の使用、`md5/sha1/sha256(password)` のアンチパターン検出 |

## 2.6 WAF によるウェブアプリケーションの保護

- 実装面の対策とは別の防御層として WAF を導入
- 自動チェック観点: ModSecurity / OWASP CRS、AWS WAF、Cloudflare WAF の関連付け（IaC）

---

## 関連ルール ID（運用 + 実装チェックリスト統合）

- IPA-OPS-01-PUBLIC-FILE: 公開すべきでないファイル（第1条）
- IPA-OPS-02-DEAD-PAGE: 不要ページ放置（第2条）
- IPA-OPS-03-SWS-COVERAGE: 安全なウェブサイトの作り方記載項目の網羅（第3条）
- IPA-OPS-04-CVE-DEP: 依存ライブラリの CVE（第4条）
- IPA-OPS-05-ERROR-MSG: エラー詳細露出（第5条）
- IPA-OPS-06-APP-LOG: アプリログ設定（第6条）
- IPA-OPS-07-HTTPS-HSTS: HTTPS / HSTS（第7条）
- IPA-OPS-08-LOGIN-DEFENSE: 不正ログイン対策（第8条）
- IPA-OPS-09-SW-UPDATE: OS/ミドルウェア更新（第9条）
- IPA-OPS-10-MINIMAL-SVC: 不要サービス（第10条）
- IPA-OPS-11-NO-DEFAULT-ACCT: デフォルトアカウント（第11条）
- IPA-OPS-12-PWD-POLICY: パスワード強度（第12条）
- IPA-OPS-13-FILE-PERM: ファイル権限（第13条）
- IPA-OPS-14-WEB-LOG: ウェブサーバログ（第14条）
- IPA-OPS-15-EDGE-FW: 境界遮断（第15条）
- IPA-OPS-16-FW-RULE: FW フィルタリング（第16条）
- IPA-OPS-17-WAF: WAF/IDS/IPS（第17条）
- IPA-OPS-18-NW-LOG: ネットワーク機器ログ（第18条）
- IPA-OPS-19-CLOUD: クラウド責任分界（第19条）
- IPA-OPS-20-AUDIT: 定期検査・監査（第20条）

## 参考

- IPA「安全なウェブサイトの運用管理に向けての20ヶ条」: https://www.ipa.go.jp/security/vuln/websecurity/sitecheck.html
- IPA「安全なウェブサイトの作り方」改訂第7版 PDF: https://www.ipa.go.jp/security/vuln/websecurity/ug65p900000196e2-att/000017316.pdf
- IPA「セキュリティ実装チェックリスト」（xlsx）: https://www.ipa.go.jp/security/vuln/websecurity/ug65p900000196e2-att/000044403.xlsx
- IPA「CWE 概説」: https://www.ipa.go.jp/security/vuln/CWE.html
- IPA「脆弱性関連情報の届出」: https://www.ipa.go.jp/security/vuln/report/index.html
