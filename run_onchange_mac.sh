#!/bin/bash
[ "$(uname)" != "Darwin" ] && exit

# 移動対象のファイル
# {{ include "dot_config/vscode/keybindings_mac.json" | sha256sum }}
# {{ include "dot_config/vscode/settings.json" | sha256sum }}

# 配列でキーと値を管理
# 保存元ファイルパス 保存先ディレクトリ
file_mappings=(
  "{{ .chezmoi.sourceDir }}/dot_config/vscode/keybindings_mac.json" "{{ .chezmoi.homeDir }}/Library/Application Support/Code/User/keybindings.json"
  "{{ .chezmoi.sourceDir }}/dot_config/vscode/settings.json" "{{ .chezmoi.homeDir }}/Library/Application Support/Code/User/settings.json"
)

# 配列をループで処理
for ((i=0; i<${#file_mappings[@]}; i+=2)); do
  source_file="${file_mappings[i]}"
  dest_dir="${file_mappings[i+1]}"

  # コピー元とコピー先の更新日時を比較
  if [ -f "$dest_dir" ] && [ "$source_file" -ot "$dest_dir" ]; then
    continue
  fi

  while true; do
    echo "$source_file をコピーしますか? (y/n/d)"
    read -r answer

    case "$answer" in
      y|Y)
        cp "$source_file" "$dest_dir"
        break
        ;;
      n|N)
        break
        ;;
      d|D)
        delta "$source_file" "$dest_dir"
        ;;
      *)
        ;;
    esac
  done
done
