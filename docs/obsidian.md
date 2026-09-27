# Obsidian CLI from devcontainer

devcontainer 内の `obsidian` は、SSH 経由で macOS ホストの Obsidian CLI を呼び出すラッパーである。
CLI の stdout、stderr、終了ステータスをそのままコンテナへ返すため、通常の CLI と同様に使用できる。

```sh
obsidian version
obsidian vaults
obsidian search query="TODO"
```

引数なしで実行した場合は SSH の PTY を割り当て、Obsidian CLI の対話 TUI を開く。

## ホスト側の初期設定

1. macOS の Obsidian installer を 1.12.7 以降へ更新する。このリポジトリでは
   `dot_config/mise/config.mac.toml` の `brew-cask:obsidian` を mise で管理している。
2. Obsidian を起動し、**Settings → General → Command line interface** から CLI を登録する。
3. ホストのターミナルで CLI と symlink を確認する。

```sh
obsidian version
ls -l /usr/local/bin/obsidian
```

登録に失敗する場合は、公式手順に従ってホスト上で symlink を作成する。

```sh
sudo ln -sf /Applications/Obsidian.app/Contents/MacOS/obsidian-cli /usr/local/bin/obsidian
```

Obsidian CLI はホストのデスクトップアプリを操作する。アプリが停止中の場合、最初のコマンドで起動する。

## SSH の初期設定

この bridge は、devcontainer のホスト通知でも使用している `mac-host` SSH 接続を再利用する。
先に [devcontainer の通知設定](devcontainer.md#devcontainer-からホストへの通知設定macos-のみ) に従い、
専用鍵の作成、`authorized_keys` への登録、macOS のリモートログイン有効化を行う。

devcontainer をリビルドまたは再起動すると `post-start.sh` が `mac-host` を設定し、
`~/.config/devcontainer/scripts` が `PATH` の先頭にあるためラッパーを `obsidian` として利用できる。

```sh
# コンテナ内で SSH と CLI を順番に確認
ssh -F ~/.config/ssh/config mac-host 'test -x /usr/local/bin/obsidian && echo OK'
obsidian version
```

## バージョン管理

コンテナには Obsidian 本体や Headless CLI を重複インストールしない。実際に動作する CLI はホストの
Obsidian.app に同梱されているため、そのバージョンはホスト側の `brew-cask:obsidian` 宣言で管理する。
bridge 自体はこの dotfiles のスクリプトとしてバージョン管理される。

参考: [Obsidian CLI 公式ドキュメント](https://obsidian.md/help/cli)
