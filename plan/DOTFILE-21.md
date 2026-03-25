# DOTFILE-21: Brewなどのインストールをnixにする

## 概要

このドキュメントはHomebrewで管理しているパッケージをNixで管理するための移行計画と実装内容を説明します。

---

## Nixとは何か

[Nix](https://nixos.org/) は以下の特徴を持つパッケージマネージャー兼ビルドシステムです：

- **宣言的**: パッケージとシステム設定をコードで管理する
- **再現性**: 同じ設定から同じ環境を再現できる
- **アトミック**: ロールバックが容易（更新に失敗しても元の状態に戻せる）
- **マルチユーザー**: 複数ユーザーが独立した環境を持てる

### 主要コンポーネント

| コンポーネント | 役割 |
|---|---|
| **Nix** | パッケージマネージャー本体 |
| **nixpkgs** | Nixパッケージリポジトリ（80,000+パッケージ） |
| **nix-darwin** | macOSシステム設定をNixで管理 |
| **home-manager** | ユーザー設定（dotfiles等）をNixで管理 |
| **nix-homebrew** | Homebrewをnix-darwinで宣言的に管理 |
| **Nix Flakes** | 再現性のあるNix設定の管理方式（lockfileあり） |

---

## アーキテクチャ

```
このdotfilesリポジトリ (~/.local/share/chezmoi/)
├── flake.nix          ← Nix Flakeのエントリーポイント
├── flake.lock         ← バージョンロックファイル（renovateで自動更新）
└── nix/
    ├── darwin/        ← macOS (nix-darwin) 設定
    │   ├── default.nix
    │   └── homebrew.nix
    └── home/          ← home-manager 設定
        ├── darwin.nix
        └── linux.nix
```

### なぜchezmoidotfilesリポジトリをFlakeとして使うのか

chezmoidotfilesリポジトリ (`~/.local/share/chezmoi/`) はGitリポジトリなので、
そのままNix Flakeとして使えます。Nixはgitリポジトリをflakeのソースとして認識します。

```bash
# macOSでnix-darwinを適用する
darwin-rebuild switch --flake ~/.local/share/chezmoi#darwin

# Linux/WSL2でhome-managerを適用する
home-manager switch --flake ~/.local/share/chezmoi#linux
```

---

## macOS: nix-darwin + nix-homebrew

### nix-darwin とは

[nix-darwin](https://github.com/LnL7/nix-darwin) はmacOSのシステム設定をNixで宣言的に管理するツールです。
Homebrewパッケージの管理もサポートしています。

### nix-homebrew とは

[nix-homebrew](https://github.com/zhaofengli/nix-homebrew) はHomebrewのインストールと管理を
Nixで宣言的に行うためのモジュールです。

従来の `run_once_install-packages_mac.sh` での手動インストール:
```bash
brew install git go gpg mise ...
brew install --cask alacritty ghostty ...
```

↓ nix-homebrewで宣言的に管理:
```nix
homebrew = {
  enable = true;
  brews = [ "git" "go" "gpg" "mise" ];
  casks = [ "alacritty" "ghostty" ];
};
```

### セットアップ手順（macOS）

1. **Nixをインストール** (DeterminateSystems installer):
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

2. **nix-darwinをインストール**:
   ```bash
   nix run nix-darwin -- switch --flake ~/.local/share/chezmoi#darwin
   ```

3. **以降の更新**:
   ```bash
   darwin-rebuild switch --flake ~/.local/share/chezmoi#darwin
   ```

---

## Linux/WSL2: home-manager

### セットアップ手順（Linux/WSL2）

1. **Nixをインストール**:
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

2. **home-managerを初期化**:
   ```bash
   nix run home-manager/master -- init --switch --flake ~/.local/share/chezmoi#linux
   ```

3. **以降の更新**:
   ```bash
   home-manager switch --flake ~/.local/share/chezmoi#linux
   ```

---

## Renovateによる自動更新

Nix Flakeは `flake.lock` でインプット（依存関係）のバージョンをロックします。
Renovateの `nix` マネージャーを使うことで、`flake.lock` の自動更新PRを作成できます。

`renovate.json` に以下を追加:
```json
"nix": {
  "enabled": true
}
```

これにより:
- `nixpkgs` のコミットが新しくなると自動でPRを作成
- `nix-darwin`、`home-manager`、`nix-homebrew` なども自動更新

---

## ファイル構成

### `flake.nix`（リポジトリルート）

Flakeのエントリーポイント。以下のインプットを管理:
- `nixpkgs`: nixpkgsメインリポジトリ
- `nix-darwin`: macOSシステム管理
- `home-manager`: ユーザー設定管理
- `nix-homebrew`: Homebrew宣言的管理
- `homebrew-core`, `homebrew-cask`: Homebrewリポジトリ（nixで固定）

### `nix/darwin/default.nix`

macOSのシステム設定:
- システムパッケージ
- macOS設定（defaults）
- home-managerとnix-homebrewの統合

### `nix/darwin/homebrew.nix`

Homebrewパッケージの宣言的設定（現在の `run_once_install-packages_mac.sh` の内容をnixに変換）:
- `brews`: `brew install` のパッケージリスト
- `casks`: `brew install --cask` のパッケージリスト
- `taps`: `brew tap` のリスト

### `nix/home/darwin.nix`

macOSユーザー設定（home-manager）:
- ユーザー情報
- 追加パッケージ

### `nix/home/linux.nix`

Linux/WSL2ユーザー設定（home-manager）:
- ユーザー情報
- Linux向けパッケージ

---

## 移行戦略

現在の `run_once_install-packages_mac.sh` を完全に置き換えるのではなく、
段階的に移行することを推奨します：

1. **Phase 1（現在）**: nixをインストールし、nix-darwinの設定を追加
2. **Phase 2**: nix-homebrewでHomebrewパッケージを管理
3. **Phase 3**: nixpkgsで管理可能なパッケージを徐々にnix管理に移行

---

## 参照

- [nix-darwin](https://github.com/LnL7/nix-darwin)
- [nix-homebrew](https://github.com/zhaofengli/nix-homebrew)
- [home-manager](https://github.com/nix-community/home-manager)
- [DeterminateSystems nix-installer](https://github.com/DeterminateSystems/nix-installer)
- [Nix Flakes](https://nix.dev/concepts/flakes)
