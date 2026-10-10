---
name: dev-screen-spec
description: This skill should be used when the user asks to "dev-screen-spec", "画面仕様を生成", "画面仕様を更新", "screen spec", "generate screen spec", "update screen spec", "画面仕様ドキュメント". ソースコードから画面仕様ドキュメントを自動生成・差分更新する。受け入れ条件から画面仕様を事前生成する from-plan モードも対応。
argument-hint: '[init|update [screen-id]|from-plan <plan-name>]'
---

# Dev Screen Spec

ソースコードから画面仕様ドキュメント（Screen Spec）を生成・差分更新するスキル。
`docs/dev/screen-specs/` 配下に画面ごとの Markdown with frontmatter 形式で出力する。
webtest 計画の差分更新パイプラインにおいて、ソースコード変更を画面・機能単位の変更に翻訳する中間レイヤーとして機能する。

## 前提知識

### dev-* スキルフロー内の位置

```
[ソースコード変更]  ← dev-impl / 手作業 / 何でも
       │
       │  git diff (last_synced_commit → HEAD)
       ▼
[dev-screen-spec]   ← 手動実行（本スキル）
       │
       │  画面仕様の差分
       ▼
[dev-webtest-plan]  ← 既存の受け入れ要件 + 画面仕様を入力に
       │
       ▼
[dev-webtest]       ← 既存のまま
```

### 引数フォーマット

```
/dev-screen-spec              # 自動判定（初回 or 差分更新）
/dev-screen-spec init         # 強制的に初回生成モード
/dev-screen-spec update       # 強制的に差分更新モード
/dev-screen-spec update login # 特定画面のみ更新
/dev-screen-spec from-plan              # AC変更のある plan を自動検出
/dev-screen-spec from-plan <plan-name>  # 特定の plan を明示指定
```

### モード自動判定

`docs/dev/screen-specs/_index.md` の存在で自動判定する（ユーザー質問不要）:

| モード | 判定条件 | 特徴 |
|-------|---------|------|
| from-plan | 引数が `from-plan` で始まる | 受け入れ条件（AC + plan.md）から画面仕様を生成。ソースコード不要 |
| 初回生成 | `_index.md` が存在しない、または引数 `init` | ソースコード全体を解析して一括生成 |
| 差分更新 | `_index.md` が存在する、または引数 `update` | git diff で影響画面のみ更新 |

### サブエージェント制約（重要）

サブエージェントは Task ツールを使用できない（ネスト不可のアーキテクチャ制約）。そのため:
- コード探索は Glob/Grep/Read を直接使用する
- TodoWrite は使用しない
- サブエージェントに渡すのはファイルパスのみ。サブエージェントが自分で Read する

### コンテキスト管理戦略

メインコンテキストの肥大化を防ぐため、**中間ファイルとパス参照** を使用する:
- メインエージェントはファイルの全文を Read しない（パス存在確認・Grep での部分情報取得のみ）
- サブエージェントに渡すのはファイルパス。サブエージェントが自分で Read する
- Phase 間のデータ受け渡しは中間ファイル経由（`tmp/screen-spec/`）
- サブエージェントの返却はマーカー＋ファイルパス＋行数のみ

### 中間ファイル

```
tmp/screen-spec/
├── explore-routes.md          # Phase 1: ルーティング探索結果
├── explore-pages.md           # Phase 1: ページコンポーネント一覧
├── group-<group-name>.md      # Phase 3: グループサマリー（初回生成）
├── diff-<screen_id>.md        # 差分更新 Phase 2: 各画面の変更サマリー
├── sync-<screen_id>.md        # 差分更新 Phase 1.5: from-plan ソース同期分析
└── from-plan/
    └── screen-analysis.md     # from-plan Phase 2: 画面構成分析結果
```

### 信号機

| 信号 | 基準 |
|------|------|
| 🔵 | ソースコードから直接読み取れた情報（HTML要素、バリデーション属性、ルーティング定義等） |
| 🟡 | ソースコードから推測した情報（コンポーネント名から画面名を推定、import関係からの推論等） |
| 🔴 | AI推論補完（ソースに明示されていないが、一般的なWebアプリとして必要と判断した項目） |

