---
name: dev-webtest
description: This skill should be used when the user asks to "dev-webtest", "Webテスト", "画面の動作確認", "E2Eテスト", "web test", "visual check", "モンキーテスト", "アクセシビリティチェック", "レスポンシブテスト", "フォームテスト". Playwright CLIを使ってWebアプリの動作確認・視覚テスト・アクセシビリティ・レスポンシブ・フォームバリデーションを実行し、問題を検出・記録する。
argument-hint: '<plan-name> [--parallel N] | monkey <url> | check <url> | retest'
---

# Dev Webtest

Playwright CLI (`@playwright/cli`) を使ったWebアプリケーションの動作確認・視覚テスト・記録スキル。計画テスト、モンキーテスト、視覚チェック、アクセシビリティ、レスポンシブ、フォームバリデーションの6種類のテストを実行し、検出した問題をエラーディレクトリに記録する。修正は dev-debug 等の別スキルに委譲する。

## 前提知識

### dev-*スキルフロー内の位置

```
dev-context → dev-plan → dev-impl → dev-verify
                                         ↓
                                    [dev-webtest]
                                         ↓
                                    dev-debug (問題修正)
```

dev-verify でユニットテスト/ビルド/Lintが通った後にWeb画面の動作確認として使用する。単独での使用も可能。

### 実行モード

| モード | 引数 | 用途 |
|-------|------|------|
| 計画テスト | `<plan-name> [--parallel N]` | Markdownテスト計画に沿って自動テスト |
| モンキーテスト | `monkey <url>` | ランダム操作でエラー・崩れを検出 |
| クイックチェック | `check <url>` | 単一ページの視覚・アクセシビリティ確認 |
| プラン選択 | (引数なし) | 利用可能なプラン一覧から選択して実行 |
| 再テスト | `retest` | 未解決エラーの再現手順を再実行し、修正済みなら fixed に更新 |

### 並列実行オプション

| オプション | デフォルト | 説明 |
|-----------|-----------|------|
| `--parallel N` | 2 | シナリオグループの最大並列実行数（1〜5） |

- `--parallel 1` で従来通りの完全直列実行
- シナリオの `group` フィールドに基づいてグループ化し、異なるグループを並列実行する
- 同一グループ内のシナリオは `depends` 順に直列実行する

### ツール構成

- **メイン**: Playwright CLI — Bash経由でコマンド実行。スナップショット(YAML)とスクリーンショット(PNG)はディスク保存
- **代替**: Playwright MCP (`@playwright/mcp`) — CLI が利用できない場合のフォールバック。MCP プロトコル経由でブラウザ操作（詳細は `references/mcp-workflow.md`）
- **補助**: Chrome DevTools MCP — パフォーマンストレース、Lighthouse監査、ネットワーク分析（利用可能時のみ）

## ワークフロー

### Step 1: 環境準備

```
Step 1 開始
    |
[1-0] docs/dev/webtests/env-knowledge.md を Read（存在する場合）
    |    → 過去のトラブルシュートを把握し、同じ問題発生時に即座に適用する
    |
[1-1] docker compose ps
    |
    +-- Playwright コンテナ Running --> [1-5] CLI動作確認・モード判定
    |
    +-- 未起動 / docker compose 自体が使えない
         |
[1-2] docker-compose.yaml の存在 + playwright サービスの定義を確認
         |
         +-- yaml あり & playwright サービス定義済み → AskUserQuestion (A0, C, D)
         +-- yaml あり & playwright サービス未定義 → AskUserQuestion (A1, C, D)
         +-- yaml なし → AskUserQuestion (B, C, D)
```

**1-0. 過去の環境セットアップ知見を読み込む**

`docs/dev/webtests/env-knowledge.md` が存在する場合、Read して内容を把握する。過去のトラブルシュートを参考に、同じ問題が起きた場合は記録済みの解決策を即座に適用する。

**1-1. Docker Compose の状態を確認する**

```bash
docker compose ps
```

Playwright コンテナが Running なら **1-5** へ進む。未起動またはコマンド自体が使えない場合は **1-2** へ。

**1-2. docker-compose.yaml の存在と playwright サービスの定義を確認する**

