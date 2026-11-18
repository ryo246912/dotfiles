# Codex の作業ルール

## シェルコマンド

- 権限チェッカーに渡すコマンドは Bash 互換の構文で書き、`${(f)...}` などの zsh 専用の展開は使わない。サブエージェントにシェル操作を任せるときも、このルールを依頼に含める。
- `git diff --name-only` の結果を `lessons_query.py --paths` などに渡すときは、`git diff --name-only -z` と `xargs -0` を使うか、Bash で NUL 区切りの出力を配列に読み込んで `"${files[@]}"` で渡す。実行シェルが zsh の場合、Bash の配列処理は `bash -c` 内で実行する。
