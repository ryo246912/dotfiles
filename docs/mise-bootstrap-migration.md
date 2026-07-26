# chezmoi / mise dotfiles 調査と `run_once_install-packages_*.sh` の mise 移行ブリーフ

> このドキュメントは別エージェントに作業を引き継ぐための調査・設計ブリーフです。
> 前半は chezmoi と mise dotfiles の比較調査、後半は `run_once_install-packages_{mac,windows}.sh`
> を mise の宣言的 bootstrap へ置き換えるための具体設計と作業指示です。

## ⚠️ 一次ソース確認に関する注意

この調査は、実行環境のネットワークポリシーにより `mise.jdx.dev` および解説ブログへの直接アクセス
（WebFetch / curl とも CONNECT が 403）ができなかったため、**WebSearch のスニペット・mise の GitHub
リリースノート（v2026.6.6 / v2026.6.14）・本リポジトリの実ファイル**をもとにしています。
特に **`[bootstrap.macos.defaults]` のドメイン表記や launchd エージェントの TOML 書式などの正確な
キー名は一次ソースで裏取りできていません**。作業エージェントは実装前に必ず以下の公式ドキュメントで
正確な TOML スキーマを確認してください。

- https://mise.jdx.dev/bootstrap.html
- https://mise.jdx.dev/bootstrap/packages/brew.html
- https://mise.jdx.dev/bootstrap/launchd.html
- https://mise.jdx.dev/dotfiles.html
- https://github.com/jdx/mise/releases/tag/v2026.6.6
- https://github.com/jdx/mise/releases/tag/v2026.6.14

---

# パート1: chezmoi と mise dotfiles の違い

## 結論（要点）

- **mise dotfiles はクロスプラットフォーム対応**（mise 自体が Linux / macOS / Windows で動く）。ただし
  Windows のネイティブ symlink は管理者権限 or 開発者モードが要る点は chezmoi と同じ制約。
- **設計思想が違う**。chezmoi は「dotfiles 専用の状態管理ツール」、mise dotfiles は「`mise bootstrap`
  （マシン一括構築）の 1 フェーズとして dotfiles も配れる」機能。
- **現状構成を丸ごと mise に置き換えるのは今は非推奨**。特に **① bitwarden によるシークレット注入
  ② `.chezmoiignore` 相当の OS 別除外 ③ `run_once` / `run_onchange` の実行モデル** に mise dotfiles の
  等価物がなく、本リポジトリはこの 3 つを深く使っている。
- ただし **既に mise をパッケージ / ツール層の中心に据えている**（chezmoi の `hooks.apply.post` から
  `mise bootstrap packages` / `mise install` / `mise run` を呼ぶ）ため、「mise を主・chezmoi を従」に
  寄せる素地はある。

## 1-1. 設計思想の違い

| 観点 | chezmoi | mise dotfiles |
| --- | --- | --- |
| 位置づけ | dotfiles 専用マネージャ | `mise bootstrap`（マシン構築）の 1 フェーズ |
| 管理単位 | ソースディレクトリ全体（`dot_` 等のファイル名プレフィックスがマニフェスト） | `mise.toml` の `[dotfiles]` に明示宣言 |
| 適用 | `chezmoi apply` | `mise dotfiles apply` / `mise bootstrap`（`mise install` では走らない） |
| テンプレート | Go `text/template` + chezmoi 独自関数 | Tera（Rust。現在 v2） |
| 成熟度 | 数年運用・広く実績あり | **ごく新しい**（宣言的 bootstrap は v2026.6.6 = 2026年6月頃） |

`mise bootstrap` は「システムパッケージ → repos → **dotfiles** → shell activation → macOS defaults →
LaunchAgents → systemd user services → login shell → tools → bootstrap task」を 1 コマンドで収束させる
思想。dotfiles はその一部という位置づけ。

## 1-2. 機能比較

