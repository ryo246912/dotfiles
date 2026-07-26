# git / Docker の credential 管理

`git` と `docker login` はどちらもデフォルトでは認証情報をディスクに平文（または base64
エンコードしているだけの実質平文）で残す。fnox で管理しているのはアプリ・API 用の secret で、
git/Docker 自身の認証情報はそれぞれのツールが用意している credential helper 機構に任せる方が
自然なため、fnox とは別に `chezmoi` 側でこの2つを管理している。

## git: `credential.helper`

HTTPS 経由で git を使うときに毎回 ID/パスワードを聞かれないよう、認証情報を OS の keychain や
メモリキャッシュに保存する仕組み。`dot_config/git/config.tmpl` の `[credential]` ブロックで
OS ごとに設定を分けている:

```
[credential]
{{ if eq .chezmoi.os "darwin" }}
  helper = osxkeychain
{{- else }}
  helper = cache --timeout=86400
{{- end }}
```

| OS         | helper                  | 保存先                                         | 永続化                       |
| ---------- | ----------------------- | ---------------------------------------------- | ---------------------------- |
| macOS      | `osxkeychain`           | macOS Keychain（暗号化）                       | 永続（再起動後も残る）       |
| WSL2/Linux | `cache --timeout=86400` | メモリ上のみ（`git-credential-cache--daemon`） | プロセス終了・再起動で消える |

WSL2/Linux では `osxkeychain` 相当の OS keychain 連携が標準に無いため、平文で永続化するくらい
なら「消えても構わないメモリキャッシュのみ」にする方針にしている。長期間の永続化が必要になったら
[git-credential-manager (GCM)](https://github.com/git-ecosystem/git-credential-manager) の
導入を検討する（現状は未導入）。

GitHub 自体は `config.tmpl` の `pushInsteadOf` で SSH 運用に寄せているため、この
`credential.helper` が実際に効くのは GitHub 以外の HTTPS git host（社内 GitLab 等）を使うとき。

### 動作確認

```sh
git config credential.helper
# macOS: osxkeychain
# WSL2/Linux: cache --timeout=86400
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
# ログイン後、~/.docker/config.json に "auths" キー（base64 の認証情報）が
# 追加されていないこと（credsStore 経由で Keychain 側に保存されているため）
```

## まとめ

| 項目   | 何を使うか                                 | どこで管理                   | 対象プラットフォーム                       |
| ------ | ------------------------------------------ | ---------------------------- | ------------------------------------------ |
| git    | `credential.helper`（osxkeychain / cache） | `dot_config/git/config.tmpl` | 全プラットフォーム（内容は OS ごとに分岐） |
| Docker | `credsStore`（desktop）                    | `dot_docker/config.json`     | mac のみ（`.chezmoiignore` で他は対象外）  |

どちらも chezmoi 管理下にあるため、手動セットアップは不要。`chezmoi apply` で自動的に反映される。