from-plan モードでの信号機基準:
| 信号 | 基準 |
|------|------|
| 🔵 | ACに明示されている情報 |
| 🟡 | plan.md から推測した情報 |
| 🔴 | AI推論補完 |

## ワークフロー: 初回生成モード

### Phase 1: プロジェクト分析（メイン）

1. `docs/dev/context.md` の存在を確認する。存在しない場合は `/dev-context` の実行を案内して終了する
2. `docs/dev/context.md` を Read して技術スタック（フレームワーク、言語）を把握する
3. 中間ファイルディレクトリを作成する:
   ```bash
   mkdir -p "$(git rev-parse --show-toplevel)/tmp/screen-spec"
   ```
4. general-purpose サブエージェントを **2つ並列** で起動する:

#### 1a. ルーティング探索（general-purpose）

1. `references/explore-routes-prompt-template.md` を Read で読み込む
2. テンプレートのプレースホルダーを置換する:
   - `{{CONTEXT_MD_PATH}}` ← `docs/dev/context.md` の絶対パス
   - `{{TMP_DIR}}` ← `tmp/screen-spec/` の絶対パス
3. general-purpose サブエージェントを起動する
4. 出力のマーカーを確認する:
   - `EXPLORE_ROUTES_SUCCESS` → 次へ
   - `EXPLORE_ROUTES_FAILED` → エラー理由をユーザーに報告して終了

#### 1b. ページコンポーネント探索（general-purpose）

1. `references/explore-pages-prompt-template.md` を Read で読み込む
2. テンプレートのプレースホルダーを置換する:
   - `{{CONTEXT_MD_PATH}}` ← `docs/dev/context.md` の絶対パス
   - `{{TMP_DIR}}` ← `tmp/screen-spec/` の絶対パス
3. general-purpose サブエージェントを起動する
4. 出力のマーカーを確認する:
   - `EXPLORE_PAGES_SUCCESS` → 次へ
   - `EXPLORE_PAGES_FAILED` → エラー理由をユーザーに報告して終了

### Phase 2: グループ分割の設計（メイン）

1. Phase 1 の中間ファイルの「パス構造のみ」を Grep で取得する:
   - `tmp/screen-spec/explore-routes.md`
   - `tmp/screen-spec/explore-pages.md`
2. ルーティング情報とページコンポーネント情報を統合する
3. 画面一覧を構成する:
   - 画面ID（ケバブケース）、画面名（日本語）、パス、認証要否を決定
   - 各画面の related_files（対応するソースファイルパス）を決定
4. グループ案を自動生成する（URLパス構造や機能ドメインに基づく）
5. AskUserQuestion でユーザーに確認・調整する:
   - 画面一覧（画面ID, 画面名, パス, グループ）
   - グループ分割案
   - 修正が必要ならユーザーの指示を反映
6. 画面遷移フローを設計する:
   - ルーティング情報とページ間のリンク関係から遷移フローを構成
   - 業務的な意味のあるフロー単位でまとめる
7. 到達不能画面チェックを実施する:
   - 全画面がいずれかのフローに含まれているか検証
   - 含まれていない画面があれば警告リストに追加

### Phase 3: 画面仕様ファイル生成（グループ単位並列サブエージェント）

グループ単位で general-purpose サブエージェントを起動（並列）。1サブエージェントが「グループ内の全画面」を担当する:

1. `references/generate-prompt-template.md` を Read で読み込む
2. テンプレートのプレースホルダーを置換する:
   - `{{GROUP_NAME}}` ← グループ名
   - `{{SCREENS}}` ← グループ内の画面情報一覧（画面ID, 画面名, パス, 認証要否, related_files）
   - `{{SCREEN_SPEC_FORMAT_PATH}}` ← `references/screen-spec-format.md` の絶対パス
   - `{{CONTEXT_MD_PATH}}` ← `docs/dev/context.md` の絶対パス
   - `{{OUTPUT_DIR}}` ← `docs/dev/screen-specs/` の絶対パス
   - `{{TMP_DIR}}` ← `tmp/screen-spec/` の絶対パス