| 機能 | chezmoi | mise dotfiles |
| --- | --- | --- |
| 配置モード | 生成（コピー相当）+ symlink 対応 | `symlink` / `symlink-each` / `copy` / `template` |
| テンプレート | Go template（`.tmpl`、`.chezmoi.os` 等の変数） | Tera（`{% if os == ... %}`）。glob もソースパスで使える |
| **OS 別の除外** | **`.chezmoiignore`（OS 条件で丸ごと除外）** | **専用の除外機構なし**。エントリを条件付きで宣言するしかない |
| **シークレット** | **age / gpg / git-crypt でファイル暗号化 + bitwarden / 1Password 等の template 関数で注入** | ファイル暗号化なし。**sops + age で暗号化 env → 環境変数**として渡す方式（`env._.file`）。dotfile への任意注入は template 経由で env 参照する形に限られる |
| スクリプト実行 | `run_once_*` / `run_onchange_*` / `run_before/after`（ハッシュ管理付き） | 専用の run スクリプトなし。`hooks` / `tasks` / bootstrap task で代替 |
| 冪等・衝突保護 | あり | あり（既存状態はスキップ。衝突は既定で拒否、`--force-dotfiles` で上書き） |
| 状態管理 | ソースは別ディレクトリ（`~/.local/share/chezmoi`）で真実源 | 設定ファイル内宣言。ソースは repo 内パス |

## 1-3. クロスプラットフォーム（Windows / WSL）

- **mise は Windows ネイティブでも動く** → 「クロスプラットフォーム」の答えは **Yes**。
- 注意点:
  - **symlink モードは Windows だと権限が要る**（管理者 or 開発者モード）。chezmoi は「symlink ではなく
    生成コピー」を既定にして回避している。本リポジトリの `run_onchange_windows.sh.tmpl` /
    `run_once_install-packages_windows.sh` は WSL 前提の作りに見えるため、Windows 側の当て方次第で
    mise の symlink モードは相性が悪くなり得る。
  - **テンプレート言語が別物**（Go template → Tera）。本リポジトリの `.tmpl` 群（`.chezmoi.os` 分岐、
    chezmoi 関数、bitwarden 呼び出し）は **Tera 構文へ全書き換えが必要**で、bitwarden 関数に至っては
    等価物がない。

## 1-4. 本リポジトリ実物での移行可能性評価

| 使っている機能（実ファイル） | mise 代替可否 | コメント |
| --- | --- | --- |
| `dot_*` の生成配置 | ✅ 可 | `[dotfiles]` に `copy` / `template` で宣言し直せば同等 |
| `.tmpl` + `.chezmoi.os` 分岐 | ⚠️ 要全書換 | Go template → Tera。式・関数が別物 |
| **`.chezmoiignore`（darwin / その他で丸ごと除外）** | ❌ 等価物なし | mise は「除外」ではなく「条件付き宣言」で表現するしかなく、`**/*mac*` `**/*win*` `_*` `plan*` 等の広範な glob 除外は再現しづらい |
| `run_once_install-packages_{mac,windows}.sh` | ⚠️ 別モデル | bootstrap task / tasks へ移すことは可能だが「一度だけ実行」のハッシュ管理は自前化が必要（→ パート2で解決） |
| `run_onchange_*.sh.tmpl` | ⚠️ 別モデル | 「変更時のみ実行」も自前ハッシュ or hooks で再実装 |
| **bitwarden シークレット注入**（`.chezmoi.toml` `unlock=auto`、`git/config.tmpl`） | ❌ 直接等価なし | mise は sops + age の env 渡しが基本。bitwarden 連携・任意ファイルへの秘匿値埋め込みは chezmoi の強み |
| `hooks.apply.post` から mise を呼ぶオーケストレーション | 🔄 逆転可 | ここは**むしろ mise 側に寄せられる**。今 chezmoi hook がやっている `mise bootstrap packages` / `mise install` / `rulesync:generate` は mise bootstrap のフェーズ / タスクに自然に載る |

## 1-5. 総合判断

**「できるが、今の構成では割に合わない」** が結論。全面移行ではなく次の折衷が現実的:

1. **ツール / パッケージ / タスク層は mise に集約**（既にそうなっている）。
2. **ファイル配置・OS 別出し分け・シークレットは chezmoi のまま**残す（mise では劣化する領域）。
3. mise dotfiles は、**シークレットを含まず・OS 差分の少ない単純な dotfile**だけを試験的に移す段階的検証に
   とどめる。

---

# パート2: `run_once_install-packages_*.sh` の mise 移行（本題）

## 2-1. 「使い勝手がイマイチ」の正体 = run_once セマンティクス

現状 `run_once_install-packages_{mac,windows}.sh` の痛点は chezmoi の `run_once_` の仕組みそのもの。

