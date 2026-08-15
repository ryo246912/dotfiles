# 外部 skill の使い方

このページでは、`dot_apm/apm.yml` で導入している次の skill の使い方を説明します。

- `crit` / `crit-cli`
- `terminal-browser`
- Tsumikiの14 skill
- Ponytailの6 skill
- `ctx-agent-history-search`
- `resolving-merge-conflicts`
- `grill-me`（内部で `grilling` を使用）
- `diagram-design`
- `wireframe-spec`
- `find-skills`

## インストール

設定を反映してから APM を実行します。

```bash
chezmoi apply
mise run apm:install
```

`mise run apm:install` は user scope で skill をインストールします。Claude Code では
`~/.claude/skills/`、Codex・GitHub Copilot・Cursor では共通の `~/.agents/skills/` に配置されます。
インストール後は、エージェントを新しいセッションで起動してください。

依存先は再現性のため `dot_apm/apm.yml` で commit SHA に pin しています。更新時は upstream の内容を確認して
`ref` を変更し、もう一度 `chezmoi apply` と `mise run apm:install` を実行します。

## `crit` / `crit-cli`

### 用途

`crit`はcode diff、plan、ローカルHTML、実行中のWeb applicationをbrowser UIで確認し、行や要素へcommentを付けて
エージェントへ戻すreview skillです。`crit-cli`はcommentの作成・返信、reviewの共有、GitHub PRとの同期などを
エージェントがCLIから操作するための補助skillであり、通常は直接起動しません。

### 使い方

`crit`はユーザーが明示的に起動します。Claude Codeでは`/crit`、Codexでは`$crit`を使い、必要に応じてreview対象を
指定します。

```text
/crit docs/plan.md
```

```text
$crit を使って、現在のgit diffをreviewできるようにしてください。
```

devcontainerでは`crit`を起動した後、表示されたhost側URLをbrowserで開きます。commentを送信するとエージェントが
修正し、再reviewできます。CLIの構成、PR commentのpull / push、tool比較は[`docs/crit.md`](crit.md)を参照してください。

## `terminal-browser`

### 用途

terminal pane内に実browserを表示し、エージェントが同じtabに対してsnapshot、click、入力、JavaScript評価を行うskillです。
Web applicationの動作確認、生成したHTMLの可視化、browser上でしか確認できない状態の調査に使用します。

### 使い方

browserで確認したいURLと操作内容を自然言語で伝えます。明示的に指定する場合は、Claude Codeでは
`/terminal-browser`、Codexでは`$terminal-browser`を使用します。

```text
$terminal-browser を使って http://localhost:3000 を開き、login formを操作してerrorがないか確認してください。
```

skillは必要に応じてterminalを分割し、`terminal-browser action`で開いているtabを操作します。認証情報や個人情報を
入力させる場合は、実行する操作と送信先を事前に確認してください。

## Tsumiki skills

Tsumikiは、project初期化、context生成、plan作成、TDD実装、検証、debug、Web test、security checkをつなぐ開発workflowです。
依頼内容に応じて自動選択されますが、Claude Codeでは`/<skill-name>`、Codexでは`$<skill-name>`で明示できます。

| skill                | 用途                                                                                         |
| -------------------- | -------------------------------------------------------------------------------------------- |
| `dev-context`        | projectの技術stack、test framework、規約、architectureを分析し、context fileを生成・更新する |
| `dev-debug`          | test失敗、build・compile error、環境問題を分類し、原因を絞って修正する                       |
| `dev-impl`           | plan内のtaskまたは直接指定した小規模変更を、TDDをguardrailとして実装する                     |
| `dev-init`           | 対話で新規projectの技術stackを決め、承認後にscaffoldとcontextを生成する                      |
| `dev-navigate`       | 目的を聞き取り、使用するTsumiki skillと実行順序を案内する                                    |
| `dev-plan`           | 要件をinterface-firstの設計とtest可能なtaskへ分解し、`docs/dev/plans/`へ保存する             |
| `dev-run`            | plan内のtask範囲を`dev-impl`、`dev-verify`、`dev-debug`のflowで連続実行する                  |
| `dev-screen-spec`    | source codeまたはplanから画面仕様を生成し、既存仕様を差分更新する                            |
| `dev-verify`         | planの完了状態とtest・build・lintの整合性を検証し、reportを出力する                          |
| `dev-webtest-plan`   | dev planや画面仕様からPlaywright用のWeb test planを生成・更新する                            |
| `dev-webtest`        | Playwrightで画面動作、visual、accessibility、responsive、formをtestする                      |
| `ipa-security-check` | IPAの公開資料に基づいてsource codeを静的検査し、出典付きで脆弱性候補を報告する               |
| `ipa-security-guide` | security診断reportを読み、優先順位付きの`dev-debug`依頼リストへ変換する                      |
| `kairo-implement`    | 分割済みtaskを指定順に実装し、TDD commandを使って完了まで検証する                            |

最初にどのskillを使うべきか分からない場合は、次のように`dev-navigate`へ相談します。

```text
/dev-navigate
既存Web applicationへ決済機能を追加したいです。どの順番で進めるべきですか。
```

```text
$dev-plan checkout "決済providerを追加し、失敗時に安全にretryできるようにする"
```

既存projectで一連のworkflowを始める場合は、通常`dev-context` → `dev-plan` → `dev-impl`または`dev-run` →
`dev-verify`の順で使用します。Web UIを含む場合は`dev-webtest-plan`と`dev-webtest`、security確認が必要な場合は
`ipa-security-check`と`ipa-security-guide`を組み合わせます。

## tsumiki 入門ガイド

### 1. tsumikiとは何か

tsumikiは「**要件定義 → 設計 → タスク分割 → 実装（TDD）**」という開発プロセスを、Claude Codeのスラッシュコマンド／スキルとして一気通貫でサポートするフレームワークです。

大きく分けて以下のコマンド群があります。

| カテゴリ                     | 何をするか                                              | 本プロジェクトで使うか               |
| ---------------------------- | ------------------------------------------------------- | ------------------------------------ |
| **Kairo**                    | 要件定義〜実装までの包括的フロー                        | ◎ メインで使用                       |
| **TDD**                      | Red/Green/Refactorの個別実行（Kairoの内部でも使われる） | △ 必要に応じて個別実行               |
| **Dev Skills**               | コンテキスト分析・計画・実装・検証の統合ワークフロー    | △ 代替案として利用可                 |
| **DCS**                      | 既存コードの分析・調査・PRD作成支援                     | △ 途中の調査で利用可                 |
| **ユーティリティ**           | ヘルプ・自動デバッグ・小規模修正など                    | ○ 困ったときに利用                   |
| **リバースエンジニアリング** | 既存コードから設計書・要件定義書を逆生成                | – 今回はゼロからの開発なので基本不要 |

ポイントは、**各ステップの成果物がすべて `docs/` 配下にMarkdown等のドキュメントとして残る**ことです。これは今回の課題が必須としている「Design Doc」や「判断理由の記録」とも相性が良い仕組みです。

---

### 2. 全体のワークフロー（Kairo）

tsumikiのメインフローは次の5ステップです。

