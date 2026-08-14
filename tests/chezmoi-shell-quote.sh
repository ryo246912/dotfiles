#!/bin/bash
set -euo pipefail

marker=$(mktemp)
rm -f "$marker"
trap 'rm -f "$marker"' EXIT
expected="/tmp/\$HOME/\$(touch $marker)/\`touch $marker\`/with space/with'quote"
rendered=$(
  printf 'source_dir={{ %s | shellQuote }}\n' "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$expected")" |
    chezmoi execute-template
)
actual=$(bash -c "$rendered"$'\n''printf %s "$source_dir"')

test "$actual" = "$expected"
test ! -e "$marker"