- chezmoi は**スクリプトの内容ハッシュ**を state に記録し、**ハッシュが変わった時だけ**再実行する。
- つまり**パッケージを1個足すためにリストを編集すると、ハッシュが変わりスクリプト全体が再実行**される
  （＝各関数の `y/n` プロンプトをまた最初から全部）。
- しかも `run_once` は「一度きり」志向なので、**リストからパッケージを消しても何も起きない**（非収束）。
  失敗時のマーカー整合も崩れやすい。

→ これが「**特にファイルに更新があった場合**」に噛み合わない根本原因。宣言と実行が「ハッシュ一致」で
繋がっているだけで、**望ましい状態（desired state）を持っていない**。

## 2-2. mise bootstrap は逆の設計（宣言的・収束的）

本リポジトリはすでに `[bootstrap.packages]`（`dot_config/mise/config.mac.toml` の `brew:`、
`config.linux.toml` の `apt:`）を使い、`.chezmoi.toml.tmpl` の post-apply hook で
`mise bootstrap packages status --missing` → `apply` を呼んでいる。これが移行の核。

- **`mise bootstrap` は desired state（toml）と actual state を比較して、差分だけを適用**する。
- リストを編集 → `mise bootstrap` を再実行 → **足りないものだけ入る**。全体再実行も y/n もない。
- `mise bootstrap packages status --missing`（既に使用中）でドリフト検知、`mise doctor` でも差分が出る。

### ファイル更新時の挙動の違い

| 操作 | run_once スクリプト（現状） | mise bootstrap（宣言的） |
| --- | --- | --- |
| リストに1個追加 | 内容ハッシュ変化 → **全体再実行 + 全 y/n 再確認** | **差分の1個だけ導入**、対話なし |
| リストから1個削除 | **何も起きない**（非収束） | status で drift として可視化（apply で収束対象） |
| 実行トリガ | chezmoi の run_once ハッシュ | `mise bootstrap`（既存 hook から呼べる） |
| 冪等性 | 各関数内の `command -v` 手書きチェック頼み | mise がネイティブに保証 |

## 2-3. スクリプトの各責務 → mise の対応表

v2026.6.6「Declarative machine bootstrap」＋ v2026.6.14「Bootstrap, end-to-end」で、スクリプトがやっている
ことの**ほぼ全部**に宣言的レイヤーが用意された（`dot_config/mise/config.toml` は
`min_version = "2026.6.6"` 済みなので前提OK）。

| スクリプトの処理 | mise 宣言的レイヤー | 状態 |
| --- | --- | --- |
| brew の CLI（font-hackgen, mise 等） | `[bootstrap.packages]` `brew:` | ✅ 既に移行済 |
| **brew --cask（GUI: chrome, vscode, karabiner, raycast, docker, alacritty 等）** | **`brew-cask` バックエンド**（v2026.6.6 新規。Homebrew 本体なしで cask API メタデータから導入） | ➡️ 移行可 |
| **brew tap（kamillobinski/thock, ankitpokhrel/jira-cli）** | **`[bootstrap.brew.taps]`** | ➡️ 移行可 |
| apt の CLI（linux / WSL） | `[bootstrap.packages]` `apt:` | ✅ 既に移行済 |
| **macOS defaults（Finder / KeyRepeat / InitialKeyRepeat / NSStatusItemSpacing / hotkeys 等）** | **`[bootstrap.macos.defaults]`**（`mise bootstrap macos-defaults apply`、status / doctor でドリフト表示） | ➡️ 移行可 |
| **login items（Clibor / Docker / Raycast）** | **`[bootstrap.macos.launchd.agents]`**（launchd で起動時実行。login item と機能等価） | ➡️ 概ね移行可 |
| **chsh -s zsh** | **`[bootstrap.user].login_shell`**（chsh 実行 + `/etc/shells` 更新まで収束） | ➡️ 移行可 |
| rosetta（softwareupdate --install-rosetta）/ thock --install / clibor `--language=ja` / symbolic hotkeys の複雑な plist | 最終 **bootstrap task**（プロジェクト固有タスク） | ⚠️ 少量だけ task で残す |
| **scoop 本体 + scoop パッケージ（Windows）** | **scoop バックエンドは未実装**（jdx/mise Discussion #5575 の要望止まり） | ❌ mise ネイティブ不可 |