3. general-purpose サブエージェントを起動する
4. サブエージェントの作業:
   - グループ内の全画面仕様ファイルを生成
   - グループサマリーを中間ファイルに出力: `tmp/screen-spec/group-<group-name>.md`
5. 出力のマーカーを確認する:
   - `GENERATE_SCREEN_SPEC_SUCCESS` → 完了
   - `GENERATE_SCREEN_SPEC_FAILED` → エラー理由を記録

複数グループがある場合は並列で実行する（Agent ツールを複数同時起動）。

### Phase 4: 完了処理（メイン）

1. グループサマリー（パス＋行数のみ）から `_index.md` を組み立てる:
   - 画面一覧テーブル（Phase 2 の設計に基づく）
   - グループ情報
   - 画面遷移フロー（Phase 2 の設計に基づく）
   - 到達不能画面チェック結果
   - frontmatter: `last_synced_commit` を現在の HEAD に設定、`updated_at` を今日の日付に設定、`groups` を設定
2. `_index.md` の frontmatter にグループ情報を含める:
   ```yaml
   ---
   last_synced_commit: abc1234
   updated_at: "2026-03-10"
   groups:
     - name: user-management
       screens: [user-list, user-detail, user-create]
     - name: auth
       screens: [login, forgot-password]
     - name: settings
       screens: [user-settings]
   ---
   ```
3. 全ファイルの `last_synced_commit` を現在の HEAD（短縮形）に設定する:
   ```bash
   git rev-parse --short HEAD
   ```
4. 生成結果のサマリーを表示する:

```markdown
## dev-screen-spec 完了レポート（初回生成）

### 生成概要
- 画面数: N
- グループ数: N
- 生成ファイル数: N + 1（_index.md 含む）
- last_synced_commit: <commit hash>

### 生成ファイル一覧

| ファイル | 画面名 | パス | グループ | 項目数 | 🔵 | 🟡 | 🔴 |
|---------|--------|------|---------|--------|-----|-----|-----|
| _index.md | 画面一覧 | - | - | - | - | - | - |
| login.md | ログイン | /login | auth | 4 | 3 | 1 | 0 |
| ...

### ⚠️ 🔴 警告
以下の項目はソースコードに根拠がなく、AI が推論で追加しました。内容を確認してください:
- <ファイル名> <セクション>: <項目名>

### ⚠️ 到達不能画面
- <画面ID>: いずれの遷移フローにも含まれていません

### 次のステップ
- 画面仕様の内容を確認してください
- 差分更新: ソースコード変更後に `/dev-screen-spec` を再実行
- テスト計画生成: `/dev-webtest-plan` で画面仕様を入力としてテスト計画を生成
```

5. 中間ファイルをクリーンアップする:
   ```bash
   rm -rf "$(git rev-parse --show-toplevel)/tmp/screen-spec/"
   ```

## ワークフロー: 差分更新モード

### Phase 1: 変更検知（メイン）

1. `docs/dev/screen-specs/_index.md` の `last_synced_commit` を Grep で取得する
2. `last_synced_commit` が現在の git history に存在するか確認する:
   ```bash
   git cat-file -t <last_synced_commit>
   ```
   存在しない場合 → ユーザーに「初回生成モードで再生成」を提案して終了
3. `git diff --name-only <last_synced_commit>..HEAD` で変更ファイル一覧を取得する
4. 変更ファイルが50件を超える場合 → ユーザーに確認後、初回生成モードにフォールバック
5. 各画面の `related_files` を Grep で取得し、変更ファイル一覧と突き合わせる:
   ```
   影響判定ロジック:
   - related_files に含まれるファイルが変更されている → 影響あり
   - related_files に含まれないが、ルーティング定義が変更されている → 新画面追加の可能性
   - related_files のファイルが削除されている → 画面削除の可能性
   ```
6. 特定画面のみ更新（引数で `screen-id` 指定時）の場合は、その画面のみを対象にする
7. 影響画面がない場合 → 「変更なし」を表示して終了
8. 影響画面の一覧を表示する
9. 中間ファイルディレクトリを作成する:
   ```bash
   mkdir -p "$(git rev-parse --show-toplevel)/tmp/screen-spec"
   ```

### Phase 1.5: from-plan 画面のソース同期判定（メイン）

