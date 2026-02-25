#!/usr/bin/env bash
# multi-worktree bash completion

_multi_worktree_completion() {
    local cur prev words cword
    _init_completion || return

    # サブコマンドのリスト
    local subcommands="create remove list status cd exec open help"

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

        remove|status|cd|exec|open)
            # これらのサブコマンドはタスク名を補完
            if [[ $cword -eq 2 ]]; then
                # タスク名の一覧を取得（multi-worktree list の出力をパース）
                local task_names=$(multi-worktree list 2>/dev/null | awk '{print $1}')
                COMPREPLY=($(compgen -W "$task_names" -- "$cur"))
            elif [[ "$cur" == --* ]]; then
                # --group= オプション
                if [[ "$subcommand" != "exec" ]]; then
                    COMPREPLY=($(compgen -W "--group=" -- "$cur"))
                fi
            fi
            ;;

        list)
            # list は --group= オプションのみ
            if [[ "$cur" == --* ]]; then
                COMPREPLY=($(compgen -W "--group=" -- "$cur"))
            fi
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
