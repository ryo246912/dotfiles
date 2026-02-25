#!/usr/bin/env bash
# multi-worktree bash completion

_multi_worktree_completion() {
    local cur prev words cword
    _init_completion || return

    # サブコマンドのリスト
    local subcommands="create remove list status sync cd exec open help"

    # 最初の引数（サブコマンド）の補完
    if [[ $cword -eq 1 ]]; then
        COMPREPLY=($(compgen -W "$subcommands" -- "$cur"))
        return 0
    fi

    local subcommand="${words[1]}"

    # サブコマンドごとの補完
    case "$subcommand" in
        create)
            # create は --group= オプションのみ
            if [[ "$cur" == --* ]]; then
                COMPREPLY=($(compgen -W "--group=" -- "$cur"))
            fi
            ;;

        remove|status|cd|open)
            # これらのサブコマンドはタスク名を補完
            if [[ $cword -eq 2 ]]; then
                # タスク名の一覧を取得（multi-worktree list の出力をパース）
                local task_names=$(multi-worktree list 2>/dev/null | awk '{print $1}')
                COMPREPLY=($(compgen -W "$task_names" -- "$cur"))
            fi
            ;;

        sync)
            # syncコマンドはタスク名とリポジトリ名を補完
            if [[ $cword -eq 2 ]]; then
                # タスク名の一覧を取得
                local task_names=$(multi-worktree list 2>/dev/null | awk '{print $1}')
                COMPREPLY=($(compgen -W "$task_names" -- "$cur"))
            else
                # タスク名以降はリポジトリ名を補完
                # タスク名から worktree ディレクトリ内のリポジトリ名を取得
                local task_name="${words[2]}"
                if [[ -n "$task_name" ]]; then
                    # multi-worktree list の出力から該当タスクのパスを取得
                    local task_path=$(multi-worktree list 2>/dev/null | awk -v task="$task_name" '$1 == task {print $3}' | head -n 1)
                    if [[ -n "$task_path" ]] && [[ -d "$task_path" ]]; then
                        # worktree ディレクトリ内のリポジトリ名（ディレクトリ名）を取得
                        local repo_names=$(find "$task_path" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -exec basename {} \; 2>/dev/null)
                        COMPREPLY=($(compgen -W "$repo_names" -- "$cur"))
                    fi
                fi
            fi
            ;;

        exec)
            # execコマンドはタスク名を補完（--groupオプションなし）
            if [[ $cword -eq 2 ]]; then
                local task_names=$(multi-worktree list 2>/dev/null | awk '{print $1}')
                COMPREPLY=($(compgen -W "$task_names" -- "$cur"))
            fi
            ;;

        list)
            # list は引数なし
            ;;

        help)
            # help は引数なし
            ;;

        *)
            ;;
    esac

    return 0
}

# multi-worktree コマンドに対して補完関数を登録
complete -F _multi_worktree_completion multi-worktree