1. `source: from-plan` かつ `last_synced_commit: null` の画面を Grep で検出する
2. 該当画面がある場合:
   a. 各画面の `related_files` が空なので、ルーティング情報から対応するソースファイルを特定する
   b. ソースファイルが見つかった画面について、general-purpose サブエージェントで分析（画面数分並列）:
      - 既存の画面仕様（from-plan）を Read
      - ソースファイルを Read
      - 差分（from-plan の内容 vs ソースの実装）を表示用にまとめる
      - 中間ファイルに出力: `tmp/screen-spec/sync-<screen_id>.md`
      - マーカー: `SYNC_ANALYZE_SUCCESS` / `SYNC_ANALYZE_FAILED`
   c. 各画面について AskUserQuestion で解決方法を選ばせる:
      - 「ソースを採用」: ソースコードの実装状態で画面仕様を上書き
      - 「from-plan を維持」: 画面仕様はそのまま（実装が仕様と異なる場合は実装を修正すべき）
      - 「マージ」: 両方の情報を統合（サブエージェントがマージ実行）
   d. 選択結果に基づいて画面仕様を更新、`source: from-source`, `last_synced_commit: HEAD` に変更
3. 該当画面がない場合: 通常の差分更新フローに進む

### Phase 2: 差分内容の分析（グループ単位並列サブエージェント）

影響のある画面が属するグループ単位で general-purpose サブエージェントを起動（並列）:

1. `references/diff-analyze-prompt-template.md` を Read で読み込む
2. テンプレートのプレースホルダーを置換する:
   - `{{SCREEN_ID}}` ← 画面ID
   - `{{LAST_SYNCED_COMMIT}}` ← last_synced_commit
   - `{{RELATED_FILES}}` ← その画面の related_files 一覧
   - `{{EXISTING_SCREEN_SPEC_PATH}}` ← 既存の画面仕様ファイルパス
   - `{{TMP_DIR}}` ← `tmp/screen-spec/` の絶対パス
3. general-purpose サブエージェントを起動する
4. 出力のマーカーを確認する:
   - `DIFF_ANALYZE_SUCCESS` → Phase 3 へ
   - `DIFF_ANALYZE_FAILED` → エラー理由を記録

### Phase 3: 画面仕様の更新（グループ単位並列サブエージェント）

グループ単位で general-purpose サブエージェントを起動（並列）:

1. `references/diff-update-prompt-template.md` を Read で読み込む
2. テンプレートのプレースホルダーを置換する:
   - `{{SCREEN_ID}}` ← 画面ID
   - `{{DIFF_SUMMARY_PATH}}` ← `tmp/screen-spec/diff-<screen_id>.md` の絶対パス
   - `{{EXISTING_SCREEN_SPEC_PATH}}` ← 既存の画面仕様ファイルパス
   - `{{SCREEN_SPEC_FORMAT_PATH}}` ← `references/screen-spec-format.md` の絶対パス
   - `{{OUTPUT_DIR}}` ← `docs/dev/screen-specs/` の絶対パス
3. general-purpose サブエージェントを起動する
4. 出力のマーカーを確認する:
   - `UPDATE_SCREEN_SPEC_SUCCESS` → 完了
   - `UPDATE_SCREEN_SPEC_FAILED` → エラー理由を記録

### Phase 4: 新画面・削除画面の処理（メイン）

- **新画面**: ルーティング変更が検出された場合、初回生成モードの Phase 3 と同様に生成する
- **削除画面**: ソースファイルが全て削除されている画面は、ユーザーに削除を確認する

### Phase 5: 完了処理（メイン）

1. `_index.md` を更新する:
   - 画面一覧テーブルの更新（新規追加・削除を反映）
   - グループ情報の更新
   - 画面遷移フローの更新
   - 到達不能画面チェックの再実施
   - `last_synced_commit` を HEAD に更新、`updated_at` を今日の日付に更新
2. 全更新ファイルの `last_synced_commit` を更新する
3. 変更サマリーを表示する:

```markdown
## dev-screen-spec 完了レポート（差分更新）

### 更新概要
- 前回同期: <last_synced_commit> → 今回: <HEAD>
- 変更ファイル数: N
- 影響画面数: N

### 更新画面一覧

| 画面ID | 画面名 | 変更セクション | 変更概要 |
|--------|--------|-------------|---------|
| login | ログイン | バリデーション | パスワード最低文字数を6→8に変更 |

### 新規追加画面
- <画面ID>: <画面名>

### 削除画面
- <画面ID>: <画面名>（ユーザー確認済み）

### ⚠️ 🔴 警告
以下の項目はソースコードに根拠がなく、AI が推論で追加しました:
- <ファイル名> <セクション>: <項目名>

### ⚠️ 到達不能画面
- <画面ID>: いずれの遷移フローにも含まれていません
```

4. 中間ファイルをクリーンアップする:
   ```bash
   rm -rf "$(git rev-parse --show-toplevel)/tmp/screen-spec/"
   ```

## ワークフロー: from-plan モード

### Phase 0: 対象 plan の特定（メイン）

plan-name が明示指定されている場合はそのまま Phase 1 へ進む。省略されている場合は自動検出する:

1. `docs/dev/screen-specs/_index.md` が存在する場合:
   a. `last_synced_commit` を Grep で取得する
   b. 以下のコマンドで AC が変更された plan を検出する:
      ```bash
      git diff --name-only <last_synced_commit>..HEAD -- docs/dev/plans/*/acceptance-criteria.md
      ```
   c. 結果のパスから plan 名を抽出する（例: `docs/dev/plans/auth/acceptance-criteria.md` → `auth`）
2. `_index.md` が存在しない場合:
   a. Glob で `docs/dev/plans/*/acceptance-criteria.md` を取得する
   b. 全 plan を候補にする
3. 候補が0件 → 「対象の plan がありません」と報告して終了
4. 候補が1件 → そのまま Phase 1 へ進む
5. 候補が複数 → AskUserQuestion で選択する:
   ```
   以下の plan の acceptance-criteria.md が変更されています。対象を選んでください:
   1. auth
   2. user-management
   (all で全部、カンマ区切りで複数選択可)
   ```
6. 複数 plan が選択された場合、選択された plan を **順番に** Phase 1〜5 のワークフローを繰り返す

### Phase 1: 入力検証（メイン）

1. `docs/dev/context.md` の存在を確認する。存在しない場合は `/dev-context` の実行を案内して終了する
2. `docs/dev/plans/<plan-name>/acceptance-criteria.md` の存在を確認する。存在しない場合は「Full-spec モードの `/dev-plan` で受け入れ条件を作成してください」と案内して終了する
3. `docs/dev/plans/<plan-name>/plan.md` の存在を確認する（任意だが推奨）
4. 既存の `docs/dev/screen-specs/_index.md` がある場合、既存画面仕様への追加になることを通知する
5. 中間ファイルディレクトリを作成する: `mkdir -p tmp/screen-spec/from-plan/`

### Phase 2: 画面構成分析（general-purpose サブエージェント）

1. `references/from-plan-analyze-prompt-template.md` を Read で読み込む
2. テンプレートのプレースホルダーを置換する:
   - `{{ACCEPTANCE_CRITERIA_PATH}}` ← acceptance-criteria.md の絶対パス
   - `{{PLAN_MD_PATH}}` ← plan.md の絶対パス（存在しない場合は「なし」）
   - `{{EXISTING_INDEX_PATH}}` ← 既存の _index.md の絶対パス（存在しない場合は「なし」）
   - `{{TMP_DIR}}` ← `tmp/screen-spec/from-plan/` の絶対パス
3. general-purpose サブエージェントを起動する
4. 出力: `tmp/screen-spec/from-plan/screen-analysis.md`（画面一覧、各画面の要件、グループ案）
5. マーカー: `FROM_PLAN_ANALYZE_SUCCESS` / `FROM_PLAN_ANALYZE_FAILED`

### Phase 3: ユーザー確認（メイン）

1. 中間ファイルの画面一覧とグループ案を Grep で要約取得する
2. AskUserQuestion でユーザーに確認する:
   - 画面一覧（画面ID, 画面名, パス, グループ）
   - グループ分割
   - 修正が必要ならユーザーの指示を反映

