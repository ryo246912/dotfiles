#!/bin/bash

set -euo pipefail

# 色定義
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# グローバル変数
WORKTREES_DATA=""
SELECTED_PATH=""
SELECTED_BRANCH=""
SELECTED_ACTION=""

# エラーハンドリング
error_exit() {
	echo "${RED}エラー: $1${NC}" >&2
	exit 1
}

# git worktreeの一覧を取得してグローバル変数に格納
get_worktrees() {
	if ! git worktree list &>/dev/null; then
		error_exit "gitリポジトリではないか、git worktreeが利用できません"
	fi

	# シンプルなパース方法を使用してグローバル変数に格納
	WORKTREES_DATA=$(git worktree list | awk '{
        path = $1
        if (NF >= 3) {
            branch = $3
            gsub(/^\[|\]$/, "", branch)
        } else {
            branch = "(detached)"
        }
        printf "%s\t%s\n", path, branch
    }')

	if [ -z "$WORKTREES_DATA" ]; then
		return 1
	fi

	return 0
}

# worktreeを選択してグローバル変数に格納
select_worktree() {
	if ! get_worktrees; then
		error_exit "worktreeが見つかりません"
	fi

	# デバッグ用出力
	if [[ "${DEBUG:-}" == "1" ]]; then
		echo "${PURPLE}[DEBUG] 取得したworktrees:${NC}" >&2
		echo "$WORKTREES_DATA" | cat -A >&2
		echo "${PURPLE}[DEBUG] 行数: $(echo "$WORKTREES_DATA" | wc -l)${NC}" >&2
	fi

	# fzfで選択 (ブランチ名のみ表示)
	local selected_display
	selected_display=$(echo "$WORKTREES_DATA" | fzf \
		--header="Worktreeを選択してください (Enterで確定, Escでキャンセル)" \
		--delimiter='\t' \
		--with-nth=2 \
		--preview="git -C {1} log --oneline -10 2>/dev/null || echo 'ログ取得エラー'" \
		--preview-window="right:50%")

	if [ -z "$selected_display" ]; then
		echo "${YELLOW}選択がキャンセルされました${NC}" >&2
		return 1
	fi

	# 選択結果から元の形式に戻す（タブ区切りデータから）
	SELECTED_PATH=$(echo "$selected_display" | cut -f1)
	SELECTED_BRANCH=$(echo "$selected_display" | cut -f2)

	# デバッグ用出力
	if [[ "${DEBUG:-}" == "1" ]]; then
		echo "${PURPLE}[DEBUG] 選択結果:${NC}" >&2
		echo "${PURPLE}[DEBUG] パス: '$SELECTED_PATH'${NC}" >&2
		echo "${PURPLE}[DEBUG] ブランチ: '$SELECTED_BRANCH'${NC}" >&2
	fi

	# 選択結果の検証
	if [ -z "$SELECTED_PATH" ] || [ -z "$SELECTED_BRANCH" ]; then
		return 1
	fi

	return 0
}

# アクションを選択
select_action() {
	# 利用可能なアクションとその説明
	local actions="gitui	GitUIでリポジトリを開く
code	VS Codeでディレクトリを開く
nvim	Neovimでディレクトリを開く
czg	czgでコミットを作成
cd	ディレクトリに移動する（新しいシェル）"

	# fzfでアクション選択
	local selected_action_display
	selected_action_display=$(echo "$actions" | fzf \
		--header="実行するアクションを選択してください" \
		--delimiter='\t' \
		--with-nth=1,2 \
		--preview="echo 'アクション: {1}'; echo '説明: {2}'" \
		--preview-window="right:40%")

	if [ -z "$selected_action_display" ]; then
		echo "${YELLOW}アクション選択がキャンセルされました${NC}" >&2
		return 1
	fi

	# 選択されたアクションを抽出
	SELECTED_ACTION=$(echo "$selected_action_display" | awk -F'\t' '{print $1}')

	# デバッグ用出力
	if [[ "${DEBUG:-}" == "1" ]]; then
		echo "${PURPLE}[DEBUG] 選択されたアクション: '$SELECTED_ACTION'${NC}" >&2
	fi

	# 選択結果の検証
	if [ -z "$SELECTED_ACTION" ]; then
		return 1
	fi

	return 0
}

# gituiを開く
open_gitui() {
	local worktree_path="$1"
	local branch_name="$2"

	if [ ! -d "$worktree_path" ]; then
		error_exit "worktreeディレクトリが存在しません: $worktree_path"
	fi

	if ! command -v gitui &>/dev/null; then
		error_exit "gitui コマンドが見つかりません"
	fi

	# worktreeディレクトリに移動してgituiを起動
	cd "$worktree_path" || error_exit "ディレクトリへの移動に失敗: $worktree_path"

	# gituiを起動
	gitui

	return 0
}

# VS Codeで開く
open_code() {
	local worktree_path="$1"
	local branch_name="$2"

	if [ ! -d "$worktree_path" ]; then
		error_exit "worktreeディレクトリが存在しません: $worktree_path"
	fi

	if ! command -v code &>/dev/null; then
		error_exit "VS Code (code コマンド) が見つかりません"
	fi

	# VS Codeでディレクトリを開く
	code "$worktree_path"

	return 0
}

