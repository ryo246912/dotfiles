#!/bin/bash
#
# yepanywhere (https://github.com/kzahel/yepanywhere) を Tailscale 経由で
# スマホ / タブレットから参照できるように起動するヘルパー。devcontainer 内で実行する想定。
#
# ポイント:
# - Tailscale は userspace networking モードで動かすため TUN デバイスや NET_ADMIN 権限は不要
#   （tailscaled / tailscale CLI は root でなく vscode ユーザーのまま動く）。
# - tailnet 内だけに HTTPS で公開する（`tailscale serve`）。公開インターネットに晒す
#   `tailscale funnel` は使わない。1 人で自分のデバイスからだけアクセスする想定。
# - HTTPS 化されるため、スマホのマイク入力（音声）や通知など secure context 必須の機能も使える。
#
# 使い方:
#   # 認証キーを使う場合（推奨・非対話。devcontainer.json の remoteEnv で host から渡すことも可）
#   TS_AUTHKEY=tskey-auth-xxxx bash ~/.config/devcontainer/scripts/yepanywhere.sh
#
#   # 認証キー無しの場合（初回だけ表示される URL をブラウザで開いてログイン）
#   bash ~/.config/devcontainer/scripts/yepanywhere.sh
#
# 前提（Tailscale 管理コンソールで 1 度だけ）:
#   - MagicDNS を有効化
#   - HTTPS Certificates を有効化（`tailscale serve --https` に必要）
#
set -euo pipefail

PORT="${PORT:-3400}"
TS_STATE_DIR="${TS_STATE_DIR:-$HOME/.local/state/tailscale}"
TS_SOCK="${TS_SOCK:-$TS_STATE_DIR/tailscaled.sock}"
TS_HOSTNAME="${TS_HOSTNAME:-yepanywhere-$(hostname)}"

mkdir -p "$TS_STATE_DIR"
TS=(tailscale --socket="$TS_SOCK")

# 1. tailscaled を userspace networking で起動（既に動いていれば再利用）
if ! "${TS[@]}" status >/dev/null 2>&1; then
	echo "▶ tailscaled を起動します（userspace networking / root 不要）"
	tailscaled \
		--tun=userspace-networking \
		--socket="$TS_SOCK" \
		--statedir="$TS_STATE_DIR" \
		--port=0 \
		>"$TS_STATE_DIR/tailscaled.log" 2>&1 &
	for _ in $(seq 1 30); do
		"${TS[@]}" status >/dev/null 2>&1 && break
		sleep 0.5
	done
fi

# 2. tailnet に参加
up_args=(--hostname="$TS_HOSTNAME" --accept-dns=false)
if [ -n "${TS_AUTHKEY:-}" ]; then
	# ephemeral + reusable な認証キーを推奨（オフラインになったノードは自動で削除される）
	up_args+=(--auth-key="$TS_AUTHKEY")
	echo "▶ 認証キーで tailnet にログインします"
else
	echo "▶ 認証キーが無いため対話ログインします（表示される URL をブラウザで開いてください）"
fi
"${TS[@]}" up "${up_args[@]}"

# 3. tailnet 内のみに HTTPS で yepanywhere を公開（funnel ではないので tailnet 外からは見えない）
"${TS[@]}" serve --bg --https=443 "http://127.0.0.1:${PORT}"

# 4. アクセス URL を表示（python3 があれば DNSName から組み立て、無ければ serve status を表示）
url="$("${TS[@]}" status --json 2>/dev/null |
	python3 -c 'import sys,json; print("https://"+json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))' 2>/dev/null || true)"
echo "───────────────────────────────────────────────"
if [ -n "$url" ]; then
	echo "✓ yepanywhere: ${url}/"
else
	echo "✓ yepanywhere を公開しました。アクセス URL:"
	"${TS[@]}" serve status || true
fi
echo "  （同じ tailnet に参加しているスマホ / タブレットからアクセスできます）"
echo "───────────────────────────────────────────────"

# 5. yepanywhere をフォアグラウンドで起動（Ctrl-C で終了）
exec env PORT="$PORT" yepanywhere