確認結果に応じて AskUserQuestion で環境セットアップ方法を選択してもらう。各状況で **Recommended 付きの選択肢1つ + C + D の3択** になる。

| 選択肢 | 表示条件 | 処理 |
|--------|----------|------|
| A0) Playwright コンテナを起動する (Recommended) | yaml あり & playwright 定義済み | `docker compose up -d playwright` → `npm install -g @playwright/cli@latest` → **1-5** へ |
| A1) 既存の docker-compose.yaml に Playwright サービスを追加する (Recommended) | yaml あり & playwright 未定義 | `docker-setup.md` を参照して yaml 編集 → `docker compose up -d playwright` → `npm install -g @playwright/cli@latest` → **1-5** へ |
| B) 新しい docker-compose.yaml を作成する (Recommended) | yaml なし | `docker-setup.md` を参照して yaml 新規作成 → `docker compose up -d playwright` → `npm install -g @playwright/cli@latest` → **1-5** へ |
| C) 手動でセットアップする | 常に表示 | `docker-setup.md` を案内 → ユーザーに完了確認 → **1-5** へ |
| D) Docker を使わずローカル MCP で実行する | 常に表示 | `docker-setup.md` の「ローカル MCP セットアップ」を参照して `.mcp.json` に playwright 設定追加 → `mkdir -p tmp/webtest/screenshots` → `.gitignore` 追記 → **MCP モード確定** → Step 2 へ |

※ A0/A1/B は排他（状況に応じて1つだけ表示）。

**1-5. CLI 動作確認・モード判定**（A0/A1/B/C 選択時のみ）

```bash
docker compose exec playwright playwright-cli --version
```

- 成功 → **CLI モード**（本ドキュメントの手順に従う）
- 失敗 → **MCP モード**（Docker MCP）へフォールバック（`references/mcp-workflow.md` の手順に従う）

**1-6. 環境セットアップ知見を記録する**

Step 1 完了時に `docs/dev/webtests/env-knowledge.md` に今回の知見を追記する。

- ファイルが存在しない場合は新規作成する（下記フォーマットに従う）
- **成功手順**: 今回実行した環境構築の手順を簡潔に記録する（選択した方式、実行コマンド、確定モード）
- **トラブルシュート**: Step 1 中にエラーが発生し解決した場合、症状・原因・解決策を記録する
- 既に同じ内容が記録済みの場合は追記しない（重複防止）
- 問題なくスムーズに完了した場合、トラブルシュートの追記は不要

**env-knowledge.md フォーマット**:

```markdown
# Webtest 環境セットアップ知見

## 成功手順

### <YYYY-MM-DD> <モード名>モード確立
- <実行した手順の要約>
- 所要ステップ: <通過したステップ>

## トラブルシュート

### <YYYY-MM-DD> <問題の概要>
- 症状: <エラーメッセージや観察された挙動>
- 原因: <特定された原因>
- 解決: <実行した解決策>
```

### Step 2: 引数解析とプラン解決

引数に応じてテストモードを切り替える。

**引数解析フロー:**

```
引数あり?
  +-- "retest"       → 2d へ
  +-- "monkey <url>" → 2b へ
  +-- "check <url>"  → 2c へ
  +-- その他の文字列 → plan-name として解釈 → プラン解決へ
  +-- 引数なし → プラン一覧表示へ

--parallel N が含まれる場合:
  → N を抽出し maxParallel に設定（デフォルト: 2、範囲: 1〜5）
  → --parallel 部分を引数から除去して上記フローを継続
```

**プラン解決:**

1. `docs/dev/webtests/plans/` ディレクトリを Glob で走査し、利用可能な `.md` ファイルを一覧取得する
2. 引数が plan-name の場合:
   - `docs/dev/webtests/plans/<plan-name>.md` が存在する → 2a へ進む
   - 存在しない → 利用可能なプラン一覧を表示し、AskUserQuestion で「実行するプランを選択してください」と提示する（複数選択可）。選択されたプランを 2a で順番に実行する