### Phase 4: 画面仕様ファイル生成（並列 general-purpose サブエージェント）

グループ単位でサブエージェントを起動（並列）:

1. `references/from-plan-generate-prompt-template.md` を Read で読み込む
2. テンプレートのプレースホルダーを置換する:
   - `{{GROUP_NAME}}` ← グループ名
   - `{{SCREEN_ANALYSIS_PATH}}` ← `tmp/screen-spec/from-plan/screen-analysis.md` の絶対パス
   - `{{ACCEPTANCE_CRITERIA_PATH}}` ← acceptance-criteria.md の絶対パス
   - `{{PLAN_MD_PATH}}` ← plan.md の絶対パス
   - `{{SCREEN_SPEC_FORMAT_PATH}}` ← `references/screen-spec-format.md` の絶対パス
   - `{{PLAN_NAME}}` ← plan 名
   - `{{OUTPUT_DIR}}` ← `docs/dev/screen-specs/` の絶対パス
3. サブエージェントの作業:
   - ACとplan.mdを Read
   - グループ内の各画面について画面仕様ファイルを生成
   - frontmatter に `source: from-plan`, `source_plan: <plan-name>`, `last_synced_commit: null` を設定
   - `related_files` は空（ソースがまだないため）
   - 信号機: ACに明示 → 🔵、plan.mdから推測 → 🟡、AI推論 → 🔴
4. マーカー: `FROM_PLAN_GENERATE_SUCCESS` / `FROM_PLAN_GENERATE_FAILED`

### Phase 5: 完了処理（メイン）

1. `_index.md` を生成または更新する:
   - 画面一覧テーブル
   - グループ情報
   - 画面遷移フロー（ACから読み取れる範囲）
   - frontmatter: `last_synced_commit` は現在の HEAD、`updated_at` は今日の日付
2. 完了レポートを表示する:

```markdown
## dev-screen-spec 完了レポート（from-plan）

### 生成概要
- Source Plan: <plan-name>
- 画面数: N
- グループ数: N

### 生成ファイル一覧

| ファイル | 画面名 | パス | グループ | 🔵 | 🟡 | 🔴 |
|---------|--------|------|---------|-----|-----|-----|
| login.md | ログイン | /login | auth | 3 | 1 | 0 |

### ⚠️ 注意
これらの画面仕様は受け入れ条件から生成されたものです。
実装後に `/dev-screen-spec update` を実行してソースコードと同期してください。

### 次のステップ
- 画面仕様の内容をレビューしてください
- `/dev-webtest-plan <plan-name>` でテスト計画を生成
- `/dev-impl <plan-name>` で実装を開始
- 実装後: `/dev-screen-spec update` でソースコードと同期
```

3. 中間ファイルをクリーンアップする

## サブエージェント戦略

| Phase | タイプ | 用途 | 並列 |
|-------|-------|------|------|
| 初回 1a | general-purpose | ルーティング探索 | 1b と並列 |
| 初回 1b | general-purpose | ページコンポーネント探索 | 1a と並列 |
| 初回 3 | general-purpose | グループ単位で画面仕様生成 | グループ数分並列 |
| 差分 1.5 | general-purpose | from-plan ソース同期分析 | 画面数分並列 |
| 差分 2 | general-purpose | git diff の分析と変更サマリー出力 | グループ単位並列 |
| 差分 3 | general-purpose | 画面仕様ファイル更新 | グループ単位並列 |
| from-plan 2 | general-purpose | 画面構成分析 | 単独 |
| from-plan 4 | general-purpose | グループ単位で画面仕様生成 | グループ数分並列 |

## エスカレーション条件

以下の場合は自動処理を停止し、ユーザーに確認する:

1. **context.md 不在**: `/dev-context` を案内して終了
2. **last_synced_commit が git history にない**: rebase や force push 後。「初回生成モードで再生成」を提案
3. **変更ファイルが50件超**: ユーザーに確認後、初回生成モードにフォールバック
4. **画面削除の検出**: ユーザーに削除を確認
5. **related_files のファイルが存在しない**: 該当画面の related_files を再探索
6. **acceptance-criteria.md 不在（from-plan時）**: 「Full-spec モードの `/dev-plan` で受け入れ条件を作成してください」と案内して終了
7. **from-plan 画面のソース同期で対応ソースが見つからない**: 該当画面をスキップし、ユーザーに報告（実装がまだの可能性）

