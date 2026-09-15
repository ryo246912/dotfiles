# git / Docker credential

fnox で管理しているのはアプリ・API用のsecretで、git自身の認証情報はgitのcredential helper
機構に任せる方が自然なため、fnoxとは別にchezmoiで管理している。Dockerのcredential設定は
Docker Desktopや利用環境が更新するローカル状態として扱い、dotfilesでは管理しない。

## git: `credential.helper`

HTTPS 経由で git を使うときに毎回 ID/パスワードを聞かれないよう、認証情報を OS の keychain や
メモリキャッシュに保存する仕組み。`dot_config/git/config.tmpl` の `[credential]` ブロックで
OS ごとに設定を分けている:

```text
[credential]
{{ if eq .chezmoi.os "darwin" }}
  helper = osxkeychain
{{- else }}
  helper = manager
  credentialStore = gpg
{{- end }}
```

| OS         | helper                                                                                              | 保存先                             | 永続化                 |
| ---------- | --------------------------------------------------------------------------------------------------- | ---------------------------------- | ---------------------- |
| macOS      | `osxkeychain`                                                                                       | macOS Keychain（暗号化）           | 永続（再起動後も残る） |
| WSL2/Linux | `manager`（[git-credential-manager](https://github.com/git-ecosystem/git-credential-manager), GCM） | `pass`（GPG 暗号化されたファイル） | 永続（GPG 鍵で暗号化） |

このリポジトリでは chezmoi は常に WSL2（`.chezmoi.os` が `"linux"`）側で適用している（ネイティブ
Windows での apply は想定していない）ため、`.chezmoi.os` の分岐は darwin/else の2択にしている。

WSL2/Linux には `osxkeychain` 相当の OS keychain 連携が標準に無いため、GCM +
`pass`（GPG ベースの credential store）を使い、コミット署名に使っている既存の GPG 鍵
（`user.signingkey`）でそのまま暗号化して永続化している。

1. `pass` の store を、コミット署名に使っている GPG 鍵（`dot_config/git/config.tmpl` の
   `user.signingkey`）で初期化する。ハードコードすると鍵ローテーション時に複数箇所を
   更新することになるため、`git config` から直接参照する:
   ```sh
   pass init "$(git config user.signingkey)"
   ```
2. GCM を git の credential helper として登録する。`configure` が書くのは
   `credential.helper = manager` のみで、`credential.credentialStore = gpg` は
   `dot_config/git/config.tmpl`（chezmoi）側が既に設定済みの値を GCM が読むだけなので、
   `configure` 実行後もそちらが上書きされることはない:
   ```sh
   git-credential-manager configure
   ```
3. 非対話 TTY での pinentry は `setup-git-gpg`（`dot_local/bin/executable_setup-git-gpg`）と
   `dot_config/zsh/lazy/wsl.zsh` の `GPG_TTY` export で既に設定済みなので追加対応は不要。

GitHub 自体は `config.tmpl` の `pushInsteadOf` で SSH 運用に寄せているため、この
`credential.helper` が実際に効くのは GitHub 以外の HTTPS git host（社内 GitLab 等）を使うとき。

### 動作確認

```sh
git config credential.helper
# macOS: osxkeychain
# WSL2/Linux: manager

# WSL2/Linux のみ（macOS では `credentialStore` は未設定で osxkeychain が直接使われる）
git config credential.credentialStore
# gpg

pass show git-credential-manager/<host> # GCM が保存したエントリを pass 側からも確認できる
```

実際に HTTPS 認証が必要なホストへ一度アクセスし、2回目以降パスワードを聞かれなければ有効。

## Docker credential

`docker login`の認証情報は`~/.docker/config.json`から参照される。credential storeが設定されて
いない場合、認証情報は同ファイルの`auths`へbase64エンコードされるだけで保存されるため、暗号化
されたsecretとしては扱えない。

`credsStore`を設定すると、認証情報の保存を`docker-credential-<値>`という外部credential helperへ
委譲できる。たとえば`"credsStore": "desktop"`はDocker Desktop付属の
`docker-credential-desktop`を使用する。Docker DesktopではOSのkeychainと連携するcredential
storeがインストール・設定されるため、通常はDocker Desktopが生成した設定をそのまま利用する。

`credHelpers`はレジストリごとに使用するhelperを指定する設定であり、対象レジストリでは
`credsStore`より優先される。helperバイナリはDocker CLIを実行する環境の`PATH`に必要となる。
Docker Desktopを使わないLinux環境では、環境に応じて`docker-credential-pass`や
`docker-credential-secretservice`などを用意する。

### このリポジトリでの扱い

`~/.docker/config.json`にはcredential設定だけでなく、`auths`、`currentContext`、`plugins`、
`features`などDocker DesktopやCLIが更新するマシン固有の状態も含まれる。そのため、
`dot_docker/config.json`などのchezmoi sourceは置かず、ファイル全体をdotfiles管理の対象外とする。

設定内容は次のコマンドで確認する。`auths`の各要素に`auth`が直接含まれている場合は、credential
storeへ移行するため、利用環境に適したhelperを用意してから`docker logout`と`docker login`を
やり直す。

```sh
jq '{credsStore, credHelpers, auths}' ~/.docker/config.json

docker logout <registry>
docker login <registry>
```