3. 引数なしの場合:
   - プランが1件以上ある → AskUserQuestion でプラン一覧を表示し選択させる（複数選択可）。選択されたプランを 2a で順番に実行する
   - プランが0件 → 「`docs/dev/webtests/plans/` にテスト計画がありません。`dev-webtest-plan` でテスト計画を生成するか、`monkey <url>` または `check <url>` で直接テストしてください」と案内する
4. 複数プランが選択された場合、各プランを順番に 2a で実行する。最後に Step 8 で全プランの統合レポートを出力する

#### 2a: 計画テスト（plan-name 解決済み）

1. `docs/dev/webtests/plans/<plan-name>.md` を読み込む
2. テスト計画のフォーマットは `references/test-plan-template.md` を参照
3. テスト計画ファイルの frontmatter を更新する:
   - `status` → `in_progress`
   - `last-run` → 当日の日付（`YYYY-MM-DD`）
4. `mkdir -p tmp/webtest/results/<plan-name>` で中間結果ディレクトリを作成する
4-1. **APIデータセットアップの実行**（「## APIデータセットアップ」セクションが存在する場合）:

##### ファイル共通セットアップの実行

テスト計画の「### ファイル共通」セクション内の curl コマンドを上から順に Docker コンテナ内で実行する:

```bash
docker compose exec playwright bash -c '<curl コマンド>'
```

- トークン取得コマンドがある場合は、レスポンスからトークンを抽出して後続コマンドの `${TOKEN}` 等に展開する
- 各コマンドの実行結果（HTTP ステータスコード）を確認する
- 失敗した場合はエラーを記録し、ユーザーに警告を表示する（テスト自体は継続する）
- セットアップ結果のサマリーを `tmp/webtest/results/<plan-name>/api-setup.md` に記録する

##### シナリオ固有セットアップの事前パース

「### シナリオN固有」セクションの内容をパースし、シナリオ名と curl コマンドの対応を記録する。実際の実行は各シナリオの直前に行う（Step 5-3 の Agent 委譲時にシナリオ固有セットアップも渡す）。

5. **シナリオをグループ化し、グループ単位で並列実行する**:

##### 5-1. グループ化

シナリオの `group` フィールドに基づいてグループ分けする:
- `group` が同じシナリオは同一グループ（グループ内は `depends` 順に直列実行）
- `group` が未指定のシナリオはそれぞれ独立グループとして扱う（他と並列実行可能）
- `depends` が未指定のシナリオはグループ内の記述順に実行する

```
例: 4シナリオ（group: auth×2, group: products×1, group未指定×1）
  → グループ: [auth], [products], [シナリオ4]
  → maxParallel=2 の場合: [auth] と [products] を並列 → 完了後 [シナリオ4]
```

##### 5-2. 並列実行制御

- `maxParallel`（デフォルト: 2）に基づき、同時実行するグループ数を制限する
- グループのキューを作成し、空きスロットができたら次のグループを開始する
- 具体的には: maxParallel 個のグループを Agent tool で **同時に起動**（`run_in_background: true`）し、完了通知を受けたら次のグループの Agent を起動する
- `maxParallel: 1` の場合は従来通りの完全直列実行となる

##### 5-3. Agent 委譲（グループ単位）

