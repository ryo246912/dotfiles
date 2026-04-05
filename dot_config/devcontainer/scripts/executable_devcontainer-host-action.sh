#!/usr/bin/env bash

set -euo pipefail

readonly SSH_CONFIG="${HOME}/.config/ssh/config"
readonly SSH_HOST_ALIAS="${DEVCONTAINER_HOST_ALIAS:-mac-host}"
readonly CONNECT_TIMEOUT="${DEVCONTAINER_HOST_CONNECT_TIMEOUT:-2}"

log_error() {
    echo "devcontainer-host-action.sh: $*" >&2
}

show_usage() {
    cat <<'EOF'
Usage:
  devcontainer-host-action.sh notify --event <pending|stop> [--worktree <name>] [--tmux <0|1>]
EOF
}

is_safe_identifier() {
    [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]
}

resolve_tmux_flag() {
    local requested="${1:-}"

    if [[ -z "$requested" ]]; then
        if [[ -n "${TMUX:-}" ]]; then
            echo "1"
        else
            echo "0"
        fi
        return 0
    fi

    if [[ "$requested" != "0" && "$requested" != "1" ]]; then
        log_error "--tmux には 0 か 1 を指定してください"
        return 1
    fi

    echo "$requested"
}

run_notify() {
    local event=""
    local worktree="$(basename "$PWD")"
    local tmux_flag=""
    local remote_command=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --event)
                [[ $# -ge 2 ]] || {
                    log_error "--event の値が必要です"
                    return 1
                }
                event="$2"
                shift 2
                ;;
            --worktree)
                [[ $# -ge 2 ]] || {
                    log_error "--worktree の値が必要です"
                    return 1
                }
                worktree="$2"
                shift 2
                ;;
            --tmux)
                [[ $# -ge 2 ]] || {
                    log_error "--tmux の値が必要です"
                    return 1
                }
                tmux_flag="$2"
                shift 2
                ;;
            *)
                log_error "不明な引数です: $1"
                return 1
                ;;
        esac
    done

    if [[ "$event" != "pending" && "$event" != "stop" ]]; then
        log_error "--event には pending か stop を指定してください"
        return 1
    fi

    if ! is_safe_identifier "$worktree"; then
        log_error "worktree 名が不正です: $worktree"
        return 1
    fi

    tmux_flag="$(resolve_tmux_flag "$tmux_flag")"

    if [[ ! -f "$SSH_CONFIG" ]]; then
        log_error "SSH config が見つかりません: $SSH_CONFIG"
        return 1
    fi

    remote_command=$(printf 'notify --event %q --worktree %q --tmux %q' "$event" "$worktree" "$tmux_flag")

    exec ssh \
        -F "$SSH_CONFIG" \
        -o BatchMode=yes \
        -o ConnectTimeout="$CONNECT_TIMEOUT" \
        -o StrictHostKeyChecking=no \
        "$SSH_HOST_ALIAS" \
        "$remote_command"
}

main() {
    local action="${1:-}"

    case "$action" in
        notify)
            shift
            run_notify "$@"
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            show_usage
            return 1
            ;;
    esac
}

main "$@"