```mermaid
flowchart TD
    A[要件概要を伝える] --> B["/tsumiki:kairo-requirements"]
    B --> C{要件を確認}
    C -->|修正必要| B
    C -->|OK| D["/tsumiki:kairo-design"]
    D --> E{設計を確認}
    E -->|修正必要| D
    E -->|OK| F["/tsumiki:kairo-tasks"]
    F --> G{タスクを確認}
    G -->|OK| H["/tsumiki:kairo-implement もしくは kairo-loop"]
    H --> I{全タスク完了?}
    I -->|No| H
    I -->|Yes| J[完了]
```

**重要な考え方**: 各ステップの後には必ず人間（自分）が生成物をレビューし、必要なら修正を指示してから次のステップに進みます。生成AIに丸投げするのではなく、「AIの提案を検証・レビューする過程」自体が今回の課題で評価されるポイントでもあります。

---

### 3. 各コマンドの詳細

#### 3-1. `/tsumiki:init-tech-stack` — 技術スタックの決定

プロジェクトで使うフレームワーク・ライブラリを対話的に決めます。

- 生成物: `docs/tech-stack.md`
- 今回は非機能要件で「フロントエンド: TypeScript + React」「バックエンド: Go」と指定されているため、その制約を踏まえた選定を行うことになります（React内でのラッパーフレームワークやUIライブラリ、Goでのフレームワーク・APIスキーマ形式など、指定がない部分をここで決定していきます）。

#### 3-2. `/tsumiki:kairo-requirements` — 要件定義

要件の概要を渡すと、EARS記法（Easy Approach to Requirements Syntax）で詳細な要件定義書を作ってくれます。

```
/tsumiki:kairo-requirements 要件概要
```

- 生成物: `docs/spec/{要件名}-requirements.md`
- 含まれる内容: ユーザーストーリー、EARS記法の詳細要件、エッジケース、受け入れ基準
- 課題側の「Design Doc に要件の整理（自分で補った要件を含む）を書く」という要求と直結する部分です。README.mdの機能要件（ツイート・フォロー・タイムライン）や非機能要件をここでインプットします。

#### 3-3. `/tsumiki:kairo-design` — 設計

要件を承認した後に実行します（省略しても直前の要件定義を引き継いで実行可能）。

- 生成物: `docs/design/{要件名}/` 配下
  - アーキテクチャ設計書
  - データフロー図（Mermaid）
  - TypeScriptインターフェース定義
  - データベーススキーマ
  - APIエンドポイント仕様
- **注意点**: 課題が求める「Design Doc」には「検討した選択肢とトレードオフ」「最終的に選んだ方針とその理由」という比較検討のセクションが必須です。`kairo-design` はそのまま「決定した設計」を出力する傾向があるため、この比較検討部分は生成後に自分で加筆するか、設計を依頼する際のプロンプトで「複数の選択肢とトレードオフも明記してほしい」と明示的に指示するのがおすすめです。

#### 3-4. `/tsumiki:kairo-tasks` — タスク分割

設計を確認した後に実行します。

- 生成物: `docs/tasks/{要件名}/overview.md`、`docs/tasks/{要件名}/TASK-XXXX.md`
- 依存関係を考慮した実装順序、各タスクのテスト要件・UI/UX要件まで含めて分割してくれます。
- `/tsumiki:kairo-task-verify`（タスク内容の確認用コマンド）を実行してから実装に進むと安全です。

#### 3-5. 実装コマンド

タスクができたら実装に入ります。2つのやり方があります。

```bash
# 全タスクを順番に実装
/tsumiki:kairo-implement

# 特定タスクだけ実装（タスクファイル名 TASK番号 を指定）
/tsumiki:kairo-implement タスクファイル名 TASK番号

# タスク範囲を指定して自動連続実装（長時間実行・compact対応）
/tsumiki:kairo-loop
```

内部的には各タスクごとに以下のTDDサイクルが自動で回ります。

1. `tdd-requirements`（TDD要件定義）
2. `tdd-testcases`（テストケース作成）
3. `tdd-red`（失敗するテストを書く）
4. `tdd-green`（テストを通す最小実装）
5. `tdd-refactor`（リファクタリング）
6. `tdd-verify-complete`（完了確認）

このサイクルを個別に手動で回したい場合は `/tsumiki:tdd-requirements` 〜 `/tsumiki:tdd-verify-complete` を1つずつ呼び出すこともできます。

---

### 4. 生成物が置かれるディレクトリ構成

```
./
├── docs/
│   ├── tech-stack.md        # 技術スタック選定
│   ├── spec/{要件名}/        # 要件定義書（requirements.md 等）
│   ├── design/{要件名}/      # 設計書（architecture.md, api-endpoints.md, database-schema.sql 等）
│   ├── tasks/{要件名}/       # タスク一覧（overview.md, TASK-XXXX.md）
│   └── implements/{要件名}/{タスクID}/  # 実装に関する記録
├── frontend/                # フロントエンド（TypeScript + React）
├── backend/                 # バックエンド（Go）
└── database/                # DB関連
```

プロジェクト固有のルールを追加したい場合は `docs/rule/{種類1}/{種類2}/*.md` にMarkdownを置くと、対応するコマンド実行時に自動で読み込まれます（例: `docs/rule/kairo/requirements/` は `kairo-requirements` 実行時のみ読み込まれる）。

---

### 5. 困ったときは

```bash
# コマンド一覧・使い方を表示
/tsumiki:help

# 特定コマンドの詳細ヘルプ
/tsumiki:help kairo-requirements

# 「〜が分からない」で検索
/tsumiki:help テストが失敗して原因がわからない
```

その他、テストやビルドで詰まった場合は `/tsumiki:auto-debug`（テストエラー自動デバッグ）、`/tsumiki:build-fix`（ビルドエラー修正）なども用意されています。

---

### 6. 本プロジェクト（ENG-1100課題）での想定進行イメージ

`ENG-1100/README.md` の要件（ツイート・フォロー・タイムライン、TypeScript+React／Go、Design Doc必須）を踏まえると、次の順序で進めるのが自然です。

1. `/tsumiki:init-tech-stack` — React側のフレームワークやUIライブラリ、Go側のWebフレームワークやAPIスキーマ形式（OpenAPI等）を決定
2. `/tsumiki:kairo-requirements` — 機能要件・非機能要件・自分で補った要件をEARS記法で整理
3. `/tsumiki:kairo-design` — アーキテクチャ、データフロー、API仕様、DBスキーマを設計。**比較検討したトレードオフと決定理由は別途加筆**して課題の「Design Doc」要件を満たす
4. `/tsumiki:kairo-tasks` → `/tsumiki:kairo-task-verify` — 実装タスクへ分割・確認
5. `/tsumiki:kairo-implement` または `/tsumiki:kairo-loop` — TDDサイクルで実装を進行

各ステップの成果物は必ず内容を読んでレビューし、必要な修正指示を出してから次に進むことをおすすめします（AIに任せた部分と自分で判断した部分を分けて記録する、という課題の評価観点にも合致します）。

## Ponytail skills

