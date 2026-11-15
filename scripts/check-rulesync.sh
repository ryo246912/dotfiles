#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
repo_dir="$PWD"
check_dir="$(mktemp -d)"
trap 'rm -rf "$check_dir"' EXIT
cp rulesync.jsonc "$check_dir/"
cp -R .rulesync "$check_dir/"
(cd "$check_dir" && rulesync generate)

status=0
for file in CLAUDE.md AGENTS.md; do
	diff -u "$repo_dir/$file" "$check_dir/$file" || status=1
done
if [ "$status" -ne 0 ]; then
	echo 'rulesync の生成物に差分があります。リポジトリ直下で rulesync generate を実行してください。' >&2
fi
exit "$status"
