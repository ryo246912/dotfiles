# Obsidian CLI in devcontainer

devcontainer では、デスクトップアプリを含まない公式 CLI の
[Obsidian Headless](https://github.com/obsidianmd/obsidian-headless) を使用する。
`dot_config/devcontainer/mise.toml` の `npm:obsidian-headless` でバージョンを固定しているため、
devcontainer のリビルド時に mise が Node.js と CLI をインストールする。

```sh
ob --version
ob --help
```

## 初期設定

Obsidian Headless は Obsidian Sync / Publish 用の CLI であり、デスクトップアプリを必要としない。
Obsidian Sync を使用する場合は、コンテナ内でログインして vault を設定する。

```sh
ob login
mkdir -p ~/vaults/my-vault
cd ~/vaults/my-vault
ob sync-setup --vault "My Vault"
ob sync
```

継続的に同期する場合は `ob sync --continuous` を実行する。認証情報と vault をコンテナの
リビルド後にも残す場合は、それらの保存先を devcontainer の volume または bind mount に置く。

## `obsidian` コマンドとの違い

[Obsidian CLI](https://obsidian.md/help/cli) の `obsidian` コマンドはデスクトップアプリに
同梱され、起動中のアプリを操作する。独立した CLI パッケージではないため、CLI だけを mise で
devcontainer にインストールすることはできない。

一方、この設定で導入する `obsidian-headless` のコマンド名は `ob` で、デスクトップアプリなしで
Sync / Publish を操作できる。デスクトップアプリ内のコマンドやプラグインを操作する
`obsidian` CLI の完全な代替ではない点に注意する。

## バージョン更新

`dot_config/devcontainer/mise.toml` のバージョンを更新して devcontainer をリビルドする。
Renovate も npm のリリースを検出して更新 PR を作成する。
