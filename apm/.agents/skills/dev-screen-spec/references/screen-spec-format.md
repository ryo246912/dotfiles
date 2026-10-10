# 画面仕様ドキュメント 出力フォーマット定義

サブエージェントが画面仕様ファイルを生成・更新する際に準拠するフォーマット定義。

## 配置

```
docs/dev/screen-specs/
├── _index.md          # 画面一覧とルーティング
├── login.md
├── dashboard.md
├── user-settings.md
└── ...
```

---

## _index.md（画面一覧）

### frontmatter

```yaml
---
last_synced_commit: abc1234
updated_at: "2026-03-09"
groups:
  - name: auth
    screens: [login, forgot-password]
  - name: user-management
    screens: [user-list, user-detail, user-create]
  - name: settings
    screens: [user-settings]
---
```

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `last_synced_commit` | string | dev-screen-spec 最終同期時の commit hash（短縮形） |
| `updated_at` | string | 最終更新日（YYYY-MM-DD） |
| `groups` | object[] | 画面のグループ分割。各グループに name と screens（画面ID配列）を持つ |

### 本文構造

```markdown
# 画面一覧

| 画面ID | 画面名 | パス | 認証 | 備考 |
|--------|--------|------|------|------|
| login | ログイン | /login | 不要 | |
| dashboard | ダッシュボード | /dashboard | 必要 | |
| user-list | ユーザー一覧 | /users | 必要 | |
| user-detail | ユーザー詳細 | /users/:id | 必要 | |

## 画面遷移フロー

### 認証フロー
login → dashboard

### ユーザー管理 CRUD フロー
user-list → user-create → user-list
user-list → user-detail → user-list

### ユーザー登録→確認フロー
user-create --[登録ボタン]--> user-detail --[一覧に戻る]--> user-list

### グローバルナビゲーション
dashboard → user-list
dashboard → user-settings
user-list → dashboard
user-settings → dashboard

## 到達不能画面チェック
<!-- dev-screen-spec が自動生成: 全画面がいずれかのフローに含まれているか検証 -->
- ⚠️ なし（全画面に到達経路あり）
```

### 画面遷移フロー記法

```
<画面ID> → <画面ID>                          # 単純遷移
<画面ID> --[アクション名]--> <画面ID>          # アクション付き遷移
<画面ID> → <画面ID> → <画面ID>               # 連続遷移
```

- 各フローに名前をつけて `###` 見出しで管理する
- 業務的な意味のあるフロー単位でまとめる（CRUD、認証、特定業務フローなど）
- 全画面がいずれかのフローに含まれていることを「到達不能画面チェック」で検証する
- 到達不能画面があれば `⚠️ <画面ID>: いずれの遷移フローにも含まれていません` で警告する

---

## 個別画面ファイル

### frontmatter

```yaml
---
screen_id: login
screen_name: ログイン
path: /login
auth_required: false
source: from-source
source_plan: null
last_synced_commit: abc1234
updated_at: "2026-03-09"
related_files:
  - src/pages/login.tsx
  - src/components/LoginForm.tsx
  - src/api/auth.ts
---
```

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `screen_id` | string | 画面の一意ID（ケバブケース） |
| `screen_name` | string | 画面の日本語名 |
| `path` | string | URLパス |
| `auth_required` | boolean | 認証が必要か |
| `source` | string | 生成元。`from-source`（ソースコードから生成）または `from-plan`（受け入れ条件から生成） |
| `source_plan` | string/null | from-plan の場合の元 plan 名。from-source の場合は null |
| `last_synced_commit` | string/null | この画面を最後に同期した commit hash（短縮形）。from-plan で未同期の場合は null |
| `updated_at` | string | 最終更新日（YYYY-MM-DD） |
| `related_files` | string[] | この画面に関連するソースファイルのパス。from-plan で未同期の場合は空配列 |

### 本文構造

