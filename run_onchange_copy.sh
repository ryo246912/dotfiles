#!/bin/bash

# 移動対象のファイル
# {{ include "dot_config/commitizen/dot_commitlintrc.js" | sha256sum }}

# 配列でキーと値を管理
# コマンド 保存元ファイルパス 保存先ディレクトリ
file_mappings=(
  "commitizen" "{{ .chezmoi.sourceDir }}/dot_config/commitizen/dot_commitlintrc.js" "{{ .chezmoi.homeDir }}/.commitlintrc.js"
)

# 配列をループで処理
for ((i=0; i<${#file_mappings[@]}; i+=3)); do
  command="${file_mappings[i]}"
  source_file="${file_mappings[i+1]}"
  dest_dir="${file_mappings[i+2]}"

  # コマンドのPATHが通っていない場合はskip
  if ! command -v "$command" &> /dev/null; then
    continue
  fi
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
