# DOTFILE-62: multi-worktree list の表示を揃える

## 目的・スコープ

`multi-worktree list` コマンドの出力で各列が横に揃って表示されていない問題を修正する。

## 現状の問題

`cmd_list` 関数がタブ区切り（TSV）でデータを出力しているが、タスク名やパスの長さが異なるためタブ幅だけでは列が揃わない。

例）
```
chore/GIHO/2576/barrier	default	/Users/...	7 repos	devcontainer
chore/GIHO/2577/fileupload/comment	default	/Users/...	6 repos	devcontainer
```

## 実装方針

`cmd_list` の出力を `column -t -s $'\t'` にパイプして、タブ区切りの出力を自動的に整列させる。

また、`has_devcontainer` が空の場合に末尾の空フィールドが残り `column` の列数が不揃いになるのを防ぐため、条件分岐で空フィールドを出力しないようにする。

## 変更ファイル

- `dot_local/bin/executable_multi-worktree`
  - `list` サブコマンドの呼び出し: `cmd_list | column -t -s $'\t'`
  - `cmd_list` 内の出力: `has_devcontainer` が空の場合は末尾タブを除去

## 検証方法

`column` コマンドの動作確認:
```bash
printf "a\tb\tc\nfoo/bar/baz\tdefault\t/very/long/path\n" | column -t -s $'\t'
```

出力が揃っていることを目視確認する。

## リスク・懸念点

- `column` コマンドは macOS/Linux 共に標準搭載のため互換性の問題はない
- `devcontainer` がない行と有る行が混在しても `column` は列数の異なる行を正しく扱う
