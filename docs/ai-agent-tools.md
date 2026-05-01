# AI Agent Tools

この issue では、以下 6 件のツールを「この repo でどう扱うか」という観点で整理し、必要なものは repo-local に配置した。

- `skills-desktop`
- `rudel`
- `SkillDeck`
- `nono`
- `cr-house`
- `feature-dev`

## この repo で追加したもの

| 追加先                              | 目的                                                                     |
| ----------------------------------- | ------------------------------------------------------------------------ |
| `.claude/plugins/feature-dev/`      | upstream plugin の vendor 保管                                           |
| `.claude/commands/feature-dev.md`   | この repo で `/feature-dev` を直接試せるようにする project-local command |
| `.claude/agents/code-explorer.md`   | `feature-dev` 用の project-local agent                                   |
| `.claude/agents/code-architect.md`  | `feature-dev` 用の project-local agent                                   |
| `.claude/agents/code-reviewer.md`   | `feature-dev` 用の project-local agent                                   |
| `.claude/skills/coderabbit-config/` | `cr-house` 相当の CodeRabbit 設定生成 skill                              |
| `run_once_install-packages_mac.sh`  | `nono` を Homebrew 経由で入れやすくする                                  |

## 採用方針のまとめ

| ツール           | 種別                            | この repo での扱い                                                | 基本セットアップ                       |
| ---------------- | ------------------------------- | ----------------------------------------------------------------- | -------------------------------------- |
| `skills-desktop` | Claude Code Skills 管理 GUI     | 手順書のみ。GUI app のため repo 内にはバイナリを持たない          | Releases から導入                      |
| `rudel`          | Claude Code セッション分析 CLI  | 手順書のみ。ログインと transcript upload を伴うため自動導入しない | `npm install -g rudel`                 |
| `SkillDeck`      | 複数 agent 向け skills 管理 GUI | 手順書のみ。macOS GUI app のため repo 内にはバイナリを持たない    | Releases または Homebrew tap           |
| `nono`           | agent sandbox CLI               | macOS 初期セットアップに組み込む                                  | `brew install nono`                    |
| `cr-house`       | CodeRabbit 設定生成 skill       | `.claude/skills/coderabbit-config/` に配置                        | project-local skill としてそのまま使う |
| `feature-dev`    | Claude Code plugin / workflow   | vendor + project-local command/agent に展開                       | `claude` から `/feature-dev` を実行    |

## 1. skills-desktop

Repo: <https://github.com/Harries/skills-desktop>

### 向いている用途

- Claude Code の skill を GUI で一覧化したい
- `~/.claude/skills` と各 project の `.claude/skills` をまとめて見たい
- GitHub URL や local folder から skill を import したい

### セットアップ

1. GitHub Releases から自分の OS 向けバイナリを取得する
2. アプリを起動する
3. project path 設定にこの repo root を追加する
4. `.claude/skills/` を scan して project-local skill を認識させる

### 基本的な使い方

- `My Skills` で system-level / project-level skills を確認する
- `Skill Marketplace` から公開 skill を探す
- `Skill Import` で GitHub URL か local folder を取り込む
- `Security Scanning` で skill の危険な記述を点検する

### この repo との相性

- project path を設定すれば `.claude/skills/coderabbit-config/` を認識しやすい
- GUI 配布なので、dotfiles 管理は「導入手順の文書化」までに留めるのが自然

## 2. rudel

Repo: <https://github.com/obsessiondb/rudel>

### 向いている用途

- Claude Code の session を後から分析したい
- 組織単位で prompt / response / sub-agent 利用状況を可視化したい

### セットアップ

```bash
npm install -g rudel
rudel login
rudel enable
```

### 基本的な使い方

```bash
rudel upload
```

- `rudel enable` は Claude Code の hook を登録し、session 終了時に自動 upload する
- `rudel upload` は既存 session の一括投入に使う

### この repo との相性

- transcript 全文、git 情報、project path などが upload 対象になるため、個人 dotfiles repo では常時有効化を前提にしない
- auth と外部 upload が前提なので、自動セットアップには入れず、必要時の opt-in に寄せる

## 3. SkillDeck

Repo: <https://github.com/crossoverJie/SkillDeck>

### 向いている用途

- Claude Code だけでなく Codex / Gemini CLI / Copilot CLI など複数 agent の skills を一括管理したい
- symlink 管理と lock file を GUI で扱いたい

### セットアップ

推奨:

```bash
brew tap crossoverJie/skilldeck
brew install --cask skilldeck
```

または GitHub Releases から `SkillDeck.app` を導入し、初回起動時に署名回避が必要なら次を実行する。

```bash
xattr -cr /Applications/SkillDeck.app
```

### 基本的な使い方

- Dashboard で skill 一覧と registry を確認する
- GitHub / local folder から skill を import する
- agent assignment を切り替えて、どの CLI に symlink するかを決める

