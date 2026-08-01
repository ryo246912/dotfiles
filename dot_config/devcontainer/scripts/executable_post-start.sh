#!/bin/bash
set -e

# SSH configを生成（~/.config/ssh/configに配置）
mkdir -p ~/.config/ssh
SSH_CONFIG=~/.config/ssh/config
touch "${SSH_CONFIG}"
if ! grep -q '^Host mac-host$' "${SSH_CONFIG}"; then
cat >>"${SSH_CONFIG}" <<EOF
Host mac-host
    HostName host.docker.internal
    User ${HOST_USER}
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
EOF
echo "✓ SSH configを生成しました: ~/.config/ssh/config (User: ${HOST_USER})"
else
echo "ℹ️ SSH config (mac-host) は既に存在します"
fi

# mise trust を実行
mise trust
echo "✓ mise trust を実行しました"

# crit の appPort (127.0.0.1::7842) は host port を Docker に自動採番させているため、
# 実際に割り当てられた port を mac-host 経由の `docker port` で調べ、
# ~/.crit-host-port に記録した上でホストへ通知する（devcontainer を複数同時起動しても
# ポート衝突が起きないようにするため。詳細は docs/crit.md 参照）。
# HOSTNAME はコンテナの short ID（Docker のデフォルトのホスト名）と一致する。
#
# SSH オプションについて:
# - BatchMode=yes: 鍵認証が使えない場合にパスワード入力待ちで固まらないようにする
# - StrictHostKeyChecking は指定しない: ~/.config/ssh/config の mac-host 側で
#   accept-new を設定済みのため、ここで no を指定すると host key の変更検知が無効化されてしまう
# - timeout でラップ: ConnectTimeout は接続確立までしかカバーしないため、接続後に
#   リモートコマンドが固まった場合に備える
CRIT_HOST_PORT_FILE=~/.crit-host-port
SSH_OPTS=(-F ~/.config/ssh/config -o BatchMode=yes -o ConnectTimeout=2)

# docker port の取得はネットワークの一時的な不調で失敗することがあるため数回リトライする。
# （再起動直後で docker port さえ引ければ port 番号自体は同一コンテナである限り変わらないため、
# 一時的な失敗で ~/.crit-host-port を消して有効なキャッシュを失わないようにする）
CRIT_HOST_PORT=""
for _ in 1 2; do
	CRIT_HOST_PORT=$(timeout 5 ssh "${SSH_OPTS[@]}" mac-host \
		"docker port '${HOSTNAME}' 7842/tcp" 2>/dev/null | tail -n1 | sed -E 's/.*://') || true
	[ -n "$CRIT_HOST_PORT" ] && break
	sleep 1
done

if [ -n "$CRIT_HOST_PORT" ]; then
	echo "$CRIT_HOST_PORT" >"$CRIT_HOST_PORT_FILE"
	timeout 5 ssh "${SSH_OPTS[@]}" mac-host \
		"macos-notify-cli --title 'crit' --message 'crit UI: http://localhost:${CRIT_HOST_PORT}' --sound Glass" \
		2>/dev/null || true
	echo "✓ crit の host port (${CRIT_HOST_PORT}) を ${CRIT_HOST_PORT_FILE} に記録し、ホストへ通知しました"
else
	rm -f "$CRIT_HOST_PORT_FILE"
	echo "ℹ️ crit の host port 取得をスキップしました（devcontainer 外、または mac-host に接続できない環境）"
fi

# OpenCLI: AI はコンテナ内で動かし、ブラウザはホスト側で動かす構成のためのトンネルを張る。
# OpenCLI の daemon はホストの 127.0.0.1:19825 に固定バインドされ（ポート変更不可・認証なし）、
# ホストの Chrome 拡張(Browser Bridge)とだけ通信する。コンテナ内の `opencli` も自分の
# localhost:19825 に繋ぐ実装のため、SSH ローカルフォワードでコンテナの localhost:19825 を
# ホストの daemon へ橋渡しする。これでコンテナ内の opencli はフラグ無しでホストのブラウザを
# 操作できる（daemon は認証を持たないため直接ポート公開はせず、mac-host への SSH 経由に限定。
# 詳細は docs/opencli.md 参照）。
OPENCLI_DAEMON_PORT=19825
OPENCLI_TUNNEL_MATCH="ssh.*-L 127.0.0.1:${OPENCLI_DAEMON_PORT}:127.0.0.1:${OPENCLI_DAEMON_PORT}.*mac-host"
if pgrep -f "$OPENCLI_TUNNEL_MATCH" >/dev/null 2>&1; then
	echo "ℹ️ OpenCLI daemon への SSH トンネルは既に起動済みです"
elif timeout 5 ssh "${SSH_OPTS[@]}" mac-host true 2>/dev/null; then
	# -N: リモートコマンドを実行せずフォワードのみ行う
	# ExitOnForwardFailure=yes: ポートが既に使われている等でフォワードを張れなければ即失敗させる
	# ServerAliveInterval/CountMax: 接続断を検知してトンネルプロセスを終了させる（stale なポートを残さない）
	# setsid + disown: post-start 終了後もバックグラウンドで生かす
	setsid ssh "${SSH_OPTS[@]}" -N \
		-o ExitOnForwardFailure=yes \
		-o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
		-L "127.0.0.1:${OPENCLI_DAEMON_PORT}:127.0.0.1:${OPENCLI_DAEMON_PORT}" \
		mac-host >/dev/null 2>&1 &
	disown
	echo "✓ OpenCLI daemon への SSH トンネル (localhost:${OPENCLI_DAEMON_PORT} → mac-host) を起動しました"
else
	echo "ℹ️ OpenCLI の SSH トンネルをスキップしました（devcontainer 外、または mac-host に接続できない環境）"
fi