# Neovimで開く
open_nvim() {
	local worktree_path="$1"
	local branch_name="$2"

	if [ ! -d "$worktree_path" ]; then
		error_exit "worktreeディレクトリが存在しません: $worktree_path"
	fi

	if ! command -v nvim &>/dev/null; then
		error_exit "Neovim (nvim コマンド) が見つかりません"
	fi

	# worktreeディレクトリに移動してneovimを起動
	cd "$worktree_path" || error_exit "ディレクトリへの移動に失敗: $worktree_path"

	# neovimを起動
	nvim .

	return 0
}

# czgでコミットを作成
open_czg() {
	local worktree_path="$1"
	local branch_name="$2"

	if [ ! -d "$worktree_path" ]; then
		error_exit "worktreeディレクトリが存在しません: $worktree_path"
	fi

	if ! command -v czg &> /dev/null; then
		error_exit "czg コマンドが見つかりません"
	fi

	# worktreeディレクトリに移動してczgを起動
	cd "$worktree_path" || error_exit "ディレクトリへの移動に失敗: $worktree_path"

	# czgを起動
	czg

	return 0
}

# ディレクトリに移動（新しいシェル）
change_directory() {
	local worktree_path="$1"
	local branch_name="$2"

	if [ ! -d "$worktree_path" ]; then
		error_exit "worktreeディレクトリが存在しません: $worktree_path"
	fi

	# worktreeディレクトリに移動して新しいシェルを起動
	cd "$worktree_path" || error_exit "ディレクトリへの移動に失敗: $worktree_path"

    exec "$SHELL"

	return 0
}

# 選択されたアクションを実行
execute_action() {
	local worktree_path="$1"
	local branch_name="$2"
	local action="$3"

	case "$action" in
	"gitui")
		open_gitui "$worktree_path" "$branch_name"
		;;
	"code")
		open_code "$worktree_path" "$branch_name"
		;;
	"nvim")
		open_nvim "$worktree_path" "$branch_name"
		;;
	"czg")
		open_czg "$worktree_path" "$branch_name"
		;;
	"cd")
		change_directory "$worktree_path" "$branch_name"
		;;
	*)
		error_exit "不明なアクション: $action"
		;;
	esac

	return 0
}

# ヘルプを表示
show_help() {
	cat << 'EOF'
Git Worktree Manager - git worktreeの管理とアクション実行

使用方法:
  git_worktree_manager.sh [オプション] [アクション]

オプション:
  --help, -h      このヘルプを表示
  --debug         デバッグモード（詳細情報を表示）

アクション:
  gitui           GitUIでリポジトリを開く
  code            VS Codeでディレクトリを開く
  nvim            Neovimでディレクトリを開く
  czg             czgでコミットを作成
  cd              ディレクトリに移動する（新しいシェル）

実行例:
  # インタラクティブ選択（worktree選択 → アクション選択）
  git_worktree_manager.sh

  # 直接アクション指定（worktree選択のみ）
  git_worktree_manager.sh gitui
  git_worktree_manager.sh code
  git_worktree_manager.sh nvim
  git_worktree_manager.sh czg
  git_worktree_manager.sh cd

  # その他
  git_worktree_manager.sh --debug   # デバッグモード

EOF
}

# メイン処理
main() {
	# ヘルプの場合
	if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
		show_help
		return 0
	fi

	# デバッグモードの場合
	if [[ "${1:-}" == "--debug" ]]; then
		export DEBUG=1
		shift
	fi

	# 直接アクション指定の場合
	if [[ "${1:-}" =~ ^(gitui|code|nvim|czg|cd)$ ]]; then
		SELECTED_ACTION="$1"
		shift
	fi

	# worktree選択
	if ! select_worktree; then
		error_exit "worktreeの選択に失敗しました"
	fi

	# アクション選択（直接指定されていない場合のみ）
	if [ -z "$SELECTED_ACTION" ]; then
		if ! select_action; then
			error_exit "アクションの選択に失敗しました"
		fi
	fi

	# デバッグ情報
	if [[ "${DEBUG:-}" == "1" ]]; then
		echo "${PURPLE}[DEBUG] 最終結果:${NC}"
		echo "${PURPLE}[DEBUG] worktree_path: '$SELECTED_PATH'${NC}"
		echo "${PURPLE}[DEBUG] branch_name: '$SELECTED_BRANCH'${NC}"
		echo "${PURPLE}[DEBUG] action: '$SELECTED_ACTION'${NC}"
	fi

	# 選択結果の最終検証
	if [ -z "$SELECTED_PATH" ] || [ -z "$SELECTED_BRANCH" ] || [ -z "$SELECTED_ACTION" ]; then
		error_exit "選択に失敗しました (path='$SELECTED_PATH', branch='$SELECTED_BRANCH', action='$SELECTED_ACTION')"
	fi

	# アクション実行
	execute_action "$SELECTED_PATH" "$SELECTED_BRANCH" "$SELECTED_ACTION"

	return 0
}

# スクリプト実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
