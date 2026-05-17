# gitswitch 導入・利用ガイド

[gitswitch](https://github.com/target-ops/gitswitch) は、ディレクトリごとに Git のユーザー情報を自動で切り替えるツールです。

## 導入方法

このリポジトリでは `mise` を介して `gitswitch` を導入しています。

1. **ツールのインストール**

   ```bash
   mise install
   ```

2. **初期化**
   既存の設定から ID を自動検出します。
   ```bash
   gitswitch init
   ```

## 基本的な使い方

### アイデンティティの紐付け

特定のディレクトリ配下で特定のユーザー情報を使うように設定します。

```bash
# ~/work 配下で 'work' アイデンティティを使用
gitswitch use work ~/work

# ~/personal 配下で 'personal' アイデンティティを使用
gitswitch use personal ~/personal
```

### コミットガードの有効化

誤ったユーザー情報でのコミットを防止するために、グローバルなプリコミットフックをインストールします。

```bash
gitswitch guard install
```

### 状態の確認

現在のアイデンティティや各レイヤー（git, ssh, gh, signing）の設定が一致しているか確認します。

```bash
gitswitch doctor
```

## chezmoi との統合に関する注意点

`gitswitch use` を実行すると、`~/.gitconfig` に `includeIf` ブロックが追加されます。

```gitconfig
# >>> gitswitch:work
[includeIf "gitdir:~/work/"]
    path = ~/.config/gitswitch/identities/work.gitconfig
# <<< gitswitch:work
```

このリポジトリは `~/.gitconfig` を `dot_config/git/config.tmpl` から管理しています。`gitswitch` によって `~/.gitconfig` に直接加えられた変更は、次に `chezmoi apply` を実行した際に上書きされて消えてしまいます。

### 変更を永続化する方法

`gitswitch` による設定を永続化したい場合は、`~/.gitconfig` に追加された内容を `dot_config/git/config.tmpl` に手動で転記してください。

1. `~/.gitconfig` の内容を確認
2. `dot_config/git/config.tmpl` の末尾などに該当の `includeIf` セクションを追記
3. `chezmoi apply` を実行して反映を確認

## 設定のバックアップ

`dot_config/gitswitch/config.json.sample` を参考に、個人の設定を `~/.config/gitswitch/config.json` に配置することができます。