## 2-4. 具体イメージ（`dot_config/mise/config.mac.toml`）

> ⚠️ 下記のキー名（特に `[bootstrap.macos.defaults]` のドメイン表記、`[bootstrap.macos.launchd.agents]`
> の書式）は**未裏取り**。実装時に公式ドキュメントでスキーマ確定のこと。

```toml
[bootstrap.packages]
"brew:git"          = "latest"
# ...既存の CLI（現状の config.mac.toml の brew: 群）...

# ↓ run_once の install_cask_package / install_private_cask_package から移設（brew-cask バックエンド）
"brew-cask:alacritty"          = "latest"
"brew-cask:google-chrome"      = "latest"
"brew-cask:firefox"            = "latest"
"brew-cask:visual-studio-code" = "latest"
"brew-cask:karabiner-elements" = "latest"
"brew-cask:raycast"            = "latest"
"brew-cask:docker"             = "latest"
"brew-cask:ghostty"            = "latest"
"brew-cask:slack"              = "latest"
"brew-cask:zoom"               = "latest"
# ... 以下、run_once の cask リストを全て転記 ...

[bootstrap.brew.taps]
# install_work_package / install_cask_package の tap
"kamillobinski/thock"   = {}
"ankitpokhrel/jira-cli" = {}

[bootstrap.user]
login_shell = "zsh"     # windows(WSL)スクリプトの chsh を収束（mac 側でも設定可）

[bootstrap.macos.defaults]
# setup_settings() の defaults write を宣言化
"-globalDomain NSStatusItemSpacing"          = 6
"-globalDomain NSStatusItemSelectionPadding" = 6
"com.apple.finder AppleShowAllFiles"         = true
"com.apple.finder AppleShowAllExtensions"    = true
"com.apple.finder ShowPathbar"               = true
"com.apple.Finder QuitMenuItem"              = true
"NSGlobalDomain KeyRepeat"                   = 2
"NSGlobalDomain InitialKeyRepeat"            = 15
"NSGlobalDomain com.apple.swipescrolldirection" = false

[bootstrap.macos.launchd.agents]
# Clibor / Docker / Raycast を起動時起動（login item 代替）
```

## 2-5. 現実的な着地点

1. **mac 側はほぼ全部 mise に寄せられる** → `run_once_install-packages_mac.sh` は**削除可能**。残るのは
   rosetta / thock --install / clibor 言語オプション / symbolic hotkeys の複雑な plist くらいで、これは
   非対話・冪等な **bootstrap task** 1本にまとめる。
2. **Windows(scoop) は mise ネイティブ非対応** → `run_once_install-packages_windows.sh` は完全には消せない。
   ただし **run_once をやめて mise task 化**すれば「ハッシュ変化で全体再実行 + y/n」問題は解消できる
   （apt 分は既に `[bootstrap.packages]` にあるので、task に残すのは scoop の Windows ホスト
   provisioning だけ）。
3. **呼び出し口**: いまの `hooks.apply.post`（`.chezmoi.toml.tmpl`）は `mise bootstrap packages ...` だけを
   呼んでいるが、これを **`mise bootstrap`（全フェーズ）** に広げれば、chezmoi 側から run_once を消しても
   収束が回る。あるいは chezmoi から切り離して `mise bootstrap` を独立エントリにする。
4. **失われるもの**: 各項目の `y/n` 対話確認。ただし mise bootstrap は非対話・収束前提なので、これは
   むしろ望んでいた方向。WSL apt の sudo / TTY 判定は今の post-apply hook のロジックをそのまま使える。

---

# パート3: 作業エージェントへの指示

## 推奨: mac 先行（低リスク・効果大）

scoop という mise 非対応要素を切り離せ、一番使い勝手が悪い mac の y/n スクリプトを最初に消せるため、
**まず mac だけ移行**することを推奨する。

### ステップ

1. **公式ドキュメントでスキーマ確定**（パート冒頭の注意参照）。特に以下を確認:
   - `[bootstrap.packages]` の `brew-cask:` バックエンドの正式な指定方法（cask 名の付け方）
   - `[bootstrap.brew.taps]` の TOML 書式
   - `[bootstrap.macos.defaults]` のキー表記（ドメイン + キー、型: bool / int / string の扱い）
   - `[bootstrap.macos.launchd.agents]` のエージェント定義書式
   - `[bootstrap.user].login_shell` の指定値（`zsh` かフルパスか）
