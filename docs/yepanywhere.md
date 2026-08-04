# yepanywhere

[yepanywhere](https://github.com/kzahel/yepanywhere) は、Claude Code / Codex などのエージェントを
**ブラウザ（スマホ・タブレット・別 PC）から監督**できる、durable な Web UI です。承認ワークフロー・
差分やファイルの確認・音声入力・通知などをモバイルから行えます。

このリポジトリでは **AI エージェントを devcontainer 内で実行する前提**で、yepanywhere もコンテナ内で
起動し、**Tailscale 経由（tailnet 内のみ）で自分のデバイスからアクセスする**構成にしています
（1 人で使う想定）。devcontainer 定義は `dot_config/devcontainer/` を参照してください。

## なぜ Tailscale か

yepanywhere はコンテナ内で `http://localhost:3400` に待ち受けます。これをスマホから開くには外向きの
経路が要りますが、公開リレーやポート開放は 1 人利用にはやり過ぎです。Tailscale なら自分の tailnet に
参加したデバイス間だけで到達でき、`tailscale serve` が **正規の TLS 証明書付き HTTPS** を張ってくれます。
HTTPS（secure context）が必要なマイク入力・通知などのモバイル機能もそのまま使えます。

> [!IMPORTANT]
> 使うのは `tailscale serve`（**tailnet 内だけに公開**）であって `tailscale funnel`（公開インターネットに
> 公開）ではありません。自分のデバイスからしかアクセスできません。

## 構成

| 項目             | 設定                                                        | 場所                                                                                    |
| ---------------- | ----------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| yepanywhere 本体 | `npm:yepanywhere` を mise で導入                            | `dot_config/devcontainer/mise.toml`                                                     |
| Tailscale        | 公式スクリプトで `tailscale` / `tailscaled` を導入          | `dot_config/devcontainer/Dockerfile`                                                    |
| 認証キー（任意） | `TS_AUTHKEY` を host から渡す（remoteEnv）                  | `dot_config/devcontainer/devcontainer.json`                                             |
| 起動ヘルパー     | tailscaled 起動 → tailnet 参加 → `serve` → yepanywhere 起動 | `dot_config/devcontainer/scripts/executable_yepanywhere.sh`（適用後: `yepanywhere.sh`） |
| 待ち受けポート   | `PORT`（既定 `3400`）                                       | 環境変数（ヘルパーが既定値を設定）                                                      |

Tailscale は **userspace networking モード**で動かすため、TUN デバイスや `NET_ADMIN` 権限は不要で、
`tailscaled` も `tailscale` CLI も vscode ユーザーのまま動きます（devcontainer に特別な権限追加は不要）。

## 事前準備（Tailscale 管理コンソールで 1 度だけ）

1. [Tailscale](https://tailscale.com/) のアカウントを作り、手元のスマホ / タブレットにも Tailscale
   アプリを入れて **同じ tailnet** にログインしておく。
2. 管理コンソールで以下を有効化する（`tailscale serve --https` に必要）:
   - **MagicDNS**
   - **HTTPS Certificates**
3. （推奨）**auth key** を発行する。`Settings > Keys > Generate auth key` で
   **Reusable** かつ **Ephemeral** にしておくと、コンテナを作り直すたびにログインし直さずに済み、
   オフラインになった古いノードは自動で削除されて tailnet が散らからない。

発行した auth key を host 側の環境変数に入れておくと、`devcontainer.json` の `remoteEnv` 経由で
コンテナに渡ります（未設定でも動作し、その場合は起動時に対話ログインになります）。

```bash
# host 側（例: ~/.zshrc.local など、コミットしないファイル）
export TS_AUTHKEY="tskey-auth-xxxxxxxxxxxx"
```

> [!NOTE]
> auth key はシークレットです。リポジトリにはコミットせず、host の環境変数（または fnox 等の
> シークレット管理。`docs/fnox.md` 参照）で扱ってください。

## 使い方

devcontainer 内で起動ヘルパーを実行します。

```bash
# 認証キーを使う場合（remoteEnv で TS_AUTHKEY が渡っていれば環境変数の指定は不要）
bash ~/.config/devcontainer/scripts/yepanywhere.sh

# 認証キーをその場で指定する場合
TS_AUTHKEY=tskey-auth-xxxx bash ~/.config/devcontainer/scripts/yepanywhere.sh

# 認証キー無し（初回だけ表示される URL をブラウザで開いてログイン）
bash ~/.config/devcontainer/scripts/yepanywhere.sh
```

ヘルパーは次を順に行います。

1. `tailscaled` を userspace networking で起動（既に起動していれば再利用）
2. `tailscale up` で tailnet に参加（`TS_AUTHKEY` があれば非対話）
3. `tailscale serve --bg --https=443 http://127.0.0.1:3400` で tailnet 内に HTTPS 公開
4. アクセス URL（`https://yepanywhere-<host>.<tailnet>.ts.net/`）を表示
5. `yepanywhere` をフォアグラウンドで起動（`Ctrl-C` で終了）

表示された URL を、同じ tailnet に参加しているスマホ / タブレット / 別 PC のブラウザで開けば、
コンテナ内で動いている Claude Code / Codex のセッションを監督できます。yepanywhere は
`~/.claude` などのマウント済みディレクトリからエージェントのセッションを自動検出します。

## 環境変数

| 変数           | 既定値                          | 説明                                                          |
| -------------- | ------------------------------- | ------------------------------------------------------------- |
| `PORT`         | `3400`                          | yepanywhere の待ち受けポート（`tailscale serve` の proxy 先） |
| `TS_AUTHKEY`   | （空）                          | Tailscale 認証キー。空なら対話ログイン                        |
| `TS_HOSTNAME`  | `yepanywhere-$(hostname)`       | tailnet 上のノード名（＝ アクセス URL のホスト名）            |
| `TS_STATE_DIR` | `~/.local/state/tailscale`      | tailscaled の state / 証明書の保存先                          |
| `TS_SOCK`      | `$TS_STATE_DIR/tailscaled.sock` | `tailscaled` のソケットパス（CLI と daemon で共有）           |

手動で `tailscale` CLI を叩くときは、このソケットを指定する必要があります。

```bash
tailscale --socket=~/.local/state/tailscale/tailscaled.sock status
tailscale --socket=~/.local/state/tailscale/tailscaled.sock serve status
```

## 停止・後始末

```bash
# yepanywhere を止める: フォアグラウンドで動いているので Ctrl-C

# serve の公開設定を消す
tailscale --socket=~/.local/state/tailscale/tailscaled.sock serve --https=443 off

# tailnet から抜ける（ノードを止める）
tailscale --socket=~/.local/state/tailscale/tailscaled.sock down
```

ephemeral な auth key を使っていれば、コンテナを止めてノードがオフラインになると tailnet から
自動的に削除されます。

## トラブルシューティング

- **`tailscale serve` が証明書エラーになる** … 管理コンソールで **MagicDNS** と **HTTPS Certificates**
  が有効になっているか確認してください（本ドキュメント「事前準備」）。
- **スマホから開けない** … スマホ側の Tailscale が **同じ tailnet** で接続中か、`tailscale status` に
  スマホのノードが出ているか確認してください。
- **毎回ログインを求められる / ノードが増える** … Reusable + Ephemeral の auth key を使うと非対話で
  参加でき、古いノードも自動削除されます。
- **`tailscaled` が起動しない** … `~/.local/state/tailscale/tailscaled.log` を確認してください。
  userspace networking モードのため TUN 権限エラーは出ないはずですが、外向きの DERP 接続
  （443/tcp）が塞がれていると tailnet に参加できません。
- **デバイスストリーミング（WebRTC）が不安定** … WebRTC は P2P 接続のため、環境によっては
  tailnet 経由でも品質が落ちることがあります。差分確認・承認・チャットなど HTTP/WebSocket
  ベースの機能は `tailscale serve` 越しで問題なく動きます。

## 関連

- devcontainer 共通基盤: `docs/devcontainer.md`
- 同じく devcontainer 内で動くブラウザ UI（レビュー用）: `docs/crit.md`
- シークレット管理: `docs/fnox.md`
