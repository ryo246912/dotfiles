#!/usr/bin/env bash
# Claude Code subagentStatusLine。
# agent panel の各 subagent 行を「name · description · model effort · tokens」で表示する。
# 既定の行（name · description · token count）に、subagent ごとの model と effort を足したもの。
# effort は定義 frontmatter または呼び出し時に指定された値で、未指定なら表示しない（セッションの effort を引き継ぐ）。
# 参照: https://code.claude.com/docs/en/statusline#subagent-status-lines

command -v jq >/dev/null 2>&1 || exit 0

jq -c '
  def kfmt: if . >= 1000000 then "\((. / 100000 | round) / 10)M"
            elif . >= 1000 then "\((. / 1000) | round)k" else tostring end;
  def ecolor: {"low": "90", "medium": "32", "high": "36", "xhigh": "33", "max": "1;31"}[tostring] // "0";
  .tasks[]?
  | {
      id,
      content: ([
        (.name // .agentType // empty),
        (.label // .description // empty),
        ([
           (.model // empty | sub("^claude-"; "") | "\u001b[35m\(.)\u001b[0m"),
           (.effort // empty | "\u001b[\(ecolor)m\(if type == "number" then "\(kfmt) tok" else . end)\u001b[0m")
         ] | if length > 0 then join(" ") else empty end),
        (.tokenCount // empty | "\(kfmt) tokens")
      ] | join(" · "))
    }
' 2>/dev/null
exit 0
