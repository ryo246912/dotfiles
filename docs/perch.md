# Perch

macOS または Linux のデスクトップで、dotfiles のコードと GitHub PR を Perch から閲覧する。

1. dotfiles のチェックアウトで `mise run perch:install` を実行する。Linux では GTK 3 と glibc 2.35 以降が必要。CLI は `~/.local/bin/perch` に配置される。
2. `gh auth status` で GitHub の認証を確認し、未認証なら `gh auth login` を実行する。Codex を使う場合は `codex login status` も確認する。
3. `mise bootstrap dotfiles diff '~/.perch/config.toml'` で確認し、`mise bootstrap dotfiles apply '~/.perch/config.toml'` で配置する。既存の設定がある場合は、先に内容を確認して必要な項目を維持する。
4. Perch を起動し、サイドバーで dotfiles を開く。エージェントを使う場合は Settings で利用する CLI を選ぶ。

dotfiles の既定の場所は `~/dotfiles`。別の場所にチェックアウトしている場合は、配置時に `PERCH_DOTFILES_ROOT="$PWD"` を付ける。Perch の Settings で設定を変更した場合は、次の apply に備えて維持したい変更をテンプレートにも反映する。認証情報は GitHub CLI で管理する。

Python は `ty`、TypeScript / JavaScript は `typescript-language-server` を使用する。対象ファイルを開いて Perch のインストール案内に従う。TypeScript / JavaScript のサーバー導入には `node` と `npm` が必要。Perch v0.11.0 が扱うほかの言語は Go、Rust、Java。

[Perch 公式リポジトリ](https://github.com/perch-code/perch) · [設定リファレンス](https://github.com/perch-code/perch/blob/main/docs/configuration.md)