1グループにつき1つの Agent を起動する。Agent にはグループ内の全シナリオを渡し、**グループ内のシナリオは depends 順に直列実行** させる:

   - Agent には以下を伝える:
     - 実行モード（CLI / MCP）とセッション情報
     - グループ内の全シナリオの手順・期待結果・視覚チェックポイント（テスト計画から該当部分を抽出）
     - 各シナリオのAPIシナリオ固有セットアップ（curl コマンド、存在する場合のみ）
     - ファイル共通セットアップで取得したトークン（`${TOKEN}` 等の値）
     - 各シナリオの結果の書き出し先: `tmp/webtest/results/<plan-name>/<scenario-index>-<scenario-name>.md`
     - エラー時の error.md 作成先: `docs/dev/webtests/errors/`
     - snapshot・screenshot の取り扱いルール（後述の「ルール・制約」を参照）
   - Agent はグループ内の各シナリオについて以下を実行する:
     a-0. シナリオ固有セットアップがある場合、curl コマンドを Docker 内で実行する:
        ```bash
        docker compose exec playwright bash -c '<curl コマンド>'
        ```
        - `${TOKEN}` 等のプレースホルダはファイル共通セットアップで取得した値に展開する
        - 失敗した場合はエラーを記録し、シナリオを `skipped` として結果に記録する（次のシナリオに進む）
     a. シナリオの手順を実行（Step 2a 操作）
     b. Step 3 + Step 4: 視覚チェック + アクセシビリティチェック（**同時実行可能** — どちらも読み取り専用のため。snapshot を取得した時点で Step 3 は screenshot を Read して判定、Step 4 は snapshot を分析。ただし Tab キーボードテストは Step 3 完了後に実行する）
     c. Step 5: レスポンシブテスト（viewport 変更を伴うため単独実行）
     d. Step 6: フォームバリデーションテスト（ページ状態を変更するため最後に実行）
     e. 問題検出時は error.md を作成
     f. 結果を scenario 中間ファイルに書き出す（フォーマットは後述）
   - Agent の返却値は「完了。passed/failed（N件中M件成功）。結果ファイルパス一覧」程度の短い文字列とする
   - **シナリオが failed でも中断せず、グループ内の次のシナリオを継続する**

6. 全グループ完了後、**APIクリーンアップを実行する**（「## APIクリーンアップ」セクションが存在する場合）:

   テスト計画の「## APIクリーンアップ」セクション内の curl コマンドを上から順に Docker コンテナ内で実行する:

   ```bash
   docker compose exec playwright bash -c '<curl コマンド>'
   ```

   - `${TOKEN}` / `${ADMIN_TOKEN}` 等のプレースホルダはセットアップ時に取得した値に展開する
   - 各コマンドの実行結果を確認するが、クリーンアップ失敗はエラーとして記録するのみでテスト結果には影響しない
   - クリーンアップ結果のサマリーを `tmp/webtest/results/<plan-name>/api-cleanup.md` に記録する

7. テスト計画ファイルの frontmatter `status` を更新する:
   - 全シナリオが passed → `status: done`
   - 1つでも failed がある → `status: in_progress`
8. Step 7 → Step 8 に進む

##### scenario 中間ファイルフォーマット

Agent が `tmp/webtest/results/<plan-name>/<scenario-index>-<scenario-name>.md` に書き出す:

```markdown
---
scenario: "<シナリオ名>"
url: "<テスト対象URL>"
result: passed | failed | skipped
---
## APIセットアップ: <成功/失敗/なし>
- <セットアップの実行結果（1行。なしの場合は「シナリオ固有セットアップなし」）>

## シナリオ結果: <passed/failed/skipped>
- <結果の要約（1-2行）>

## 視覚チェック: <判定>
- <所見（1-2行）>

## アクセシビリティ: <判定>
- 画像alt: <判定> (N/M)
- フォームラベル: <判定> (N/M)
- Heading階層: <判定>
- キーボード: <判定> Tab到達率 N% (N/M)
- ARIA: <判定>
- ランドマーク: <判定>

## レスポンシブ: <判定>
- mobile: <判定> <所見>
- tablet: <判定> <所見>
- desktop: <判定> <所見>

## フォームバリデーション: <判定>
- <パターン>: <判定> | ...

## 検出エラー
- <error.md へのパス>（エラーがない場合は「なし」）
```

#### 2b: モンキーテスト（monkey 指定時）

1. 指定URLにアクセスする
2. `snapshot` でページ構造を把握する
3. 以下のアクションをランダムに実行する（最大20アクション）:
   - リンクのクリック
   - ボタンのクリック
   - フォームへのランダム入力（正常値・異常値・空値・境界値）
   - ナビゲーション（戻る・進む）
4. 各アクション後に以下を確認する:
   - `snapshot` でページ状態を取得
   - `console` でJavaScriptエラーを確認
   - `network` でHTTPエラー(4xx/5xx)を確認
5. 問題検出時は `screenshot` を取得する
6. 問題検出時はエラーディレクトリを作成する:
   - `docs/dev/webtests/errors/<YYYY-MM-DD>-<NNN>-<概要>/error.md` を作成
   - `tmp/webtest/errors/<YYYY-MM-DD>-<NNN>-<概要>/screenshot.png` にスクリーンショットを保存