Ponytailは、YAGNI、standard library、native platform機能、既存dependencyの順に検討し、要件を満たす最小の実装を
選ぶcoding workflowです。短いcodeを目的化するのではなく、security、accessibility、trust boundaryのvalidation、
data lossを防ぐerror handlingは省略しません。

| skill             | 用途                                                                                |
| ----------------- | ----------------------------------------------------------------------------------- |
| `ponytail`        | 最小の正しい実装を選ぶmode。`lite`、`full`、`ultra`の3段階を切り替えられる          |
| `ponytail-review` | 現在のdiffから過剰なabstraction、不要なdependency、再実装されたstdlibなどを探す     |
| `ponytail-audit`  | repository全体を対象に、削除・単純化できる箇所を優先順位付きで報告する              |
| `ponytail-debt`   | source内の`ponytail:` commentを収集し、意図的に先送りした制約と改善条件を一覧化する |
| `ponytail-gain`   | 公開benchmarkに基づくcode量、cost、処理時間への影響をscoreboardで表示する           |
| `ponytail-help`   | mode、skill、command、無効化方法をquick referenceとして表示する                     |

### 使い方

通常modeは`full`です。Claude Codeでは`/ponytail`、Codexでは`$ponytail`を使い、必要に応じてlevelを指定します。

```text
/ponytail lite
このAPI clientへretryを追加してください。
```

```text
$ponytail ultra を使って、この変更を実現する最小のdiffを作ってください。
```

過剰実装だけをreviewするときは`ponytail-review`、repository全体を調べるときは`ponytail-audit`を使用します。これらは
correctness、security、performanceのreviewを置き換えないため、必要に応じて通常のcode reviewと併用してください。

```text
$ponytail-review を使って、現在のdiffから削除できるabstractionを探してください。
```

Ponytailを止めるときは「stop ponytail」または「normal mode」と伝えます。default levelを変える場合は
`PONYTAIL_DEFAULT_MODE`へ`lite`、`full`、`ultra`、`off`のいずれかを設定します。pluginのalways-on activationには
Node.jsで動くlifecycle hookを使用するため、非対話shellの`PATH`から`node`を実行できる必要があります。

## `ctx-agent-history-search`

### 用途

ローカルに保存された過去のcoding-agent sessionを`ctx` CLIで検索し、以前の判断、試行、失敗理由、関連する会話を
現在の作業前に確認するskillです。同じrepositoryで過去の経緯が役立つ可能性があるときに自動的に使用されます。

### 使い方

初回だけ`ctx setup`でindexを作成します。明示的に使う場合は、Claude Codeでは`/ctx-agent-history-search`、Codexでは
`$ctx-agent-history-search`を指定します。

```text
$ctx-agent-history-search を使って、以前database migrationに失敗したsessionとその原因を調べてください。
```

手動検索では`ctx search "query"`、詳細表示では`ctx show session <session-id>`などを使用します。setup、主要command、
local historyに含まれる秘密情報の注意点は[`docs/ctx.md`](ctx.md)を参照してください。

## `resolving-merge-conflicts`

### 用途

進行中の `git merge` または `git rebase` で発生した conflict を、両方の変更意図を調べながら解消する skill です。
単に片側を採用するのではなく、commit・PR・issue などの一次情報を確認し、可能な限り双方の意図を保ちます。

### 使い方

conflict が発生した状態で、エージェントに自然言語で依頼します。明示的に指定する場合は、Claude Code では
`/resolving-merge-conflicts`、Codex では `$resolving-merge-conflicts` を使用します。

```text
/resolving-merge-conflicts
現在の rebase conflict を、各 commit の意図を確認して解消してください。
```

```text
$resolving-merge-conflicts を使って、この merge conflict を解消してください。
```

skill は次の順に作業します。

1. merge/rebase の状態、履歴、conflict 対象を確認する。
2. 各変更の commit・PR・issue を調べ、意図を特定する。
3. conflict を hunk 単位で解消する。
4. リポジトリの typecheck・test・format などを実行する。
5. ファイルを stage し、merge commit または `git rebase --continue` まで完了する。

> [!IMPORTANT]
> この skill は進行中の merge/rebase を `--abort` せず、最後まで完了させる方針です。中断したい場合は、実行前に
> その旨を明示してください。また、作業ツリーに退避していない変更がないか事前に確認してください。

## `grill-me`

### 用途

計画、設計、意思決定を実行に移す前に、未決定事項や暗黙の前提を質問によって洗い出す skill です。質問を
decision tree として扱い、前提が確定した時点で回答可能になる質問を round ごとに提示します。

`grill-me` はユーザーが明示的に起動する skill です。質問処理の本体である `grilling` も APM で一緒に
インストールされます。

### 使い方

Claude Code では `/grill-me`、Codex では `$grill-me` に続けて検討対象を渡します。

```text
/grill-me
社内 API を外部パートナーへ公開する計画について、実装前に不足している判断を洗い出してください。
```

```text
$grill-me を使って、新しい CLI の配布方法を固めたいです。
```

各 round では複数の質問と推奨回答が提示されます。質問へ回答すると、その回答に依存する次の質問が提示されます。
すべての branch が解決すると interview は終了しますが、合意内容を実装へ移すのはユーザーが明示的に確認した後です。

効果的に使うため、最初の依頼には次を含めます。

- 達成したい結果と対象ユーザー
- 既に決まっていること
- 変更できない制約（期限、互換性、予算など）
- 特に不安な判断

## `diagram-design`

### 用途

architecture、flowchart、sequence、ER、timeline、swimlane、quadrant、Gantt などの図を、inline SVG/CSS を含む
self-contained HTML として生成する skill です。文章や表より図の方が理解しやすい情報に使用します。

### 初回セットアップ

最初の図を作るとき、skill は同梱の `references/style-guide.md` がデフォルトのままか確認します。デフォルトの場合は、
次のいずれかを選択します。

1. Web サイトの URL から色と font を抽出する。
2. インストール済み skill の design token を参照する。
3. ローカルの design system directory から抽出する。
4. token を手動で渡す。
5. デフォルトテーマをそのまま使う。

APM の再インストールや更新では配布先が再生成される可能性があります。ブランド設定を継続的に管理したい場合は、
upstream skill を直接編集せず、生成時に URL・design system・token を指定してください。

### 使い方

作りたい図、含める要素、要素間の関係、出力先を自然言語で依頼します。skill は依頼内容から図の種類を選択します。
明示的に指定する場合は、Claude Code では `/diagram-design`、Codex では `$diagram-design` を使用します。

```text
/diagram-design
Web、API、PostgreSQL、Redis、外部決済サービスを含む architecture diagram を作り、
docs/architecture.html に保存してください。主要な request と data flow も表示してください。
```

```text
$diagram-design を使って、OAuth authorization code flow の sequence diagram を
docs/oauth-sequence.html に作成してください。
```

出力は build step や外部画像を必要としない HTML なので、browser で直接確認できます。

```bash
open docs/architecture.html # macOS
xdg-open docs/architecture.html # Linux
```

PNG または SVG が必要な場合は、生成後に自然言語で対象ファイルと形式を指定します。

```text
docs/architecture.html の図を SVG と PNG に export してください。
```