## マーカー文字列

| マーカー | 意味 |
|---------|------|
| `EXPLORE_ROUTES_SUCCESS` | ルーティング探索成功 |
| `EXPLORE_ROUTES_FAILED` | ルーティング探索失敗 |
| `EXPLORE_PAGES_SUCCESS` | ページコンポーネント探索成功 |
| `EXPLORE_PAGES_FAILED` | ページコンポーネント探索失敗 |
| `GENERATE_SCREEN_SPEC_SUCCESS` | 画面仕様ファイル生成成功 |
| `GENERATE_SCREEN_SPEC_FAILED` | 画面仕様ファイル生成失敗 |
| `DIFF_ANALYZE_SUCCESS` | 差分分析成功 |
| `DIFF_ANALYZE_FAILED` | 差分分析失敗 |
| `UPDATE_SCREEN_SPEC_SUCCESS` | 画面仕様更新成功 |
| `UPDATE_SCREEN_SPEC_FAILED` | 画面仕様更新失敗 |
| `FROM_PLAN_ANALYZE_SUCCESS` | from-plan 画面構成分析成功 |
| `FROM_PLAN_ANALYZE_FAILED` | from-plan 画面構成分析失敗 |
| `FROM_PLAN_GENERATE_SUCCESS` | from-plan 画面仕様生成成功 |
| `FROM_PLAN_GENERATE_FAILED` | from-plan 画面仕様生成失敗 |
| `SYNC_ANALYZE_SUCCESS` | from-plan ソース同期分析成功 |
| `SYNC_ANALYZE_FAILED` | from-plan ソース同期分析失敗 |

## ルール・制約

- context.md が存在しない場合は `/dev-context` を案内して終了する
- モード判定は自動（ユーザー質問不要）
- `docs/dev/screen-specs/` が存在しない場合は自動作成する
- 画面仕様ファイルはソースコードの「現在の状態」を反映する（あるべき姿ではなく実装の状態）
- from-plan モードで生成された画面仕様は受け入れ条件に基づく（実装前の仕様）
- 差分更新ではソースコードの変更のみを反映する（仕様変更の推測はしない）
- related_files はソース内の import/include 関係を辿って特定する（手動メンテ不要）
- 1画面1ファイルの原則を維持する（複合ページでも画面単位で分割）
- 中間ファイルはスキル完了時に必ず削除する
- Bash コマンドはプロジェクトルートの **絶対パス** を使用する（`$(git rev-parse --show-toplevel)` でルートを取得）
- サブエージェントは Task/TodoWrite 使用禁止
- メインエージェントはファイル全文を Read しない（パス確認・Grep のみ）
- サブエージェントにはファイルパスを渡し、サブエージェントが自分で Read する
- Phase 間のデータ受け渡しは中間ファイル（`tmp/screen-spec/`）経由
- サブエージェントはマーカー＋ファイルパス＋行数のみ返す（結果本文は返さない）
- 🔴 は完了レポートで警告表示する

## 追加リソース

### リファレンスファイル

- **`references/screen-spec-format.md`** — 画面仕様ドキュメントの出力フォーマット定義
- **`references/explore-routes-prompt-template.md`** — Phase 1: ルーティング探索用プロンプトテンプレート
- **`references/explore-pages-prompt-template.md`** — Phase 1: ページコンポーネント探索用プロンプトテンプレート
- **`references/generate-prompt-template.md`** — Phase 3: 画面仕様ファイル生成用プロンプトテンプレート
- **`references/diff-analyze-prompt-template.md`** — 差分更新 Phase 2: 変更分析用プロンプトテンプレート
- **`references/diff-update-prompt-template.md`** — 差分更新 Phase 3: 画面仕様更新用プロンプトテンプレート
- **`references/from-plan-analyze-prompt-template.md`** — from-plan Phase 2: 画面構成分析用プロンプトテンプレート
- **`references/from-plan-generate-prompt-template.md`** — from-plan Phase 4: 画面仕様ファイル生成用プロンプトテンプレート