7. 同一ドメイン内のみ遷移する。外部リンクはスキップする

#### 2c: クイックチェック（check 指定時）

1. 指定URLにアクセスする
2. `screenshot` + `snapshot` を取得する
3. Step 3（視覚チェック）と Step 4（アクセシビリティ）のみ実行する
4. 結果を直接ユーザーに報告する（レポートファイルは作成しない）

#### 2d: 再テスト（retest 指定時）

`docs/dev/webtests/errors/` の未解決エラーについて、再現手順を再実行して修正を確認する。

1. `docs/dev/webtests/errors/` を Glob で走査し、全 `error.md` を取得する
2. 各 error.md を Read し、frontmatter の `status: open` のものだけ収集する
3. 0件の場合 →「未解決の webtest エラーはありません」と報告して終了
4. 各エラーを順次再テストする:
   a. error.md の `url` にアクセスする
   b. 「再現手順」に記載された操作を Playwright で実行する
   c. 「期待される状態」と実際の状態を比較する
   d. 判定:
      - 問題が解消 → error.md の `status` を `open` → `fixed` に更新し、`fixedDate: YYYY-MM-DD` を追記する
      - 問題が残存 → `status: open` のまま維持する
5. 全エラーの再テスト完了後、結果を報告する（レポートファイルは作成しない）:
   - fixed に変更されたエラー一覧
   - まだ open のエラー一覧（あれば）

### Step 3: 視覚チェック（サブAgent内で実行）

スクリーンショットを Read tool で読み取り、Claude が視覚的に判断する。判定完了後は画像の内容をテキスト要約に変換し、以降はテキスト要約のみ保持する（画像データはコンテキストから自然に流れる）。

**チェック項目**（詳細は `references/visual-check-criteria.md` 参照）:
- レイアウト崩れ（要素の重なり、はみ出し、意図しない配置）
- 文字化け・フォント異常
- 色の異常（コントラスト不足、意図しない色）
- 画像の表示異常（破損、アスペクト比崩れ）
- 余白・マージンの異常
- ボタン・リンクの視認性

**判定**:
- ✅ 問題なし
- ⚠️ 軽微な問題（改善推奨）
- ❌ 重大な問題（修正必須）

**エラー記録**: ⚠️ または ❌ 判定時はエラーディレクトリを作成する:
- `docs/dev/webtests/errors/<YYYY-MM-DD>-<NNN>-<概要>/error.md` を作成
- `tmp/webtest/errors/<YYYY-MM-DD>-<NNN>-<概要>/screenshot.png` にスクリーンショットを保存

### Step 4: アクセシビリティチェック（サブAgent内で実行）

`snapshot` のアクセシビリティツリーを分析する（詳細は `references/accessibility-checklist.md` 参照）:

1. `img` 要素の `alt` 属性の有無
2. `form` 要素と `label` の紐づけ
3. ARIA属性の適切な使用
4. heading要素(h1-h6)の階層構造
5. キーボード操作可能かを `press Tab` で確認
6. フォーカスの視認性

Chrome DevTools MCP が利用可能な場合は `lighthouse_audit` でスコアを取得する。

**エラー記録**: 問題検出時はエラーディレクトリを作成する:
- `docs/dev/webtests/errors/<YYYY-MM-DD>-<NNN>-<概要>/error.md` を作成
- `tmp/webtest/errors/<YYYY-MM-DD>-<NNN>-<概要>/screenshot.png` にスクリーンショットを保存

### Step 5: レスポンシブテスト（サブAgent内で実行）

シナリオのURLについて3つのビューポートでスクリーンショットを取得し、AIで確認する。判定完了後は画像の内容をテキスト要約に変換し、以降はテキスト要約のみ保持する:

```bash
# モバイル
docker compose exec playwright playwright-cli open <url> --headless --viewport 375x667
docker compose exec playwright playwright-cli screenshot --filename=/work/tmp/webtest/screenshots/mobile.png

# タブレット
docker compose exec playwright playwright-cli open <url> --headless --viewport 768x1024
docker compose exec playwright playwright-cli screenshot --filename=/work/tmp/webtest/screenshots/tablet.png

# デスクトップ
docker compose exec playwright playwright-cli open <url> --headless --viewport 1280x800
docker compose exec playwright playwright-cli screenshot --filename=/work/tmp/webtest/screenshots/desktop.png
```

**確認項目**:
- ナビゲーションの表示切り替え（ハンバーガーメニュー等）
- グリッドレイアウトの列数変化
- テキストの折り返し
- 水平スクロールの有無（モバイルで不要な横スクロールは ❌）
- タッチターゲットのサイズ（モバイル時 44px 以上推奨）

**エラー記録**: 問題検出時はエラーディレクトリを作成する:
- `docs/dev/webtests/errors/<YYYY-MM-DD>-<NNN>-<概要>/error.md` を作成
- `tmp/webtest/errors/<YYYY-MM-DD>-<NNN>-<概要>/screenshot.png` にスクリーンショットを保存

### Step 6: フォームバリデーションテスト（サブAgent内で実行）

ページ内のフォームを `snapshot` から自動検出し、以下のパターンでテストする:

| パターン | 入力値 | 期待 |
|---------|-------|------|
| 空送信 | 全フィールド空 | バリデーションエラー |
| 必須チェック | 必須フィールドのみ空 | 該当フィールドにエラー |
| 型チェック | email欄に非email文字列 | 型エラー表示 |
| 最大長 | 1000文字の文字列 | 切り詰めまたはエラー |
| XSS | `<script>alert(1)</script>` | スクリプトが実行されない |
| SQLi | `'; DROP TABLE users; --` | SQLエラーが発生しない |
| 正常値 | 適切な値 | 成功 |

セキュリティ上の問題（XSS, SQLi）は ❌ として即時報告する。

**エラー記録**: 問題検出時はエラーディレクトリを作成する:
- `docs/dev/webtests/errors/<YYYY-MM-DD>-<NNN>-<概要>/error.md` を作成
- `tmp/webtest/errors/<YYYY-MM-DD>-<NNN>-<概要>/screenshot.png` にスクリーンショットを保存

### Step 7: エラー記録の確認

検出された問題は `docs/dev/webtests/errors/` に error.md として記録済みである。

- 修正は **dev-debug** 等の別スキルで対応する（本スキルでは修正を行わない）
- 各エラーの `error.md` の `status` フィールドを `open` → `fixed` に更新して対応状況を管理する

### Step 8: レポート出力

計画テスト・モンキーテストの場合、`docs/dev/webtests/reports/YYYY-MM-DD-<plan-name>.md` にレポートを出力する。

**計画テストの場合**（サブAgent結果を集約）:
1. `tmp/webtest/results/<plan-name>/` 配下の全 scenario 中間ファイルを Read する
2. 中間ファイルの内容を集約してレポートを生成する
3. レポート生成後、`rm -rf tmp/webtest/results/<plan-name>/` で中間ファイルを削除する

レポートには以下を含める:
- Summary（テスト種別ごとの結果概要テーブル）
- APIセットアップ結果（実行したセットアップコマンドの成否。`api-setup.md` から集約）
- シナリオテスト結果（各シナリオの passed/failed と詳細）
- 視覚チェック結果（判定と所見）
- アクセシビリティ結果（チェック項目ごとの結果テーブル）
- レスポンシブ結果（ビューポートごとの結果テーブル）
- フォームバリデーション結果（パターンごとの結果テーブル）
- 検出されたエラー一覧（severity, step, 概要, error.md へのリンクのテーブル）
- APIクリーンアップ結果（実行したクリーンアップコマンドの成否。`api-cleanup.md` から集約）
- 未対応のエラー（status: open のエラー数）
- Recommendations

## ルール・制約

### コンテキスト管理（重要）

サブAgent内でのコンテキスト蓄積を抑制するため、以下のルールを遵守する。

