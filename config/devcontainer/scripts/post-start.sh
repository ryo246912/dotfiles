#!/bin/bash
set -e

# コンテナ再起動時には bind mount を張り直す必要がある。
if ! bash /home/vscode/.config/devcontainer/scripts/mount-container-only-dirs.sh "${PWD}"; then
	echo "⚠️ プロジェクト生成物の分離に失敗しましたが、残りの起動処理を続行します" >&2
fi

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
# ホストでは host-exec の docker-port だけが実行できる（config/host-exec/commands.sh）。
CRIT_HOST_PORT_FILE=~/.crit-host-port

# docker port の取得はネットワークの一時的な不調で失敗することがあるため数回リトライする。
# （再起動直後で docker port さえ引ければ port 番号自体は同一コンテナである限り変わらないため、
# 一時的な失敗で ~/.crit-host-port を消して有効なキャッシュを失わないようにする）
CRIT_HOST_PORT=""
for _ in 1 2; do
	CRIT_HOST_PORT=$(HOST_EXEC_CONNECT_TIMEOUT=2 HOST_EXEC_TIMEOUT=5 \
		~/.config/devcontainer/scripts/host-exec docker-port "${HOSTNAME}" 7842/tcp 2>/dev/null |
		tail -n1 | sed -E 's/.*://') || true
	[ -n "$CRIT_HOST_PORT" ] && break
	sleep 1
done

if [ -n "$CRIT_HOST_PORT" ]; then
	echo "$CRIT_HOST_PORT" >"$CRIT_HOST_PORT_FILE"
	echo "✓ crit の host port (${CRIT_HOST_PORT}) を ${CRIT_HOST_PORT_FILE} に記録しました"
else
	rm -f "$CRIT_HOST_PORT_FILE"
	echo "ℹ️ crit の host port 取得をスキップしました（devcontainer 外、または mac-host に接続できない環境）"
fi
