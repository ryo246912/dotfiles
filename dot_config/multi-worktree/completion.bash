#!/usr/bin/env bash
# multi-worktree bash completion

_multi_worktree_completion() {
    local cur prev words cword
    _init_completion || return

    # サブコマンドのリスト
    local subcommands="create recreate remove list status sync cd dev exec open help"

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

        recreate)
            if [[ $cword -eq 2 ]]; then
                local task_names=$(multi-worktree list 2>/dev/null | awk '{print $1}')
                COMPREPLY=($(compgen -W "$task_names" -- "$cur"))
            elif [[ "$cur" == --* ]]; then
                COMPREPLY=($(compgen -W "--group=" -- "$cur"))
            fi
            ;;

        remove)
            # removeサブコマンドはタスク名と--forceを補完
            if [[ $cword -eq 2 ]]; then
                # タスク名の一覧を取得（multi-worktree list の出力をパース）
                local task_names=$(multi-worktree list 2>/dev/null | awk '{print $1}')
                COMPREPLY=($(compgen -W "$task_names" -- "$cur"))
            elif [[ $cword -eq 3 ]]; then
                COMPREPLY=($(compgen -W "--force" -- "$cur"))
            fi
            ;;

        status)
            if [[ $cword -eq 2 ]]; then
                local task_names=$(multi-worktree list 2>/dev/null | awk '{print $1}')
                COMPREPLY=($(compgen -W "main $task_names" -- "$cur"))
            elif [[ $cword -eq 3 && "${words[2]}" == "main" ]]; then
                COMPREPLY=($(compgen -W "--group=" -- "$cur"))
            fi
            ;;

        cd)
            if [[ $cword -eq 2 ]]; then
                local task_names=$(multi-worktree list 2>/dev/null | awk '{print $1}')
                COMPREPLY=($(compgen -W "$task_names" -- "$cur"))
            elif [[ $cword -eq 3 ]]; then
                local task_name="${words[2]}"
                local task_path=$(multi-worktree list 2>/dev/null | awk -F $'\t' -v task="$task_name" '$1 == task {print $3}' | head -n 1)
                if [[ -n "$task_path" ]] && [[ -d "$task_path" ]]; then
                    local repo_names=$(find "$task_path" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -exec basename {} \; 2>/dev/null)
                    COMPREPLY=($(compgen -W "$repo_names" -- "$cur"))
                fi
            fi
            ;;

        open)
            if [[ $cword -eq 2 ]]; then
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
                # タスク名以降は --all オプションとリポジトリ名を補完
                local task_name="${words[2]}"
                if [[ "$cur" == --* ]]; then
                    COMPREPLY=($(compgen -W "--all" -- "$cur"))
                elif [[ -n "$task_name" ]]; then
                    local task_path=$(multi-worktree list 2>/dev/null | awk -F $'\t' -v task="$task_name" '$1 == task {print $3}' | head -n 1)
                    if [[ -n "$task_path" ]] && [[ -d "$task_path" ]]; then
                        local repo_names=$(find "$task_path" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -exec basename {} \; 2>/dev/null)
                        COMPREPLY=($(compgen -W "$repo_names" -- "$cur"))
                    fi
                fi
            fi
            ;;

        dev)
            if [[ $cword -eq 2 ]]; then
                local task_names=$(multi-worktree list 2>/dev/null | awk '{print $1}')
                COMPREPLY=($(compgen -W "$task_names" -- "$cur"))
            elif [[ $cword -ge 3 ]]; then
                local sandbox_mode=false word
                for word in "${words[@]}"; do
                    if [[ "$word" == "--sbx" || "$word" == --sbx=* ]]; then
                        sandbox_mode=true
                        break
                    fi
                done

                if [[ "$sandbox_mode" == true ]]; then
                    local sandbox_agents="claude codex copilot docker-agent gemini kiro opencode shell"
                    if [[ "$prev" == "--sbx" ]]; then
                        COMPREPLY=($(compgen -W "$sandbox_agents" -- "$cur"))
                    elif [[ "$prev" == "--cli" ]]; then
                        COMPREPLY=($(compgen -W "sbx docker" -- "$cur"))
                    elif [[ "$cur" == --sbx=* ]]; then
                        COMPREPLY=($(compgen -W "$sandbox_agents" -- "${cur#--sbx=}"))
                        COMPREPLY=("${COMPREPLY[@]/#/--sbx=}")
                    elif [[ "$cur" == --cli=* ]]; then
                        COMPREPLY=($(compgen -W "sbx docker" -- "${cur#--cli=}"))
                        COMPREPLY=("${COMPREPLY[@]/#/--cli=}")
                    elif [[ "$cur" == --* ]]; then
                        COMPREPLY=($(compgen -W "--name --name= --cli --cli= --" -- "$cur"))
                    fi
                else
                    # [dev_commands] セクションからコマンド名を補完
                    local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/multi-worktree/config.toml"
                    if [[ -f "$config_file" ]]; then
                        local dev_cmd_names
                        dev_cmd_names=$(awk '
                            /^\[dev_commands\]/ { in_section=1; next }
                            /^\[/ { in_section=0 }
                            in_section && /^[[:space:]]*[^[:space:]=]+[[:space:]]*=/ {
                                match($0, /^[[:space:]]*([^[:space:]=]+)/, arr)
                                print arr[1]
                            }
                        ' "$config_file")
                        COMPREPLY=($(compgen -W "$dev_cmd_names" -- "$cur"))
                    fi
                fi
            fi
            ;;

        exec)
            # execコマンドはタスク名・リポジトリ名を補完
            if [[ $cword -eq 2 ]]; then
                local task_names=$(multi-worktree list 2>/dev/null | awk '{print $1}')
                COMPREPLY=($(compgen -W "$task_names" -- "$cur"))
            elif [[ $cword -eq 3 ]]; then
                local task_name="${words[2]}"
                local task_path=$(multi-worktree list 2>/dev/null | awk -F $'\t' -v task="$task_name" '$1 == task {print $3}' | head -n 1)
                if [[ -n "$task_path" ]] && [[ -d "$task_path" ]]; then
                    local repo_names=$(find "$task_path" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -exec basename {} \; 2>/dev/null)
                    COMPREPLY=($(compgen -W "$repo_names" -- "$cur"))
                fi
            elif [[ "${words[$cword-1]}" != "--" ]] && ! printf '%s\n' "${words[@]}" | grep -q '^--$'; then
                # -- が未入力なら -- を補完
                COMPREPLY=($(compgen -W "--" -- "$cur"))
            else
                # -- 以降はファイル補完
                COMPREPLY=($(compgen -f -- "$cur"))
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
