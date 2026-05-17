#!/usr/bin/env bash
# multi-worktree bash completion

_multi_worktree_task_names() {
    multi-worktree list 2>/dev/null | awk '{print $1}'
}

_multi_worktree_task_path() {
    local task_name="$1"
    multi-worktree list 2>/dev/null | awk -F $'\t' -v task="$task_name" '$1 == task {print $3}' | head -n 1
}

_multi_worktree_repo_names() {
    local task_name="$1"
    local task_path
    task_path="$(_multi_worktree_task_path "$task_name")"
    if [[ -n "$task_path" ]] && [[ -d "$task_path" ]]; then
        find "$task_path" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -exec basename {} \; 2>/dev/null
    fi
}

_multi_worktree_main_repo_names() {
    local task_path
    task_path="$(multi-worktree list 2>/dev/null | awk -F $'\t' 'NR==1 {print $3}')"
    if [[ -n "$task_path" ]] && [[ -d "$task_path" ]]; then
        find "$task_path" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -exec basename {} \; 2>/dev/null
    fi
}

_multi_worktree_completion() {
    local cur prev words cword
    _init_completion || return

    local subcommands="create recreate remove list status sync cd dev exec open help completion"

    if [[ $cword -eq 1 ]]; then
        COMPREPLY=($(compgen -W "$subcommands" -- "$cur"))
        return 0
    fi

    local subcommand="${words[1]}"

    case "$subcommand" in
        create)
            if [[ "$cur" == --* ]]; then
                COMPREPLY=($(compgen -W "--group= --from= --branch= --default-branch" -- "$cur"))
            fi
            ;;

        recreate)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=($(compgen -W "$(_multi_worktree_task_names)" -- "$cur"))
            elif [[ "$cur" == --* ]]; then
                COMPREPLY=($(compgen -W "--group= --from= --branch= --default-branch" -- "$cur"))
            fi
            ;;

        remove)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=($(compgen -W "$(_multi_worktree_task_names)" -- "$cur"))
            elif [[ "$cur" == --* ]]; then
                COMPREPLY=($(compgen -W "--force" -- "$cur"))
            fi
            ;;

        status)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=($(compgen -W "main $(_multi_worktree_task_names)" -- "$cur"))
            elif [[ ${words[2]} == "main" && "$cur" == --* ]]; then
                COMPREPLY=($(compgen -W "--group=" -- "$cur"))
            fi
            ;;

        sync)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=($(compgen -W "$(_multi_worktree_task_names)" -- "$cur"))
            else
                local task_name="${words[2]}"
                if [[ "$cur" == --* ]]; then
                    COMPREPLY=($(compgen -W "--all" -- "$cur"))
                else
                    COMPREPLY=($(compgen -W "$(_multi_worktree_repo_names "$task_name")" -- "$cur"))
                fi
            fi
            ;;

        cd|open|dev)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=($(compgen -W "$(_multi_worktree_task_names)" -- "$cur"))
            elif [[ "$subcommand" == "cd" && $cword -eq 3 ]]; then
                COMPREPLY=($(compgen -W "$(_multi_worktree_repo_names "${words[2]}")" -- "$cur"))
            fi
            ;;

        exec)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=($(compgen -W "main $(_multi_worktree_task_names)" -- "$cur"))
            elif [[ ${words[2]} == "main" ]]; then
                if [[ "$cur" == --* ]]; then
                    COMPREPLY=($(compgen -W "--group=" -- "$cur"))
                elif [[ $cword -le 4 ]]; then
                    COMPREPLY=($(compgen -W "$(_multi_worktree_main_repo_names)" -- "$cur"))
                fi
            elif [[ $cword -eq 3 ]]; then
                COMPREPLY=($(compgen -W "$(_multi_worktree_repo_names "${words[2]}")" -- "$cur"))
            fi
            ;;

        completion)
            if [[ $cword -eq 2 ]]; then
                COMPREPLY=($(compgen -W "bash zsh fish powershell" -- "$cur"))
            fi
            ;;
    esac

    return 0
}

complete -F _multi_worktree_completion multi-worktree
