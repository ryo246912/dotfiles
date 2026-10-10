# Lightweight モード シナリオ推論ガイド

Lightweight モード（acceptance-criteria.md が存在しない場合）において、タスクファイルの情報から webtest シナリオを推論するためのガイド。

---

## 推論の情報源と優先順位

Lightweight モードでは以下の情報源を優先順位順に使用する:

| 優先順位 | 情報源 | セクション | 信号 |
|---------|--------|-----------|------|
| 1 | タスクファイル | Test Strategy | 🟡 |
| 2 | タスクファイル | Goal | 🟡 |
| 3 | タスクファイル | Files | 🟡 |
| 4 | plan.md | Requirements Summary / Design Overview | 🟡 |
| 5 | 実装コード | HTML/テンプレート/ルーティング | 🟡（コード確認時） |
| 6 | Web テストベストプラクティス | — | 🔴 |

**重要**: Lightweight モードでは 🔵 は付与しない（AC による直接的な根拠がないため）。

---

## タスクファイルからの推論ルール

### Test Strategy → シナリオ

タスクの Test Strategy の各項目を画面テストの観点に変換する:

| Test Strategy の記述パターン | 推論するシナリオ |
|---------------------------|---------------|
| 「X を入力すると Y が返る」 | フォーム入力 → 結果表示のシナリオ |
| 「X のバリデーションエラー」 | フォームバリデーション確認テーブルに追加 |
| 「X ページが表示される」 | ページアクセス → 表示確認のシナリオ |
| 「X をクリックすると Y に遷移」 | ナビゲーション確認のシナリオ |
| 「X の一覧が表示される」 | 一覧表示 → データ確認のシナリオ |
| 「X を削除すると一覧から消える」 | 削除操作 → 一覧更新確認のシナリオ |
| 「認証エラー時に 401 が返る」 | 未認証アクセス → エラー画面表示のシナリオ |

**変換例**:

タスク Test Strategy:
```
- [ ] 有効なメール+パスワードでログインするとAuthResultが返る
- [ ] 無効なパスワードでログインするとAuthErrorが投げられる
- [ ] 空文字のメールでログインするとValidationErrorが投げられる
```

推論シナリオ:
```markdown
<!-- 🟡 source: task-002 Test Strategy -->
### シナリオ1: 正常なログイン
**手順**: ...
**期待結果**: ログイン後の画面に遷移する

<!-- 🟡 source: task-002 Test Strategy -->
### シナリオ2: パスワード誤りでログイン失敗
**手順**: ...
**期待結果**: エラーメッセージが表示される

<!-- 🟡 source: task-002 Test Strategy -->
### シナリオ3: メールアドレス空でバリデーションエラー
**手順**: ...
**期待結果**: バリデーションエラーが表示される
```

### Goal → シナリオの方向性

Goal が提供する情報は、シナリオ全体の方向性の決定に使う:

| Goal の記述パターン | 推論方向 |
|------------------|---------|
| 「X 画面を実装する」 | その画面の表示・操作テスト |
| 「X 機能を追加する」 | 機能の正常系・異常系テスト |
| 「X を修正する」 | 修正後の動作確認テスト |
| 「X の API を実装する」 | API に対応する画面があればテスト、なければスキップ |

### Files → target-url の推定

Files セクションから画面の URL を推定する:

| Files のパターン | URL 推定 |
|----------------|---------|
| `internal/handler/auth.go` | `/login`, `/register`, `/logout` |
| `internal/handler/user.go` | `/users`, `/users/:id` |
| `templates/pages/dashboard.templ` | `/dashboard` |
| `templates/pages/settings.templ` | `/settings` |
| `static/js/form-validation.js` | フォームを含むページ |

**推定ルール**:
1. ハンドラーファイルのルーティング定義を推定
2. テンプレートファイル名からパスを推定
3. 複数候補がある場合は最も一般的なパスを選択し `（推定）` を付記

---

## 画面が存在するかの判定

タスクが画面に関係するかを判定する基準:

### 画面関連と判定するパターン

- Files に `templates/`, `views/`, `pages/` を含むファイルがある
- Files に `static/css/`, `static/js/` を含むファイルがある
- Files に `handler/` を含むファイルがある（API専用ハンドラーを除く）
- Goal に「画面」「ページ」「フォーム」「表示」「UI」のキーワードがある
- Test Strategy に「表示される」「クリック」「入力」のキーワードがある

### 画面関連でないと判定するパターン

