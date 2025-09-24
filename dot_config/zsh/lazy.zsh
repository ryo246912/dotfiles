# cSpell:disable
for file in $XDG_CONFIG_HOME/zsh/lazy/*.zsh; do
  source "$file"
done

# 仮検討ファイルを読み込み
if [[ -d "$HOME/.local/share/chezmoi/dot_config/zsh/temp" ]]; then
  # (N)フラグを使用して、マッチするファイルがない場合でもエラーを出さないように
  for file in $HOME/.local/share/chezmoi/dot_config/zsh/temp/*.zsh(N); do
    source "$file"
  done
fi

# バックグラウンドでzcompile
# [-s:sizeが0以上][-nt:タイムスタンプが新しいか]
{
  files=(
    $HOME/.zprofile{,.secret}
    $HOME/.zshrc{,.secret}
    $HOME/.zcompdump
  )
  for file in "${files[@]}" ; do
    if [[ -s "$file" && (! -s "${file}.zwc" || "$file" -nt "${file}.zwc") ]]; then
      zcompile "$file"
    fi
  done
} &!
