# HOST_ENV の一時的な上書き

`templates/zsh/.zshenv.tera` は、`HOST_ENV` が未設定の場合だけ
`config/zsh/host-env.map` から現在のホスト名に対応する値を解決する
（既に `HOST_ENV` が export 済みなら上書きしない）。これを利用すると、
別ロールの設定を一時的なシェルで試せる。

```sh
exec env -u ZDOTDIR -u MISE_ENV -u FNOX_PROFILE -u AGENTSVIEW_PG_MACHINE HOST_ENV=mac,work3 zsh -l
```

- `HOST_ENV=mac,work3` — 試したいロールを明示的に指定し、`host-env.map` の解決をスキップさせる
- `-u MISE_ENV` / `-u FNOX_PROFILE` — 現在のシェルから引き継いだ古い値を外す
- `-u AGENTSVIEW_PG_MACHINE` — 元のロールの値が残るので外す（一時シェルでは未設定になる）
- `-u ZDOTDIR` — 外さないと `~/.zshenv` 自体が読まれない（下記）

## `ZDOTDIR` を外す必要がある理由

`~/.zshenv` が export する `ZDOTDIR`（`${XDG_CONFIG_HOME:-$HOME/.config}/zsh`）を引き継ぐと、zsh は
`~/.zshenv` ではなく存在しない `$ZDOTDIR/.zshenv` を読むため、`HOST_ENV` などの解決・導出が走らない。

## `MISE_ENV`/`FNOX_PROFILE` を一緒にクリアする必要がある理由

`HOST_ENV` 同様、`MISE_ENV`/`FNOX_PROFILE` も「未設定の場合だけ `HOST_ENV` から導出する」実装になっている:

```sh
# dot_zshenv.tmpl
if [ -z "${MISE_ENV:-}" ] && [ -n "${HOST_ENV:-}" ]; then
    export MISE_ENV="$HOST_ENV"
fi
...
if [ -z "${FNOX_PROFILE:-}" ]; then
    case "${HOST_ENV:-}" in
        *work*) export FNOX_PROFILE="work" ;;
    esac
fi
```

`exec $SHELL -l` は現在のシェルの環境変数を引き継ぐため、既に通常起動で
`MISE_ENV`/`FNOX_PROFILE` が export 済みの状態から `HOST_ENV` だけを
上書きしても、この2つは「未設定」ではないため再導出されず、古いロールの
値のまま残ってしまう。`env -u MISE_ENV -u FNOX_PROFILE` で外すと
`-z` 判定が真になり、新しい `HOST_ENV` から正しく再導出される。

## 確認方法

```sh
exec env -u ZDOTDIR -u MISE_ENV -u FNOX_PROFILE -u AGENTSVIEW_PG_MACHINE HOST_ENV=mac,work3 zsh -l
```

起動し直したシェルで:

```sh
echo "$HOST_ENV $MISE_ENV $FNOX_PROFILE"
```