- Files が `internal/service/`, `internal/repository/` のみ
- Goal が「API」「バッチ」「マイグレーション」「CLI」に関するもの
- Test Strategy が「返る」「投げられる」のみで画面操作を含まない

画面関連でないタスクは webtest plan の対象外としてスキップする。

---

## ベストプラクティスによる補完（🔴）

前工程に根拠がない場合でも、Web テストとして推奨されるシナリオを 🔴 で追加する:

### 追加を検討するシナリオ

| カテゴリ | シナリオ | 追加条件 |
|---------|---------|---------|
| セキュリティ | XSS 入力テスト | フォームが存在する場合 |
| セキュリティ | 未認証アクセス拒否 | 認証が必要なページの場合 |
| エラーハンドリング | 404 ページ表示 | ルーティングが存在する場合 |
| エラーハンドリング | サーバーエラー時の表示 | フォーム送信がある場合 |
| アクセシビリティ | キーボード操作 | すべてのページ |
| レスポンシブ | モバイル表示 | すべてのページ |

### 追加しないシナリオ

- タスクのスコープ外の画面に関するテスト
- 他の webtest plan で既にカバーされているテスト
- インフラ・DB レベルの障害テスト

---

## APIセットアップ/クリーンアップの推論

Lightweight モードでもタスク情報からAPIセットアップ/クリーンアップを推論する。

### 推論の情報源と優先順位

| 優先順位 | 情報源 | 推論内容 | 信号 |
|---------|--------|---------|------|
| 1 | タスクファイル Interfaces | API型定義からエンドポイント・ボディを推定 | 🔴 |
| 2 | タスクファイル Files | handler/route ファイルからエンドポイントを推定 | 🔴 |
| 3 | タスクファイル Test Strategy | テスト前提のデータ要件を推定 | 🔴 |
| 4 | 実装コード（Phase 2b） | ルーティング定義から確認済みエンドポイントを取得 | 🟡 |
| 5 | 既存API仕様（自動探索） | openapi.yaml等から確認済みエンドポイントを取得 | 🔵（仕様確認時のみ） |

**重要**: Lightweight モードでは情報源 1-3 のみの場合は 🔴 が主体となる。コード探索やAPI仕様で確認できた場合のみ 🟡/🔵 に昇格する。

### タスク情報からのAPI推論パターン

| タスク情報のパターン | 推論するAPIセットアップ |
|-------------------|---------------------|
| Goal「ユーザー管理画面を実装」+ Files に handler/user.go | POST /api/users でテストユーザー作成 |
| Test Strategy「一覧にデータが表示される」 | 対象リソースの作成APIで複数件データ登録 |
| Test Strategy「削除すると一覧から消える」 | 削除対象データの事前作成API |
| Goal「注文フローを実装」+ Interfaces に Order型 | POST /api/orders で注文データ作成 |
| Test Strategy「ログイン成功」+ Files に handler/auth.go | POST /api/users でテストユーザー作成（セットアップ）+ POST /api/auth/login でトークン取得 |

### Files からのAPIエンドポイント推定

| Files のパターン | 推定エンドポイント |
|----------------|----------------|
| `internal/handler/user.go` | GET/POST/PUT/DELETE /api/users |
| `internal/handler/auth.go` | POST /api/auth/login, POST /api/auth/logout |
| `internal/handler/order.go` | GET/POST/PUT/DELETE /api/orders |
| `src/routes/api/products.ts` | GET/POST/PUT/DELETE /api/products |

### クリーンアップの推論

セットアップで作成したリソースに対応するDELETEエンドポイントを推論する:

- POST /api/users → DELETE /api/users/:id（or /api/users/:email）
- POST /api/orders → DELETE /api/orders/:id
- DELETEエンドポイントが不明な場合はコメントで `# TODO: 適切なクリーンアップAPIを確認` を記載

### API仕様の自動探索

以下のパスを自動探索し、存在する場合はAPI情報源として使用する:

```
openapi.yaml, openapi.json
swagger.yaml, swagger.json
docs/api/*, api-docs/*
*.openapi.yaml, *.swagger.json
```

## draft: true 時の注意事項

Lightweight モードかつ実装コード未確認の場合は `draft: true` となる:

- UI 要素名は推定値を使用し `（推定）` を付記する
- URL は Files セクションからの推定値を使用する
- 「dev-impl 完了後に `/dev-webtest-plan` を再実行して draft: false に更新してください」と完了レポートに記載する