### この repo との相性

- 複数 agent をまたぐ skill 配布の確認には便利
- GUI app なので repo では設定方針だけを残し、バイナリ管理はしない

## 4. nono

Repo: <https://github.com/always-further/nono>

### 向いている用途

- Claude Code などの agent を OS カーネル強制 sandbox の中で動かしたい
- 「危険コマンドをそもそも実行させない」運用をしたい

### 原理

- capability ベース: `--allow` / `--read` / `--write` で与えた範囲だけを能力として渡す
- OS カーネル強制: Linux は Landlock、macOS は Seatbelt で制約する
- 危険コマンド遮断: `rm`, `dd`, `chmod`, `sudo`, package manager などを default で block する
- secret 注入: API key や token を安全に process へ渡す設計を持つ
- profile: `claude-code` などの built-in profile で audited な最小権限を再利用できる
- ephemeral / rollback 系: snapshot / rollback を安全装置として持つ設計で、upstream README でも atomic rollback を前面に出している

### セットアップ

macOS:

```bash
brew install nono
```

この repo では `run_once_install-packages_mac.sh` に `nono` の install を追加してある。

### 基本的な使い方

Claude Code を包む最小例:

```bash
nono run --profile claude-code -- claude
```

追加ディレクトリも許可したい場合:

```bash
nono run --profile claude-code --allow /tmp -- claude
```

任意 command を dry-run で確認したい場合:

```bash
nono run --allow . --dry-run -- claude
```

### この repo との相性

- dotfiles repo は shell script や OS 設定が多く、agent の誤操作リスクを減らす用途に合う
- 一方で package install や `chezmoi apply` のような system-wide 変更は block されやすいので、許可パスと command block の設計が必要
- まだ early alpha のため、常用前に profile と制約を小さく試すのが前提

## 5. cr-house

Repo: <https://github.com/goofmint/cr-house>

### 向いている用途

- `.coderabbit.yaml` を対話で作りたい
- review 対象言語、トーン、除外パス、`path_instructions` を整理したい

### この repo でのセットアップ

- `.claude/skills/coderabbit-config/SKILL.md` を追加した
- project root で `claude` を起動すれば project-local skill として読まれる想定

### 基本的な使い方

```text
.coderabbit.yaml を作成して
```

または:

```text
CodeRabbit 用の設定をこの repo 向けに作って
```

期待する挙動:

1. repo 構成と主な拡張子を調べる
2. review 方針と除外対象を質問する
3. `path_instructions` を含む `.coderabbit.yaml` を生成する

### この repo との相性

- dotfiles repo は shell / toml / json / markdown が混在するため、`path_instructions` と除外パスの整理がしやすい
- org-wide default ではなく repo-local 設定のたたき台を作る用途に向く

## 6. feature-dev

Repo: <https://github.com/anthropics/claude-code/tree/main/plugins/feature-dev>

### 向いている用途

- 実装前に codebase 調査、設計比較、review を段階的に進めたい
- feature 実装時に「調査 -> 質問 -> 設計 -> 実装 -> review」の型を固定したい

### この repo でのセットアップ

- upstream plugin を `.claude/plugins/feature-dev/` に vendor した
- project-local ですぐ使えるように `.claude/commands/feature-dev.md` と `.claude/agents/*.md` に同内容を展開した

### 基本的な使い方

project root で `claude` を起動し、次を実行する。

```text
/feature-dev
```

引数付きでもよい。

```text
/feature-dev CodeRabbit 用の設定ファイル生成フローを追加したい
```

ワークフローは大きく次の 7 段階:

1. 要件確認
2. 既存コード調査
3. 不明点の質問
4. 実装アーキテクチャ比較
5. 実装
6. 品質 review
7. 完了サマリ

### この repo との相性

- rulesync / chezmoi / mise のような repo 固有ルールが多いので、実装前に調査と質問を強制できる点が合う
- plugin install は user-scope の marketplace フロー寄りだが、この repo では project-local command / agent に展開しているため、plugin manager を経由せず試せる

## 試用メモ

- `feature-dev`
  - repo 内に command / agent を置いたので、Claude Code が project-local `.claude/commands` / `.claude/agents` を読める環境ならそのまま試せる
  - `claude plugin validate ./.claude/plugins/feature-dev` は、`mise` shim を避けて Claude の実体バイナリを直接呼ぶ形で通過を確認した
- `coderabbit-config`
  - repo-local skill として配置済み
  - 実際の `.coderabbit.yaml` 生成は Claude Code 実行環境で行う

## どれを使い分けるか

- skills / plugin を GUI で探すなら `skills-desktop` または `SkillDeck`
- Claude Code の行動ログを分析するなら `rudel`
- agent の破壊範囲を先に縛るなら `nono`
- CodeRabbit の設定ファイルを作るなら `cr-house`
- 実装フローそのものを定型化するなら `feature-dev`