**snapshot の取り扱い**:
- snapshot の YAML 全体をそのまま保持しない
- 判定に必要な要素（確認対象の要素名・状態・ref ID）のみ抽出して記録する
- 判定完了後は次の操作に必要な情報のみ保持し、不要な snapshot データは破棄する意識で進める
- Step 4 の Tab キーボードテストでは、各 Tab 後のフォーカス要素名のみをリスト形式で記録する:
  - 良い例: 「Tab 1: "Email input" → Tab 2: "Password input" → Tab 3: "Login button"」
  - 悪い例: Tab ごとに snapshot YAML 全体を逐次保持

**screenshot の取り扱い**:
- CLI モード: screenshot はファイルに保存し、視覚判定が必要な時点でのみ Read する
- 判定完了後は画像の内容をテキスト要約に変換し、以降はテキスト要約のみ参照する
  - 例: 「mobile.png: レイアウト正常、ナビゲーションがハンバーガーメニューに切り替わっている」
- 同じ画像を複数 Step で重複して Read しない
- Step 8 レポートでは画像ファイルへのパスのみ記載し、画像自体は Read しない
- MCP モード: `browser_take_screenshot` の base64 が直接返るため、判定後すぐにテキスト要約に変換して以降は要約のみ使用する

**scenario 中間ファイル**:
- 各シナリオの結果は `tmp/webtest/results/<plan-name>/` にファイルとして書き出す
- メインAgentは中間ファイルを Read して統合レポートを生成する
- レポート生成後、中間ファイルは削除する

### 一般ルール

- スクリーンショットは `tmp/webtest/screenshots/` に保存する（git管理しない）
- エラー検出時は `docs/dev/webtests/errors/<YYYY-MM-DD>-<NNN>-<概要>/error.md` を作成する
- エラーのスクリーンショットは `tmp/webtest/errors/<YYYY-MM-DD>-<NNN>-<概要>/screenshot.png` に保存する（git管理しない）
- 連番 NNN は日付ごとに 001 からリスタートする。同日再実行時は既存の最大連番の次から採番する
- 概要部分は英数字ケバブケースで記述する
- エラー検出後も全テストを最後まで継続する（中断しない）
- CLI モードの場合、Playwright CLI コマンドは `docker compose exec playwright` 経由で実行する
- コマンドの詳細は `references/playwright-cli-reference.md` を参照する
- モンキーテストのアクション数上限は20。タイムアウトはアクションあたり10秒
- 同一ドメイン外への遷移はしない
- Chrome DevTools MCP は optional。利用できない場合はスキップする
- `@playwright/cli` が利用できない場合は `references/mcp-workflow.md` に従って MCP モードで実行する
- 環境が未セットアップの場合は Step 1 の AskUserQuestion で選択してもらう
- Bash コマンドはプロジェクトルートの **絶対パス** を使用する（`$(git rev-parse --show-toplevel)` でルートを取得）
- 500行ルール: 修正によりファイルが500行を超える場合は分割する

### error.md テンプレート

```markdown
---
severity: critical | major | minor
step: "2a-scenario | 2b-monkey | 3-visual | 4-a11y | 5-responsive | 6-form"
status: open | fixed
detected: YYYY-MM-DD
fixedDate:
scenario: "シナリオ名またはテスト概要"
url: "テスト対象URL"
---

## 検出内容

（何が問題だったかの説明）

## 再現手順

1. （手順1）
2. （手順2）
3. ...

## 期待される状態

（正しい動作の説明）

## スクリーンショット

![エラースクリーンショット](../../../../../tmp/webtest/errors/<YYYY-MM-DD>-<NNN>-<概要>/screenshot.png)
```

## 追加リソース

### リファレンスファイル

- **`references/playwright-cli-reference.md`** — Playwright CLI コマンド一覧と使用例
- **`references/test-plan-template.md`** — テスト計画の書き方テンプレート
- **`references/visual-check-criteria.md`** — 視覚チェックの判定基準と具体例
- **`references/accessibility-checklist.md`** — アクセシビリティチェック項目の詳細
- **`references/docker-setup.md`** — Docker環境のセットアップ手順
- **`references/mcp-workflow.md`** — MCP モードのワークフローとツール対応表

### サンプルファイル

- **`examples/sample-test-plan.md`** — サンプルテスト計画（Go+Echo+templアプリ向け）