SVG は standalone file として生成されます。PNG export には Python 版 Playwright と Chromium が必要です。
未導入の場合は、export を依頼する前に次のコマンドを実行します。

```bash
pip install playwright
playwright install chromium
```

SVG は Google Fonts を外部参照するため、font を取得しない offline viewer などでは代替 font で表示される可能性が
あります。pixel-perfect な持ち運びが必要な場合は PNG を使用してください。diagram 生成時は、要素を詰め込みすぎず、
複雑な場合は overview と detail に分割してください。

## `wireframe-spec`

### 用途

visual designへ進む前に、contentの優先順位、component配置、interaction、responsive、accessibilityを含む注釈付き
wireframe仕様を作るskillです。色や装飾ではなく情報構造と画面状態の合意に使います。

### 使い方

対象要件、必要なbreakpoint、empty / loading / errorなどの状態、保存先を指定します。Claude Codeでは
`/wireframe-spec`、Codexでは`$wireframe-spec`で明示的に指定できます。

```text
$wireframe-spec を使って、FR-001〜FR-008のdesktop/mobile用low-fi wireframeを作ってください。
empty、loading、error状態とkeyboard操作を注記し、docs/design/checkout/wireframe.mdへ保存してください。
```

このskill単体は画像を生成しません。注釈付き仕様からHTML prototypeを作ってbrowserで確認する、または実装後の
screenshotをreviewするところまで別途依頼してください。要件の壁打ちから実装後の漏れ監査までを含む推奨手順は、
このページ後半の[「軽量な仕様駆動開発 workflow の選定と運用」](#軽量な仕様駆動開発-workflow-の選定と運用)を参照してください。

## `find-skills`

### 用途

実現したい作業に利用できる既存のagent skillを検索し、候補の品質を確認して提案するskillです。「この作業に使える
skillはあるか」「エージェントへ特定分野の能力を追加したい」といった依頼で使用します。

検索結果をそのまま勧めるのではなく、install数、配布元の信頼性、GitHub starsなどを確認してから候補を提示します。
適切なskillが見つからなかった場合は、通常のエージェント機能で作業を続けるか、独自skillを作る方法を提案します。

### 使い方

skillは該当する依頼から自動的に選択されます。明示的に指定する場合は、Claude Codeでは`/find-skills`、Codexでは
`$find-skills`を使用し、探したい分野と具体的な作業を伝えます。

```text
/find-skills
Playwrightを使ったE2E testの設計と実装を支援するskillを探してください。
```

```text
$find-skills を使って、Pull Requestのreviewに利用できるskillを探してください。
```

skillは最初に[skills.sh](https://skills.sh/)のleaderboardを確認し、必要に応じてSkills CLIで検索します。

```bash
npx skills find "react performance"
npx skills find "pr review"
npx skills find testing --owner vercel-labs
```

候補が見つかると、用途、install数、配布元、install command、詳細ページが提示されます。提示されたskillをこの
dotfilesで継続管理する場合は、提案された`npx skills add`を直接実行するのではなく、upstreamを確認して
`dot_apm/apm.yml`へcommit SHAまたはrelease tagでpinし、APMでインストールしてください。

## 軽量な仕様駆動開発 workflow の選定と運用

この文書は、最初の仕様案を作った後に壁打ちで穴を見つけ、仕様へ戻してから画面設計・task分解・AI実装へ進むための
比較・運用ガイドです。

結論は、**まず[OpenSpec](https://github.com/Fission-AI/OpenSpec)を主軸として試す**ことです。Spec Kitはcoverage検査が
充実する一方、今回重視する「文書量を抑え、作った仕様へ後から判断を反映する」用途には重めです。OpenSpecは
proposal・delta spec・design・tasksという小さなartifactを任意の時点で更新でき、`update`が既存artifact間の整合を
取り直し、`verify`が実装との差を検査します。

> [!IMPORTANT]
> framework名よりgateの設計が重要です。「taskがすべてchecked」だけを完了条件にせず、要件・scenario → task → test →
> codeのtraceabilityと、実装後の独立検証を必須にします。

### 調査した候補

2026-08-15時点の各公式repositoryと同梱workflowを確認しました。star数ではなく、artifact量、仕様を後から直せるか、
実装・検証の仕組み、導入負荷で比較しています。

#### 有力候補

| 候補                                               | 特徴                                                                                            | 実装漏れへの防御                                      | 分量・導入負荷                                   | 判断                                                                      |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------- |
| [OpenSpec](https://github.com/Fission-AI/OpenSpec) | proposal・delta spec・design・tasksを変更単位で管理。`update`で既存artifactを相互に再整合できる | requirement / scenarioとtaskを`verify`で実装に照合    | **軽い**。Node CLI、30以上のagentに対応          | **第一候補**。今回の「仕様案 → grill → 仕様へ反映」に最も素直             |
| [Superpowers](https://github.com/obra/superpowers) | brainstorming → design承認 → plan → taskごとのsubagent実装。TDDと2段階reviewを強制              | taskごとにspec compliance reviewとcode quality review | **軽〜中**。skill中心で自動発火                  | 実装品質の補助に有力。ただし要件台帳の差分管理はOpenSpecほど明示的でない  |
| [cc-sdd](https://github.com/gotalab/cc-sdd)        | Kiro風のrequirements → design → tasksと、taskごとのfresh implementer / independent reviewer     | EARS、task boundary、TDD、独立review、auto-debug      | **中**。17 skillsとphase gate                    | 長時間の自律実装と漏れ防止を優先する場合の第二候補                        |
| [GSD Core](https://github.com/open-gsd/gsd-core)   | Discuss → Plan → Execute → Verify → Shipをphaseごとに繰り返す                                   | fresh contextのexecutorと完了前verify、fix plan       | **中〜重**。subagent orchestrationと状態artifact | 大規模・長時間実装向け。小機能には過剰になりやすい                        |
| [Tsumiki](https://github.com/classmethod/tsumiki)  | EARS要件、設計、task、TDD、Web test / UATまで一式                                               | `task-breakdown`、TDD、`dev-verify`、UAT              | **中〜重**。導入skill数と成果物が多い            | test-firstを最優先する場合。task自体の欠落には別のtraceability gateを足す |

#### 用途が合えば候補になるもの

| 候補                                                              | 得意なこと                                                                    | 今回の主軸にしない理由                                                        |
| ----------------------------------------------------------------- | ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| [Conductor](https://github.com/gemini-cli-extensions/conductor)   | project context、featureごとのspec / plan、実装後reviewと修正task追加         | setup時のproduct・guideline・tech stack等のartifactが増える                   |
| [Agent OS](https://github.com/buildermethods/agent-os)            | codebase標準をagentへ注入し、product planとspecをshapeする                    | 仕様策定には良いが、公開workflow上の実装後coverage監査は薄い                  |
| [LeanSpec](https://github.com/codervisor/leanspec)                | 2K token未満を目安にした小さいspec、Markdown / GitHub Issues / ADO等のbackend | spec管理・検索・dashboardが中心で、厳格な実装loopは利用側で設計する必要がある |
| [Spec Workflow MCP](https://github.com/Pimzino/spec-workflow-mcp) | requirements → design → tasksの承認、dashboard、進捗・implementation log      | MCP serverと別processのdashboardを運用する必要がある                          |
| [Spec Kitty](https://github.com/Priivacy-ai/spec-kitty)           | work package、worktree、review / accept / merge、audit trail                  | team向けgovernanceが強く、個人の軽量flowには重い                              |
| [BMad Method](https://github.com/bmad-code-org/BMAD-METHOD)       | Analyst、PM、UX、Architect等の専門roleを含むproduct discovery                 | 小〜中規模機能にはroleと成果物が過剰になりやすい                              |
| [GitHub Spec Kit](https://github.com/github/spec-kit)             | constitution、clarify、checklist、artifact間analyze、実装後converge           | 漏れ検査は強いが、厳格なphaseとMarkdown量が今回の希望より多い                 |

Pimzinoの旧[Claude Code Spec Workflow](https://github.com/Pimzino/claude-code-spec-workflow)は開発の中心がMCP版へ移行済みのため、
新規採用候補から外します。また、単にprompt templateを複製する小規模projectは候補が多いものの、更新・検証・複数agent対応の
いずれかが弱いものはpilot対象に含めません。

### 選定方針

1. **OpenSpecを2〜3機能でpilot**し、同程度のTsumiki利用実績と比較する。
2. 実装の自律性を上げたい場合だけ、cc-sddまたはSuperpowersを別pilotにする。同一featureで複数frameworkのartifactを
   二重生成しない。
3. 次を計測する: artifact総行数、要件からtaskへのcoverage、受け入れscenarioのtest化率、実装後に見つかった漏れ、
   人間のreview時間、仕様変更の反映時間。
4. OpenSpecの`verify`はcode検索を含むheuristicな検査なので、test実行と人間の受け入れ確認を置き換えない。

### 推奨 workflow: OpenSpec → grill → update

```mermaid
flowchart LR
    A[依頼・制約] --> B[OpenSpec propose: 仕様案]
    B --> C[人間が一次review]
    C --> D[grill-me: 仕様案を反証]
    D --> E[decision logを承認]
    E --> F[OpenSpec update: 既存仕様へ反映]
    F --> G[validate・人間が再承認]
    G --> H[wireframe-spec]
    H --> I[画面上の新判断をupdate]
    I --> J[task coverage gate]
    J --> K[apply: 小batch実装]
    K --> L[test・browser確認]
    L --> M[verify: 実装差分監査]
    M -->|仕様の残差| F
    M -->|実装の残差| K
    M -->|合格| N[archive・PR]
```

#### 0. OpenSpecをprojectへ導入する

OpenSpec CLIはmiseでversionをpinし、hostのglobal環境とdevcontainer imageの両方へ導入します。

| 実行環境     | mise設定                            | installされるタイミング                             |
| ------------ | ----------------------------------- | --------------------------------------------------- |
| host global  | `dot_config/mise/config.toml`       | `chezmoi apply`後のglobal `mise install`            |
| devcontainer | `dot_config/devcontainer/mise.toml` | devcontainer image build中の`mise install -C /mise` |

hostですぐ反映する場合は次を実行します。devcontainer側は設定変更後にimageをrebuildします。

```bash
node --version # 20.19.0以上であることを確認する
chezmoi apply
mise install npm:@fission-ai/openspec
openspec --version
```

OpenSpecにはNode.js 20.19.0以上が必要です。このdotfilesではhost globalとdevcontainerのどちらも要件を満たすNode.jsをmiseで
pinしています。個別環境でversionが要件未満なら、利用中のversion managerでNode.jsを更新してからinstallします。

CLIを導入した後、対象repositoryごとに初期化します。APMからskillだけを抜き出さず、CLIが対象agent用のcommand / skillを
生成する公式手順を使います。

```bash
cd <project>
openspec init
```

このguideで使用する`/opsx:continue`と`/opsx:verify`を利用できるよう、初期化後にexpanded workflowを選択してprojectへ
反映します。

```bash
openspec config profile # wizardでexpanded workflowを選択する
cd <project>
openspec update
```

以下ではClaude Codeのcanonical表記`/opsx:<command>`を使います。Codexでは生成された`$openspec-<command>`を使います。

#### 1. まず仕様案を作る

最初から質問だけを始めるのではなく、現在分かっている範囲をreview可能なartifactへ固定します。

```text
/opsx:propose <feature-name>
目的: <達成したい結果>
対象user: <user>
既決事項: <変更しない判断>
制約: <期限・互換性・security・運用>
```

`propose`は通常、proposal、delta spec、design、tasksを一度にdraftします。この時点のtaskは実装許可ではなく、仕様の穴を
探す材料です。生成後に、最低限、scope、requirement / scenario、仮定、未決事項を人間が一次reviewします。

artifactを1つずつ承認したい場合だけexpanded profileを有効にし、`/opsx:new`と`/opsx:continue`を使います。分量削減が
目的なら`propose`はdefaultのcore profileのまま利用できます。ただし、最終gateで`/opsx:verify`を使うため、上記の手順で
expanded workflow自体は有効にしておきます。

##### 4項目へどの粒度で書くか

`propose`の入力は完成した要件定義書ではなく、agentが最初の仕様案を作るための**境界線**です。通常は1項目につき1〜5 bullet、
全体で15〜30行程度にします。画面、API、database tableをすべて確定させる必要はありません。

| 項目           | 書く内容                                                                     | 書かない内容                                            |
| -------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------- |
| `feature-name` | 1つのreleaseまたは検証可能なchange。kebab-caseで結果が分かる名前             | app全体を無条件に`build-app`へ詰め込むこと              |
| 目的           | 誰のどのproblemを、どの状態へ変えたいか。可能なら成功を観測する指標          | 画面やlibraryの羅列。「AIを使う」のような手段だけの説明 |
| 対象user       | 最初に最適化するprimary userと利用状況。secondary userは分けて書く           | 「すべての人」のように優先順位が決まらない表現          |
| 既決事項       | review済みで、このchange中には比較し直さないproduct / technical判断とscope外 | 候補にすぎないframeworkや、まだ迷っている二択           |
| 制約           | 違反するとreleaseできない期限、platform、privacy、互換性、予算、運用条件     | 単なる好みや、数値・判定方法のない「高速・安全」        |

粒度は次の3段階から選びます。

1. **短いspike（5〜10行）**: feasibility調査や捨てる前提のprototype。目的、primary user、最大の制約だけを書く。
2. **通常のfeature / MVP（15〜30行、推奨）**: 目的とMVP境界、primary user、確定事項、scope外、hard constraintを書く。
   画面案や技術候補は補足として渡すが、未決なら明確に「候補」とする。
3. **高risk change（30〜60行）**: 個人情報、課金、migration、外部連携、既存互換性がある場合。data flow、保持・削除、failure、
   rollback、運用責任まで入力する。それ以上なら1つのchangeを分割する。

次の情報は最初から渡すと良い一方、決め切る必要はありません。

- **渡す**: app concept、primary user、MVPで完了させたいuser journey、必須画面、明確なscope外、確定済み技術、privacy上の前提。
- **未決として渡す**: 比較中のstorage / state管理、calendarかlistか、AI provider、通知頻度など。候補を既決事項へ混ぜない。
- **grillへ残す**: data送信への同意、AI失敗時の保存、録音時間上限、音声削除、offline、感情分析の誤判定表示など、
  product ownerの判断が必要な点。agentがrepositoryや公式資料から調査できる事実は質問事項にしない。

##### VoiceDiary AIの場合

提示されたconceptをそのまま1 changeへ入れると、録音、文字起こし、AI enrichment、CRUD、振り返り、通知、themeまで含むため
taskが大きくなります。次の例では「録音 → 文字起こし確認・修正 → AI enrichment → 保存 → 一覧・詳細・編集・削除」を
1つのMVPに含める一方、週次・月次のAI振り返り通知とthemeは次のchangeに分けます。さらに小さく始めたい場合は、後述する
録音spikeを先に実行するか、AI enrichmentも別changeへ分割します。

次が**通常のMVPとして推奨する入力例**です。

```text
/opsx:propose voice-diary-mvp

目的:
- 日記を書きたいがtypingが負担で続かない人が、音声から日記を短時間で作成・保存できるようにする。
- 最初のMVPでは「録音開始 → 文字起こし確認・修正 → 保存 → 一覧・詳細から再閲覧」を完結させる。
- 成功は、初回userが説明なしで3分以内に1件を保存できることと、保存済み日記を再度開けることで確認する。

対象user:
- primary: 日本語で日記を残したいが、mobileで長文をtypingするのが負担なiOS / Android user。
- 利用状況: 1人で過ごす時間に、数分話してその日の考えや感情をprivateに記録する。
- secondary: typingや細かい操作が苦手なuser。accessibility要件は落とさないが、MVPの主対象はprimary userとする。

既決事項:
- Expo / React NativeでiOS・Android向けに作る。
- 日記の本文、生成metadata、音声fileはdevice-localをsource of truthとして保存する。
- 保存前に文字起こし結果を表示し、userが修正・保存cancelできる。
- MVPには録音、文字起こし、AIによるtitle・summary・感情・tag、一覧、詳細、編集、削除を含める。
- account、cloud sync、共有・SNS、複数device同期、週次・月次のAI振り返り通知はMVPのscope外とする。

制約:
- microphone permissionを拒否した場合と、録音・文字起こし・AI生成が失敗した場合に、dataを失わずretryまたは本文手入力へ進める。
- 外部AIへ送るdata、送信目的、保存有無をuserへ説明し、明示的な同意なしにprivateな日記を送信しない。
- AI生成結果は事実や診断として扱わず、userが編集または削除できる補助情報として表示する。
- offline時も保存済み日記の閲覧・編集・削除ができる。networkが必要な処理は再実行可能にする。
- 日記削除時に本文・生成metadata・対応する音声fileを一貫して削除する。

未決事項（仕様案で選択肢を比較し、grill-meで決める）:
- 文字起こしとAI enrichmentへGemini APIを使う範囲。音声を直接送るか、別の文字起こし手段からtextだけを送るか。
- 外部provider側のdata retention、user同意の再確認方法、AI処理前に匿名化できる情報。
- 録音時間・file容量の上限、AI失敗時に生成metadataなしで先に保存するか。
- local storageはSQLite、FileSystem、secure storageをdata種別ごとにどう分けるか。
```

この例で重要なのは、`Gemini`、state管理library、storage実装を「技術仕様案に書かれていたから」という理由だけで既決事項に
しないことです。特に「device内に保存する」と「処理のため外部AIへ送信する」は両立し得ますが、**local-onlyではありません**。
送信data、同意、provider側の保持、削除要求を仕様として決める必要があります。

個人の日記をproductionで扱う**高risk change**として策定する段階では、上のMVP例へ少なくとも次を追記します。

```text
追加する制約:
- data flow: 音声・文字起こし・生成metadataごとに、device、app backend、外部providerのどこを通るかを明記する。
- retention: deviceと外部providerの保持期間、backupの有無、削除操作が各copyへ反映される期限を決める。
- consent: 初回送信前に送信dataと目的を提示し、拒否後もAIなしで日記を保存できるようにする。
- access: device紛失、OS backup、lock screen通知からprivateな本文が露出しない方針を決める。
- safety: 感情分析を医療判断・危機判定に使わず、誤生成の報告・編集・削除手段を用意する。
- operations: provider障害、quota超過、API key漏えい時の停止手順、retry上限、userへの表示を決める。
- release gate: privacy review、実機permission test、削除test、offline testがpassするまでreleaseしない。
```

この情報を含めても60行を大きく超える場合は、録音・保存、AI enrichment、振り返り通知を別changeに分割します。

AI振り返りを次のchangeにする場合は、次のように短く始めます。

```text
/opsx:propose voice-diary-reflection
目的: userが過去1週間または1か月の日記から、自分で振り返るきっかけを得られるようにする。
対象user: VoiceDiary MVPで複数の日記を保存し、振り返り通知を明示的に有効化したuser。
既決事項: 通知はopt-inで初期値OFF。関連日記を確認できる。医療・心理診断を行わない。
制約: privateな日記の送信範囲と保持を説明する。通知本文をlock screenへ表示するかuserが選べる。OFF時は生成しない。
```

逆に、録音APIが要件を満たすかだけを調べるspikeなら、次の粒度で十分です。

```text
/opsx:propose voice-recording-spike
目的: ExpoでiOS・Androidの録音、pause、停止、再生、file削除が実現可能か検証する。
対象user: 本実装を判断する開発者。
既決事項: production UIと永続的な日記保存は作らない。検証codeは破棄可能とする。
制約: microphone permission拒否、app background移行、実機での録音file形式と容量を確認し、結果を文書化する。
```

##### `propose`実行後の段取り

`/opsx:propose ai-voice-diary-mvp`を実行して、たとえば次が生成された時点では、**まだ実装を始めません**。

```text
openspec/changes/ai-voice-diary-mvp/
├── proposal.md
├── specs/
│   └── <capability-name>/
│       └── spec.md
├── design.md
└── tasks.md
```

`<capability-name>`はchange名の繰り返しではなく、仕様を所有する機能領域です。たとえば`voice-entry`、`diary-library`、
`ai-enrichment`のようになります。1 changeに複数capabilityがあれば`spec.md`も複数生成されます。実際のpathはschemaにより
異なる可能性があるため、file名を決め打ちせず`status`で確認します。

各artifactの役割は次のとおりです。

| artifact                     | 答える問い                                        | 注意点                                                             |
| ---------------------------- | ------------------------------------------------- | ------------------------------------------------------------------ |
| `proposal.md`                | なぜ行うか、何を変えるか、scopeはどこまでか       | product intentとscopeのsource。実装詳細を詰め込みすぎない          |
| `specs/<capability>/spec.md` | systemが外部から観測可能な何を満たすか            | changeによる**delta spec**。requirementとscenarioをreviewする      |
| `design.md`                  | どのarchitecture・data flow・技術判断で実現するか | alternative、failure、privacy、migrationも確認する                 |
| `tasks.md`                   | どの順序で何を実装・testするか                    | checkboxが実装状態になる。requirement / scenarioとの対応を確認する |

`openspec/changes/.../specs/.../spec.md`は、このchangeが既存仕様へ加える・変える・削除する内容です。この時点で
`openspec/specs/.../spec.md`へ手動copyしません。完了時の`sync`または`archive`でmain specへmergeされ、change directoryは
履歴としてarchiveされます。

###### A. changeとartifactの状態を確認する

terminalで次を実行します。`/opsx:...`はAI assistantのchatへ、`openspec ...`はterminalへ入力する点に注意してください。

```bash
openspec list
openspec status --change ai-voice-diary-mvp
openspec show ai-voice-diary-mvp
openspec validate ai-voice-diary-mvp --strict
```

- `list`: active change名を確認する。
- `status`: 使用schema、artifactの有無・依存関係、planningが完了しているかを確認する。
- `show`: changeの内容をまとめて読む。
- `validate --strict`: delta specの構造、requirement、scenarioなどの形式不備を検出する。

validation成功は「仕様がproductとして正しい」という意味ではありません。形式が正しくても、scope漏れ、曖昧な判断、scenario不足は
残り得ます。

###### B. artifactを順番にreviewする

次の順で読み、気になる点をreview noteへまとめます。まだ直接直しても構いませんが、複数artifactへ波及する変更は後述の
`/opsx:update`を使う方が安全です。

1. **`proposal.md`**
   - primary userと解決するproblemが1つに絞られているか。
   - MVPのin scope / out of scopeが明記されているか。
   - 「voice diaryを作る」のように成功判定不能な目的になっていないか。
2. **各`spec.md`**
   - requirementが画面部品ではなく、userまたはsystemから観測できる振る舞いになっているか。
   - happy pathだけでなく、permission拒否、offline、AI失敗、retry、削除などのscenarioがあるか。
   - `GIVEN / WHEN / THEN`の結果がtest可能か。`適切に`、`高速に`など判定不能な表現が残っていないか。
3. **`design.md`**
   - 音声、文字起こし、日記本文、生成metadataがどこを通り、どこへ保存されるか。
   - device-localと外部AI送信の境界、同意、retention、削除、API key管理が説明されているか。
   - 採用案だけでなく、主要alternativeと採用理由、failure時のfallbackがあるか。
4. **`tasks.md`**
   - 全requirement / scenarioを実装またはtestするtaskがあるか。
   - permission、error、offline、data削除、accessibilityが最後の「その他」へ埋もれていないか。
   - taskが大きすぎず、依存順、完了条件、実行するtestが分かるか。
   - specにない機能を実装するtaskが紛れ込んでいないか。

VoiceDiaryの場合、最初のreviewで最低限次の表を作ると漏れを見つけやすくなります。

| 確認対象      | 対応artifact                         | 最初に確認するscenario例                                    |
| ------------- | ------------------------------------ | ----------------------------------------------------------- |
| 録音          | voice entryのspec / design / tasks   | permission拒否、中断、background、時間上限、file削除        |
| 文字起こし    | voice entryまたはtranscriptionのspec | 失敗、timeout、空結果、修正、再試行、AIなし保存             |
| AI enrichment | AI capabilityのspec / design         | provider障害、誤生成、同意拒否、再生成、metadata編集・削除  |
| local diary   | diary libraryのspec / tasks          | CRUD、app再起動、offline、音声と本文の一貫削除              |
| privacy       | proposal / spec / design             | 送信前説明、送信data、retention、OS backup、lock screen露出 |

###### C. 作成済み仕様を`grill-me`へ渡す

一次review後、次のpromptで壁打ちします。change名を明示すると、別changeを誤って読むのを防げます。

```text
/grill-me
`openspec/changes/ai-voice-diary-mvp` のproposal、全delta spec、design、tasksを読んでください。
artifact間の矛盾と、未決定・曖昧・test不能・task未対応の要件をdecision treeで質問してください。
repositoryや公式資料から調査できる事実は自分で確認し、product判断だけを私へ質問してください。
終了時は、決定事項、変更するrequirement、追加scenario、design変更、task変更、scope外、未決事項、riskに整理し、
artifactをまだ編集せず私の承認を待ってください。
```

質問への回答が終わったら、agentが出したdecision logをそのまま採用せず、自分が同意した項目だけを承認済みとして残します。

###### D. 承認した判断を全artifactへ反映する

同じAI chat、またはartifactを読み直せる新しいsessionで次を実行します。

```text
/opsx:update ai-voice-diary-mvp
以下の承認済みdecision logを既存artifactへ反映してください。
proposal → 全spec → design → tasksの整合を確認し、変更案と理由をartifactごとに提示してください。
私が各変更を承認してからfileを更新し、未決事項は勝手に決めず明記してください。

<承認済みdecision log>
```

`update`は既存artifactを整合させますが、未作成artifactを新規作成しません。`status`にmissing / blockedがある場合は、expanded
workflowの`/opsx:continue ai-voice-diary-mvp`で次のartifactを作ってから、もう一度`update`します。

反映後にもう一度確認します。

```bash
openspec status --change ai-voice-diary-mvp
openspec validate ai-voice-diary-mvp --strict
git diff -- openspec/changes/ai-voice-diary-mvp
```

このdiffを人間が承認するまでは`/opsx:apply`を実行しません。承認済みplanning artifactだけを先にcommitすると、実装後の
code diffと仕様変更を分けてreviewしやすくなります。

```bash
git add openspec/changes/ai-voice-diary-mvp
git commit -m "docs: define AI voice diary MVP"
```

###### E. wireframeを作り、画面由来の判断を戻す

`wireframe-spec`へchange directoryと対象scenarioを渡します。empty / loading / error / permission denied、mobile viewport、
keyboard・screen reader操作を含めてreviewします。画面reviewで新しいproduct判断が出た場合は、wireframeだけに残さず、
`/opsx:update ai-voice-diary-mvp`をもう一度実行してspec・design・tasksへ反映します。

###### F. task coverageを承認してから実装する

実装直前に、requirement / scenario → task → testの対応表をagentへ作らせ、未対応が0であることを確認します。その後、chatで
change名を明示して実装します。

```text
/opsx:apply ai-voice-diary-mvp
```

`apply`は`tasks.md`の未完了checkboxを読み、codeとtestを実装して`[x]`へ更新します。中断した場合は同じcommandを再実行すると
最初の未完了taskから再開できます。長いtask listでは、最初のphaseだけ実装してtest結果とdiffを提示し、承認を待つよう
追加指示して小batchにします。checkboxが`[x]`でも、test成功やrequirement適合を自動的に証明するものではありません。

各batchでproject固有のtest、typecheck、lintを実行し、次も確認します。

```bash
openspec status --change ai-voice-diary-mvp
git diff
```

###### G. 実装を検証して完了する

全taskの実装後、chatで次を実行します。

```text
/opsx:verify ai-voice-diary-mvp
```

`verify`はcompleteness、correctness、coherenceを確認し、CRITICAL / WARNING / SUGGESTIONを報告します。CRITICAL、未完了task、
scenario未対応、失敗testが0になるまで、仕様の問題は`update`、実装の問題は`apply`へ戻します。さらに実browserで主要scenarioと
wireframeとの差を人間が確認します。

問題がなくなったら、必要に応じてdelta specのmain specへのmergeを先にreviewできます。

```text
/opsx:sync ai-voice-diary-mvp
```

`sync`は任意です。changeをactiveのまま`openspec/specs/`へdeltaをmergeします。通常は省略し、次のarchive時に表示される
sync確認へ同意すれば十分です。

```text
/opsx:archive ai-voice-diary-mvp
```

`archive`はartifactとtaskの状態を確認し、未syncならmain specへのmergeを提案してから、changeを
`openspec/changes/archive/<date>-ai-voice-diary-mvp/`へ移します。未完了taskがあってもwarningだけでarchiveできるため、実行前に
必ず自分で`tasks.md`、test結果、`verify`結果を確認します。archive後のmain specとarchive diffをcommitし、PRを作成します。

###### 最短の実行順

迷った場合は、次の順を守れば実装開始を急ぎすぎません。

1. `/opsx:propose ai-voice-diary-mvp`
2. `openspec status` / `show` / `validate`と4 artifactの人間review
3. `/grill-me`で作成済みartifactを壁打ち
4. `/opsx:update ai-voice-diary-mvp`で承認済みdecisionを反映
5. 再validate・diff review・planning artifactをcommit
6. `wireframe-spec`で画面reviewし、新判断があれば再度`update`
7. task coverage承認後に`/opsx:apply ai-voice-diary-mvp`
8. test・browser確認・`/opsx:verify ai-voice-diary-mvp`
9. 残差を`update`または`apply`で解消
10. `/opsx:archive ai-voice-diary-mvp`でspecをmerge・archiveし、PR作成

#### 2. 作成済み仕様を`grill-me`で詰める

`grill-me`には一般的なアイデアではなく、OpenSpec changeのproposal・spec・design・tasksを読ませます。事実調査はagentに任せ、
userにしか決められないproduct判断だけをdecision treeの順に質問させます。

```text
/grill-me
OpenSpec change `<feature-name>` の既存artifactをすべて読んでから、仕様を反証してください。
特に対象user、scope外、権限、data lifecycle、失敗・retry、競合、互換性、migration / rollback、
accessibility、観測性、成功指標、各scenarioのtest可能性を確認してください。
repositoryから調査できる事実は質問せず自分で確認してください。
終了時は「決定事項」「変更する要件」「追加scenario」「scope外」「未決事項」「risk」に整理し、
まだartifactやcodeを編集せず、私の承認を待ってください。
```

この順序なら、質問が抽象論にならず、既存仕様の具体的な文言・欠落を対象にできます。`grill-me`の会話ログ自体はsource of
truthにせず、次のstepで必ずartifactへ反映します。

#### 3. grillの結果を`update`で仕様へ戻す

承認したdecision logを`/opsx:update`へ渡します。`update`はplanning artifactだけを対象に、変更点を1 artifactずつ提示して
承認を取り、proposal・spec・design・tasksの前後方向の不整合を直します。未作成artifactを勝手に作らず、codeも変更しません。

```text
/opsx:update <feature-name>
以下はgrill-me後に承認したdecision logです。既存artifactへ反映してください。
要件には安定したID、各requirementには観測可能なscenarioを付け、削除・scope外も明記してください。
taskには対応する要件ID、test、依存関係、完了条件を持たせてください。
各artifactの変更案と理由を先に示し、私の承認後に1つずつ更新してください。

<承認済みdecision log>
```

反映後は`openspec validate <feature-name> --strict`を実行し、`git diff -- openspec/changes/<feature-name>`を人間がreviewします。
ここが**仕様承認gate**です。grillで決まった事項がchatにしか残っていない、または古いtaskが残る場合は先へ進みません。

#### 4. `wireframe-spec`で画面を固め、判断を再反映する

更新済みspecを入力に、happy pathだけでなくempty、loading、partial、error、permission denied、offline、長文、mobileを対象に
annotated wireframeを作ります。

```text
/wireframe-spec
OpenSpec change `<feature-name>` の承認済みrequirement / scenarioに対応するdesktop・mobileのlow-fi wireframeを
docs/design/<feature-name>/wireframe.mdへ作ってください。各要素へ要件ID、content priority、interaction、data source、
keyboard操作、focus順を注記し、empty / loading / error / permission denied状態を含めてください。
```

`wireframe-spec`は画像生成ではなく注釈付きlayout仕様です。必要ならそこからHTML prototypeを作りbrowserで確認します。
画面reviewで新しい仕様判断が出たら、wireframeだけへ書き足さず、もう一度`/opsx:update`でspec・design・tasksへ戻します。

#### 5. 実装前にtask coverageを確認する

OpenSpecのartifact検証に加え、AIへtraceability表を作らせます。次が0件になるまで`apply`しません。

- taskへmapされないrequirement / scenarioと非機能要件
- requirementへmapされないtask（scope creep）
- test taskのないerror、permission、concurrency、migration / rollback
- spec・design・wireframe・tasks間の用語や状態の不一致
- dependencyまたは完了条件のないtask

#### 6. 小batchで実装し、`verify`する

`/opsx:apply <feature-name>`を使いますが、全件一括の完了表示を信用せず、依存関係に沿った小batchごとにtest、typecheck、lint、
diff reviewを行います。画面は実browserでdesktop / mobileと主要状態を確認します。

実装後はexpanded profileの`/opsx:verify <feature-name>`で、task完了、requirement実装、scenarioのtest coverage、design準拠を
再検査します。指摘が仕様変更なら`update`、実装漏れなら`apply`へ戻し、critical issueと未完了taskが0になってから
`/opsx:archive`とPRへ進みます。

### 最小成果物とgate

| 段階     | 必須成果物                                    | 次へ進む条件                                              |
| -------- | --------------------------------------------- | --------------------------------------------------------- |
| 仕様案   | proposal、delta spec、design、tasks           | 人間が一次review済み                                      |
| grill    | 承認済みdecision log、未決事項、scope外、risk | userがdecisionを明示承認                                  |
| 仕様反映 | 更新済みartifactとdiff                        | strict validation成功、chatだけの決定が0                  |
| 画面     | 状態別・breakpoint別wireframe                 | 全要素が要件IDへtraceでき、画面由来の判断もspecへ反映済み |
| task     | 要件ID・依存・test・完了条件付きtask          | uncovered requirement / scenarioが0                       |
| 実装     | code、test、command結果、画面確認             | batchごとのcheckがpass                                    |
| 完了     | `verify`結果、最終traceability表、PR          | critical、未完了task、未反映reviewが0                     |

### 導入したdesign skill

[`owl-listener/designer-skills`の`wireframe-spec`](https://github.com/owl-listener/designer-skills/tree/20e34c4a587e5eb09fcdf8351fa97b3ad761b31e/prototyping-testing/skills/wireframe-spec)
だけをAPMへcommit SHA pinで追加しています。suite全体を入れないのは、常時読み込まれるskill descriptionと更新対象を
必要最小限にするためです。必要になった時点で`user-flow-diagram`、`state-machine`、visual critique、design handoffを
責務ごとに個別評価します。