2. **`dot_config/mise/config.mac.toml` を拡張**:
   - `run_once_install-packages_mac.sh` の `install_cask_package` / `install_private_cask_package` /
     `install_work_package` の cask を `brew-cask:` として `[bootstrap.packages]` に転記。
   - tap を `[bootstrap.brew.taps]` に。
   - `setup_settings()` の `defaults write` を `[bootstrap.macos.defaults]` に。
   - login items を `[bootstrap.macos.launchd.agents]` に。
   - `login_shell = "zsh"` を `[bootstrap.user]` に。
3. **残処理を bootstrap task 化**: rosetta インストール / `thock --install` / clibor の `--language=ja` /
   symbolic hotkeys の複雑な plist 書き込みを、非対話・冪等な mise タスク（`dot_config/mise/tasks/` 配下
   または `[bootstrap]` の最終 task）にまとめる。
4. **`.chezmoi.toml.tmpl` の `hooks.apply.post` を更新**: `mise bootstrap packages ...` の呼び出しを
   `mise bootstrap`（全フェーズ）に広げる。既存の WSL sudo / TTY / 非対話中断ロジックは維持する。
5. **`run_once_install-packages_mac.sh` を削除**。
6. **動作確認**: `mise bootstrap macos-defaults apply` / `mise bootstrap packages status --missing` /
   `mise doctor` でドリフトが正しく検知・収束されることを確認。パッケージを1個足す / 消す操作で、
   全体再実行や y/n が発生せず差分だけ適用されることを確認。

### 注意・制約

- **brew-cask で特殊処理が必要な cask**（`clibor --language=ja`、`google-japanese-ime` の rosetta 前提、
  `thock` の tap + `thock --install`）は宣言だけでは完結しないため、bootstrap task 側で個別対応する。
- **既存の `[bootstrap.packages]` の brew: 群と重複させない**こと（CLI は brew:、GUI は brew-cask: で
  役割分担）。
- **min_version** は既に `2026.6.6`。login_shell や brew-cask など一部は v2026.6.14 相当の機能を含むため、
  必要なら `min_version` を `2026.6.14` に引き上げる。
- **Windows(scoop) はこのフェーズの対象外**。フル移行する場合は別途、scoop provisioning を mise task 化
  （run_once → task）する。mise ネイティブの scoop バックデンドは存在しないので、task から powershell.exe を
  呼ぶ現状ロジックを踏襲する。

## 対象ファイル一覧

| ファイル | 変更内容 |
| --- | --- |
| `dot_config/mise/config.mac.toml` | `[bootstrap.packages]`（brew-cask 追加）/ `[bootstrap.brew.taps]` / `[bootstrap.macos.defaults]` / `[bootstrap.macos.launchd.agents]` / `[bootstrap.user]` を追加 |
| `dot_config/mise/tasks/` | rosetta / thock / clibor / hotkeys 用の bootstrap task を追加 |
| `.chezmoi.toml.tmpl` | `hooks.apply.post` の `mise bootstrap packages` を `mise bootstrap` に拡張 |
| `run_once_install-packages_mac.sh` | 削除 |
| `dot_config/mise/config.toml` | 必要なら `min_version` を `2026.6.14` に引き上げ |
| （フル移行時）`run_once_install-packages_windows.sh` | run_once → mise task 化（scoop 部分） |

---

## 参考リンク

- [Release v2026.6.6: Declarative machine bootstrap · jdx/mise](https://github.com/jdx/mise/releases/tag/v2026.6.6)
- [Release v2026.6.14: Bootstrap, end-to-end · jdx/mise](https://github.com/jdx/mise/releases/tag/v2026.6.14)
- [Bootstrap | mise-en-place](https://mise.jdx.dev/bootstrap.html)
- [brew | mise-en-place (bootstrap packages)](https://mise.jdx.dev/bootstrap/packages/brew.html)
- [launchd | mise-en-place](https://mise.jdx.dev/bootstrap/launchd.html)
- [Dotfiles | mise-en-place](https://mise.jdx.dev/dotfiles.html)
- [Feature request: scoop backend · jdx/mise Discussion #5575](https://github.com/jdx/mise/discussions/5575)
- [What does chezmoi do? — chezmoi](https://www.chezmoi.io/what-does-chezmoi-do/)
