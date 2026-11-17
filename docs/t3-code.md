# T3 Code

T3 Code は Codex / Claude Code などのセッションをブラウザー・デスクトップ・スマホから操作する UI。
この構成では **実装セッションごとに Git worktree と Docker Sandbox を分け、T3 サーバーも sandbox 内で起動**する。
端末や Git 操作も sandbox 内になる。ホストで `t3` を直接起動せず、`t3-session` を使う。

## 初回導入

Docker Sandboxes の `sbx` が使える PC で実行する。通常の Docker Engine だけでは足りない。
ホスト側は `config/mise/config.toml`、sandbox 側は `config/devcontainer/mise.toml` に
`npm:t3 = 0.1.10` を固定している。npm の `t3` は初回実行時に公式リリースの実行ファイルを
ダウンロードし、SHA256SUMS で確認する。ホストは Node 20.11 以上が必要で、Intel Mac の CLI は非対応。

```bash
cd /path/to/dotfiles
mise bootstrap dotfiles apply
mise install
mise run sandbox:setup
mise run sandbox:build-template codex
command -v t3 t3-session sbx sbx-agent
sbx ls
```

既に sandbox を使っていても、T3 を追加した template は再ビルドする。
既存 sandbox に新しい template のツールは反映されないため、初回は新しいセッション名を使う。
既存環境の bootstrap に関する注意は [setup](setup.md)、認証・mount の仕様は
[Docker Sandboxes](docker-sandboxes.md) を参照。

## 実装セッションを開始・再開する

```bash
cd /path/to/project                 # 毎回同じ元リポジトリから実行
t3-session start fix-login HEAD     # 初回だけ任意の開始 ref を指定できる
```

初回は `t3/fix-login` ブランチと `../worktrees/<repo>-<識別子>-fix-login` を作り、
`t3-<識別子>-fix-login` という sandbox を準備する。
元 checkout の未コミット変更はコピーしない。開始 ref のコミットから作業する。
別の作業には別名を使う。同じセッションを再開するときは次のように開始 ref を省略する。

```bash
t3-session start fix-login
```

セッション名は英小文字・数字・ハイフンの 1〜32 文字（末尾ハイフン不可）。
既存のブランチや別リポジトリのディレクトリは上書きしない。失敗後も worktree は残し、変更を保護する。
`sbx` がない場合や起動に失敗した場合、ホストでの実行には切り替えない。

T3 は前景起動する。出力された `sbx ports` の sandbox port `3773` に対応する host port を確認し、
PC から `http://127.0.0.1:<host-port>` を開く。認証は出力されるペアリング案内に従う。
host port は自動採番なので、複数セッションを同時に起動できる。停止・再起動で番号が変わることがある。

```bash
# 別のターミナルで、同じ元リポジトリから実行
t3-session ports fix-login
t3-session cli fix-login pair
```

T3 の Providers 設定で Codex の認証状態を確認する。
必要なら sandbox 内で CLI のログインを行う（sandbox 名は開始時の表示を使う）。

```bash
sbx exec -u agent <sandbox-name> bash -lc 'mise exec -- codex login --device-auth'
```

認証済みの Codex を選び、追加された worktree のプロジェクトでスレッドを開始する。
このコマンドの「セッション」は一つの実装作業を指す。同じ環境に複数の実装スレッドを作ると
同じ sandbox / worktree を共有するため、独立した実装はホストで別の `t3-session start <別名>` を実行する。
T3 UI の worktree 機能だけで新規作成しても sandbox は分かれない。

## スマホから同じセッションを開く

iOS / Android の公式 T3 Code アプリ、または https://app.t3.codes を使う。
PC が起動していて、sandbox と T3 サーバーが動いている必要がある。
スマホには Git リポジトリや Codex CLI をインストールしない。

### T3 Connect

初回の本人認証はユーザーが行う。別ターミナルで次を実行する。

```bash
t3-session cli fix-login connect link --headless
```