```markdown
# <画面名>

<画面の概要（1-2文）>

## 画面項目

| # | 項目名 | 種別 | 必須 | 説明 |
|---|--------|------|------|------|
| 1 | メールアドレス | text input | Yes | ユーザーのメールアドレス |
| 2 | パスワード | password input | Yes | 8文字以上 |
| 3 | ログインボタン | button | - | フォーム送信 |
| 4 | パスワードを忘れた方 | link | - | /forgot-password へ遷移 |

## バリデーション

| 項目 | ルール | エラーメッセージ |
|------|--------|-----------------|
| メールアドレス | 必須 | メールアドレスを入力してください |
| メールアドレス | メール形式 | 正しいメールアドレスを入力してください |
| パスワード | 必須 | パスワードを入力してください |
| パスワード | 8文字以上 | パスワードは8文字以上で入力してください |

## インタラクション

### ログイン成功
- ログインボタン押下 → API呼び出し → /dashboard へリダイレクト

### ログイン失敗
- ログインボタン押下 → API呼び出し → エラーメッセージ「メールアドレスまたはパスワードが正しくありません」を表示

### パスワード表示切替
- パスワードフィールドの目アイコン押下 → パスワードの表示/非表示が切り替わる

## 状態

| 状態 | 条件 | 表示内容の変化 |
|------|------|---------------|
| 初期表示 | ページ読み込み時 | フォームは空、ボタンは活性 |
| 送信中 | APIリクエスト中 | ボタン非活性、ローディング表示 |
| エラー | API 401応答 | エラーメッセージ表示 |

## 備考

- ソーシャルログイン（Google, GitHub）は Phase 2 で追加予定
```

---

## 信号機の付与ルール

各セクションの項目に信号機を付与する。信号機はテーブルの備考欄やインタラクション見出しの末尾にコメントとして記載する。

```markdown
| 1 | メールアドレス | text input | Yes | ユーザーのメールアドレス <!-- 🔵 --> |

### ログイン成功 <!-- 🔵 -->

| 初期表示 | ページ読み込み時 | フォームは空、ボタンは活性 <!-- 🟡 --> |
```

| 信号 | 基準 |
|------|------|
| 🔵 | ソースコードから直接読み取れた情報（HTML要素、バリデーション属性、ルーティング定義、エラーメッセージ文字列等） |
| 🟡 | ソースコードから推測した情報（コンポーネント名からの推定、コードの制御フローからの推論等） |
| 🔴 | AI推論補完（ソースに明示されていないが一般的なWebアプリとして必要と判断した項目） |

---

## セクションの独立性

各セクションは独立しており、差分更新時に特定セクションだけを更新可能:

- **画面項目** → webtest の要素確認シナリオ
- **バリデーション** → webtest のフォームバリデーション確認
- **インタラクション** → webtest のテストシナリオ（手順＋期待結果）
- **状態** → webtest の状態遷移テスト

## related_files による変更検知

- git diff の変更ファイル一覧と `related_files` を突き合わせることで、影響のある画面を高速に特定できる
- LLM に全 diff を読ませる必要がなく、トークン消費を抑えられる
- import/include 関係を辿って related_files を特定する（手動メンテ不要）

## from-plan モードによる設計先行

- 新規開発時は受け入れ条件（AC + plan.md）から画面仕様を先に生成し、レビュー後に実装に進む
- 実装後の `dev-screen-spec update` でソースコードと同期する際、from-plan の内容と実装の差分をユーザーが解決する
- 画面仕様が「設計書」（from-plan）と「実装の翻訳」（from-source）の両方の役割を果たす
- from-plan で生成された画面は `source: from-plan`, `last_synced_commit: null`, `related_files: []` で識別可能

## グループによる大規模プロジェクト対応

- 画面をグループ単位（業務ドメイン、URL プレフィックス等）に分割して管理する
- `_index.md` の frontmatter にグループ情報を記録し、バッチ処理・差分更新の単位として使用する
- コンテキスト肥大化を防ぐため、サブエージェントはグループ単位で起動する（1サブエージェント = 1グループ内の全画面）
- グループ分割はスキル実行時に自動提案し、AskUserQuestion でユーザーが確認・調整する
