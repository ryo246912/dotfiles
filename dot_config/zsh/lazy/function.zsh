cb() {
  if command -v pbcopy &> /dev/null; then
    command pbcopy
  elif command -v clip.exe &> /dev/null; then
    command clip.exe
  fi
}

open() {
  if command -v open &> /dev/null; then
    command open
  elif command -v xdg-open &> /dev/null; then
    command xdg-open
  fi
}

ssh() {
  # tmux起動時
  if [[ -n $(printenv TMUX) ]] ; then
    # locale対応
    export LC_CTYPE=en_US.UTF-8
    # 接続先ホスト名に応じて背景色切り替え
    if [[ `echo "$1" | grep 'audit'` ]] ; then
      tmux set -p window-active-style 'bg=#400000'
      tmux set -p window-style 'bg=#400000'
    else
      tmux set -p window-active-style 'bg=#002800'
      tmux set -p window-style 'bg=#002800'
    fi

    command ssh $@
    # 色設定を戻す
    tmux set -p window-style 'bg=#303030'
    tmux set -p window-active-style 'bg=#000000'
  else
    command ssh $@
  fi
}

_zsh-history-backup() {
  local backup_dir="$HOME/.local/state/zsh"
  while sleep $((60 * 15)) ; do
    if [[ $(wc -l "$backup_dir/.zsh_history" | awk '{print $1}') -gt 1000 ]] ; then
      cp -f "$backup_dir/.zsh_history" "$backup_dir/zsh_history_backup_$(date '+%y%m')$(printf '%02d' $(( $(date '+%d') / 10 * 10 )))"
    else
      osascript -e 'display notification "Backup Error!" with title "zsh"'
    fi
  done
}

zsh-history-backup() {
  # ロックディレクトリを作成して排他制御
  local lock_file="$HOME/.zsh_history_backup.lock"
  local pid_file="$HOME/.zsh_history_backup_process.pid"
  local cmd="_zsh-history-backup"

  if ! mkdir "$lock_file" 2>/dev/null; then
    return 0
  fi
  # ターミナル終了時にロックを解除するトラップを設定
  trap "rmdir \"$lock_file\" 2>/dev/null" EXIT

  # すでにプロセスが実行中かチェック
  if [[ -f "$pid_file" ]]; then
    local existing_pid=$(cat "$pid_file")
    if ps -p "$existing_pid" > /dev/null 2>&1; then
      return 0
    else
      echo "pidファイルはあるがプロセスがないので削除"
      rm -f "$pid_file"
    fi
  fi

  # バックアップコマンドをバックグラウンド実行 & PID を保存
  $cmd &
  echo $! > "$pid_file"
  echo "バックアッププロセスを開始しました (PID: $(cat "$pid_file"))"
  rmdir "$lock_file" 2>/dev/null
}

zsh-startuptime() {
  local time_rc
  local total_msec=0
  local msec
  for i in $(seq 1 10); do
    msec=$((TIMEFMT='%mE'; time zsh -i -c exit) 2>/dev/stdout >/dev/null | tr -d "ms")
    echo "${(l:2:)i}: ${msec} [ms]"
    total_msec=$(( $total_msec + $msec ))
  done
  time_rc=$(( ${total_msec} / 10 ))
  local time_norc
  time_norc=$((TIMEFMT="%mE"; time zsh -df -i -c "autoload -Uz compinit && compinit -C; exit") &> /dev/stdout)
  echo "my zshrc: ${time_rc}ms\ndefault zsh: ${time_norc}\n"
}

zsh-profiler() {
  ZSHRC_PROFILE=1 zsh -i -c zprof
}

# historyの定期バックアップを起動
zsh-history-backup