表示された URL を開き、コードを確認して承認する。その後、T3 を Ctrl-C で終了して
`t3-session start fix-login` で再開する。sandbox の中では systemd が使えるとは限らないため、
サービスを入れる `t3 up` ではなく `connect link` と前景起動を使う。
スマホで同じ T3 Connect アカウントにログインし、対象の環境を選ぶと同じスレッドを見られる。
必要に応じて Settings → Sharing & access で新規デバイスの承認を有効にする。

**sandbox ごとに別の T3 環境として数える。** 公式ドキュメントの標準上限は 3 台
（T3 Chat の契約により拡張可能）。多数のセッションには次の Tailscale 経路も使える。
sbx のネットワークポリシーが Connect の認証先や Cloudflare tunnel を遮断する場合、
`sbx policy log` で拒否先を確認する。必要な通信先を個別に許可するか Tailscale 経路を使う。
この設定では sandbox のネットワーク制限を一括解除しない。

### Tailscale 経由（Connect が利用できない場合）

ホスト PC とスマホを同じ tailnet に接続し、MagicDNS と HTTPS 証明書を有効にする。
Tailscale はホスト側で動かす。sandbox 内にインストールする必要はない。

```bash
t3-session ports fix-login
# 3773 に対応する host port に置換。8443 は未使用の HTTPS port を選ぶ。
tailscale serve --bg --https=8443 http://127.0.0.1:<host-port>
t3-session cli fix-login pair
```

スマホアプリの Settings → Environments → Add environment で
`https://<PCのMagicDNS名>:8443` と、新しく発行したペアリングコードを入力する。
PC 内で発行された URL の `127.0.0.1` はスマホには使えない。
Web 版も HTTPS が必要。複数のセッションを使うときは HTTPS port を分ける。
ペアリング URL / コードは認証情報なので共有・コミットしない。

公開先の host port が変わったら、Tailscale Serve の転送先を同じ手順で更新する。
不要になった経路だけを停止するには次を使う（他の Serve 設定をリセットしない）。

```bash
tailscale serve --https=8443 off
```

## 停止・履歴・後片付け

前景の T3 を Ctrl-C で終了する。端末を閉じても使いたい場合はホストの tmux 内で
`t3-session start fix-login` を実行し、tmux から detach する。PC のスリープ中は接続できない。

```bash
t3-session stop fix-login           # sandbox 全体を停止。ファイルと履歴は残る
```

worktree のコードはホストにあり、T3 の履歴・設定・Connect 認証は sandbox の agent ユーザーの
`~/.t3` にある。sandbox の削除・再作成で履歴や追加ログインが消えるため、必要なら先にバックアップする。
template に認証情報を焼き込まない。

実装が終わったら差分を確認し、コミット・マージ後に、対象 sandbox を既存の sbx 運用で削除する。
worktree は `git worktree remove <path>` で削除し、不要ならブランチも手動で消す。
このコマンドは worktree・ブランチ・sandbox を自動削除しない。

## 検証状況と制約

2026-11-18（日本時間）の作業環境には Docker Engine はあるが `sbx` と `/dev/kvm` がない。
T3 CLI 0.1.10 の導入・ヘルプと、起動スクリプトの構文を確認済み。
実際の一時 Git リポジトリと sbx のスタブを使う 12 件のテストで、worktree 分離・再開・失敗時の挙動を検証した。
**実際の microVM 起動、Codex の実会話、スマホからの接続は未確認。**
実機では初回起動後、PC で作ったテストスレッドがスマホに表示されること、
別セッションの worktree と sandbox が別になること、停止後の再開で履歴が残ることを確認する。

テストの再実行（Python 3、Git、Bash が必要。実際の sbx は起動しない）:

```bash
python3 scripts/tests/test_t3_session.py
```

参考: [公式 README](https://github.com/pingdotgg/t3code)、
[リモートアクセス](https://github.com/pingdotgg/t3code/blob/main/docs/user/remote-access.md)、
[バックグラウンド起動](https://github.com/pingdotgg/t3code/blob/main/docs/user/background-service.md)。
