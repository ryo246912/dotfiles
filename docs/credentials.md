# git / Docker の credential 管理

`git` と `docker login` はどちらもデフォルトでは認証情報をディスクに平文（または base64
エンコードしているだけの実質平文）で残す。fnox で管理しているのはアプリ・API 用の secret で、
git/Docker 自身の認証情報はそれぞれのツールが用意している credential helper 機構に任せる方が
自然なため、fnox とは別に `chezmoi` 側でこの2つを管理している。

## git: `credential.helper`

HTTPS 経由で git を使うときに毎回 ID/パスワードを聞かれないよう、認証情報を OS の keychain や
メモリキャッシュに保存する仕組み。`dot_config/git/config.tmpl` の `[credential]` ブロックで
OS ごとに設定を分けている:

```text
[credential]
{{ if eq .chezmoi.os "darwin" }}
  helper = osxkeychain
{{- else if eq .chezmoi.os "windows" }}
  helper = manager
  credentialStore = wincredman
{{- else }}
  helper = manager
  credentialStore = gpg
{{- end }}
```

| OS                    | helper                                                                                              | 保存先                             | 永続化                 |
| --------------------- | --------------------------------------------------------------------------------------------------- | ---------------------------------- | ---------------------- |
| macOS                 | `osxkeychain`                                                                                       | macOS Keychain（暗号化）           | 永続（再起動後も残る） |
| WSL2/Linux            | `manager`（[git-credential-manager](https://github.com/git-ecosystem/git-credential-manager), GCM） | `pass`（GPG 暗号化されたファイル） | 永続（GPG 鍵で暗号化） |
| Windows（未使用想定） | `manager`                                                                                           | Windows Credential Manager         | 永続                   |

このリポジトリでは chezmoi は常に WSL2（`.chezmoi.os` が `"linux"`）側で適用しており、ネイティブ
Windows で apply することは想定していない。Windows の分岐は、万一そちらで apply された場合に
Linux 専用の `pass`/GPG セットアップへ誤って倒れないための保険で、pass のセットアップ手順は無い。

WSL2/Linux には `osxkeychain` 相当の OS keychain 連携が標準に無いため、GCM +
`pass`（GPG ベースの credential store）を使い、コミット署名に使っている既存の GPG 鍵
（`user.signingkey`）でそのまま暗号化して永続化している。GCM 本体は
`dot_config/mise/config.toml` の `github:git-ecosystem/git-credential-manager` として、
`pass` は `dot_config/mise/config.linux.toml` の `apt:pass` として pin 済みなので
`mise install` すれば入るが、以下の**一度だけの手動セットアップ**が別途必要:

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

## Docker: `credsStore`

`docker login` のデフォルト動作は `~/.docker/config.json` に認証情報を base64 エンコードして
書き込むだけで、暗号化はされていない（実質平文）。`credsStore` を設定すると、外部の credential
helper バイナリに保存を委譲し、OS の keychain 等へ安全に保管できるようになる。

`dot_docker/config.json`（mac のみ）:

```json
{
  "credsStore": "desktop"
}
```

`desktop` は Docker Desktop に同梱されている `docker-credential-desktop`（macOS Keychain と
連携する credential helper）を指す。`.chezmoiignore` で mac 以外は `.docker/config.json` を
デプロイ対象外にしている。`docker-credential-desktop` は Docker Desktop 前提のバイナリで、
Linux/WSL2 の Docker Engine 環境には存在しないため。

### Linux/WSL2 でも管理したくなったら

Docker Desktop が無い環境では、別途 credential helper を用意して `credsStore` をそれに合わせる
必要がある:

- [`docker-credential-pass`](https://github.com/docker/docker-credential-helpers)
  （GPG + `pass` ベース）
- [`docker-credential-secretservice`](https://github.com/docker/docker-credential-helpers)
  （GNOME Keyring / KDE Wallet 経由、Secret Service API 使用）

現状このリポジトリでは未対応（必要になったら `.chezmoiignore` の除外を外し、対応する helper を
`dot_config/mise/config.toml` に pin する形で追加する）。

### 動作確認

```sh
cat ~/.docker/config.json
# {"credsStore": "desktop"} になっていること（mac）

docker login ghcr.io
# ログイン後、ghcr.io の entry が "auths" に追加されていないこと
# （credsStore 経由で Keychain 側に保存されているため。他レジストリの
# 既存 auths エントリは対象外なので、ghcr.io だけを見る）
jq '.auths["ghcr.io"]' ~/.docker/config.json
# null が返ればOK（credsStore 経由で保存されている証拠）
```

## まとめ

| 項目   | 何を使うか                                        | どこで管理                   | 対象プラットフォーム                       |
| ------ | ------------------------------------------------- | ---------------------------- | ------------------------------------------ |
| git    | `credential.helper`（osxkeychain / manager+pass） | `dot_config/git/config.tmpl` | 全プラットフォーム（内容は OS ごとに分岐） |
| Docker | `credsStore`（desktop）                           | `dot_docker/config.json`     | mac のみ（`.chezmoiignore` で他は対象外）  |

どちらも設定自体は chezmoi 管理下にあり `chezmoi apply` で自動反映されるが、WSL2/Linux の git は
上記の `pass init` / `git-credential-manager configure` をマシンごとに一度だけ手動実行する必要が
ある（age の bootstrap と同様、鍵/ストアの初期化はマシンローカルな一度きりの操作のため自動化していない）。
