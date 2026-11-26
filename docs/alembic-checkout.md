## Alembic を使うリポジトリのブランチ切替

Git 2.36 以上で利用できます。dotfiles を配置して対話型 zsh を起動すると、
`git checkout` と `git switch` の切替前に検査します。既存の個人設定に
`git()` があれば削除してください。VS Code の Git UI やスクリプトからの操作には、
リポジトリ側で設定した場合に切替後の検査が使えます。
切替前検査はサブコマンドを先頭に指定する場合に有効です。`git -C ... checkout`
や `git -c ... switch` は Git にそのまま渡ります。別ディレクトリで検査するには
`cd` してから切り替えてください。

初回は以下を実行し、`work3/config` の URL を `git config --get remote.origin.url` で確認した値の
形式に、`work3/guard` のパスとサービス設定を実際の値に置き換えてください。
`private` にはサンプルを参考に非公開の Git 設定を記入します。既存の非公開設定を
移行する場合は、手元の値を引き継いでください。

```sh
mkdir -p ~/.config/git/work3
chmod 700 ~/.config/git/work3
cp -n ~/dotfiles/config/git/work3.example/config ~/.config/git/work3/config
cp -n ~/dotfiles/config/git/work3.example/guard ~/.config/git/work3/
cp -n ~/dotfiles/config/git/private.example ~/.config/git/private
```

dotfiles 内に設定済みの `config/git/work3/` がある場合は、雛形の代わりにその中の
`config` と `guard` を使えます。環境が変わった場合は `preCheckout` の絶対パスを更新してください。

`mise bootstrap dotfiles apply` で Git 設定を配置します。Git がグローバル設定として読む
`~/.config/git/config` から `work3/config` が読み込まれます。URL が一致すると
`work3/guard` が読み込まれます。どちらの実ファイルも Git 管理外に置いてください。

切替後の検出も使う場合は、リポジトリの `lefthook-local.yml` の旧
`pre-checkout` 定義を削除し、次の `post-checkout` を使います。

```yaml
post-checkout:
  commands:
    alembic-guard:
      run: '"/<path/to/dotfiles>/config/git/alembic-pre-checkout" {1} {2} {3}'
```

一時的に検査を省く場合は `ALEMBIC_GUARD=0` を付けます。切替前の呼び出しだけを
省く場合は `GIT_PRE_CHECKOUT=0` を付けます。
