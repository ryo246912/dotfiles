# cSpell:disable
for file in $XDG_CONFIG_HOME/zsh/lazy/*.zsh; do
  source "$file"
done

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
