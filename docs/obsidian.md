# Obsidian CLI

Obsidian CLI は独立した CLI パッケージではなく、Obsidian 1.12.7 以降のデスクトップアプリに
同梱されている。このリポジトリでは macOS 版 Obsidian を mise の
`brew-cask:obsidian` bootstrap package として宣言し、アプリと CLI のバージョンをまとめて管理する。

## インストール

chezmoi の設定を反映すると、post-apply hook が不足している bootstrap package を導入する。
Obsidian だけを明示的に同期したい場合も、通常の packages apply を実行する。

```sh
chezmoi apply
# または
mise bootstrap packages apply
```

インストール後、Obsidian で CLI を一度だけ登録する。

1. Obsidian を起動する。
2. **Settings** → **General** を開く。
3. **Command line interface** を有効にし、画面の案内に従う。
4. ターミナルを開き直して動作を確認する。

```sh
obsidian version
obsidian help
```

CLI はデスクトップアプリを操作するため、コマンド実行時に Obsidian が起動していなければ
アプリも起動する。

## バージョン更新

現在の upstream バージョンは `dot_config/mise/config.mac.toml` の Obsidian 行末コメントで追跡する。
Renovate がコメントのバージョンを更新する PR を作成し、マージ後の `chezmoi apply` または次の
コマンドで `latest` の cask に収束させる。

```sh
mise bootstrap packages status
mise bootstrap packages upgrade
```

Obsidian CLI の必要条件は Obsidian installer 1.12.7 以降。アプリ内更新だけでは installer が
古いままになる場合があるため、CLI が登録できないときは bootstrap package を再適用してから
もう一度登録する。

参考: [Obsidian CLI 公式ドキュメント](https://obsidian.md/help/cli)
