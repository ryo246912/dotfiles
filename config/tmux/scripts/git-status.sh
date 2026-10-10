#!/bin/sh
# tmuxのpane-border-format用: 指定ディレクトリのgit statusを短く表示する
# usage: git-status.sh <path>

cd "$1" 2>/dev/null || exit 0

# HEADからの追加/削除行数(staged + unstaged)
stats=$(git --no-optional-locks diff HEAD --numstat 2>/dev/null | awk '{ a += $1; d += $2 } END { print a + 0, d + 0 }')

git --no-optional-locks status --porcelain=v2 --branch 2>/dev/null | awk -v stats="$stats" '
  /^# branch.head / { head = $3 }
  /^# branch.oid /  { oid = substr($3, 1, 7) }
  /^# branch.ab /   { ahead = substr($3, 2); behind = substr($4, 2) }
  /^[12] / {
    x = substr($2, 1, 1); y = substr($2, 2, 1)
    if (x != ".") staged++
    if (y != ".") unstaged++
  }
  /^u / { conflict++ }
  /^\? / { untracked++ }
  END {
    if (head == "") exit
    if (head == "(detached)") head = oid
    split(stats, s, " ")
    out = "#[fg=#000000,bg=#ffff00] " head
    if (ahead > 0)     out = out " ↑" ahead
    if (behind > 0)    out = out " ↓" behind
    if (staged > 0)    out = out " +" staged
    if (unstaged > 0)  out = out " !" unstaged
    if (untracked > 0) out = out " ?" untracked
    if (conflict > 0)  out = out " =" conflict
    if (s[1] > 0 || s[2] > 0) out = out " (+" s[1] " -" s[2] ")"
    if (staged + unstaged + untracked + conflict == 0) out = out " ✓"
    print out " "
  }
'
