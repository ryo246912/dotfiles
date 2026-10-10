#!/usr/bin/env bash
# Claude Code statusLine。
# prompt cache の残り時間・ヒット率などを表示するキャッシュ・セグメント。
# 参照: https://code.claude.com/docs/en/statusline#prompt-cache-fields

input=$(cat)

command -v jq >/dev/null 2>&1 || exit 0

# prompt_cache が現れるまで（最初の API 応答前・v2.1.251 未満）は灰色で waiting を表示する。
# 自分のバージョンに存在しないフィールドは空文字となり、表示をスキップする。
cache_line=$(printf '%s' "$input" | jq -r --argjson now "$(date +%s)" '
  if .prompt_cache == null then "\u001b[90mcache – waiting\u001b[0m" else
  .prompt_cache
  | . as $c
  | def kfmt: if . >= 1000 then "\((. / 1000) | round)k" else tostring end;
    def mins: if . >= 60 then "\((. / 60) | floor)m" else "\(.)s" end;
    ({"5m": 300, "1h": 3600}[$c.ttl // ""]) as $ttl_sec
  | (if $c.expires_at != null then $c.expires_at - $now else null end) as $left
  | if $c.caching_observed == false then
      # cache token がまだ一度も報告されていない（caching 無効、または provider が報告しない）。
      "\u001b[90mcache – not observed\u001b[0m"
    elif ($c.warm == true) and ($left == null or $left > 0) then
      # warm: 緑。残り 20% 未満で黄色。
      (if $ttl_sec != null and $left != null then ([$left / $ttl_sec, 1] | min) else null end) as $frac
      | (if $frac != null and $frac < 0.2 then "\u001b[33m" else "\u001b[32m" end) as $color
      | [
          "cache ●",
          ($c.ttl // empty),
          (if $frac != null then
             ((($frac * 6) | ceil) as $n | ("█" * $n) + ("░" * (6 - $n)))
           else empty end),
          (if $left != null then "\($left | mins) left" else empty end)
        ] as $head
      | [
          ($head | join(" ")),
          (if $c.hit_ratio != null then "hit \(($c.hit_ratio * 100) | round)%" else empty end),
          (if $c.misses != null then "misses \($c.misses)" else empty end)
        ]
      | "\($color)\(join(" · "))\u001b[0m"
    elif ($c | has("warm")) then
      # cold: 赤。次のメッセージで再キャッシュされるトークン数と、ミス原因（あれば）を表示。
      [
        "cache ○ cold",
        (if $c.recache_tokens_if_cold != null then
           "next message re-caches \($c.recache_tokens_if_cold | kfmt) tokens"
         else empty end),
        (if ($c.last_miss_cause.causes // []) | length > 0 then
           "last miss: \($c.last_miss_cause.causes | join(", "))"
         else empty end)
      ]
      | "\u001b[31m\(join(" · "))\u001b[0m"
    else empty end
  end
' 2>/dev/null)

# rate limit（5h / weekly）の残り割合とリセットまでの時間を表示する。
# claude.ai Pro/Max のみ、最初の API 応答後に現れる。window ごとに独立して欠けうるため、無い window はスキップする。
# 残り 20% 未満で黄色、5% 未満で赤。
# 参照: https://code.claude.com/docs/en/statusline#rate-limit-usage
limit_line=$(printf '%s' "$input" | jq -r --argjson now "$(date +%s)" '
  def dur: if . >= 86400 then "\((. / 86400) | floor)d\(((. % 86400) / 3600) | floor)h"
           elif . >= 3600 then "\((. / 3600) | floor)h\(((. % 3600) / 60) | floor)m"
           else "\((. / 60) | floor)m" end;
  def seg($label):
    if . == null or .used_percentage == null then empty else
      ([[100 - .used_percentage, 0] | max, 100] | min) as $left
      | (if $left < 5 then "\u001b[31m" elif $left < 20 then "\u001b[33m" else "\u001b[32m" end) as $color
      | ((($left / 100 * 6) | ceil) as $n | ("█" * $n) + ("░" * (6 - $n))) as $bar
      | [
          "\($label) \($bar) \($left | round)% left",
          (if .resets_at != null and .resets_at > $now then "reset \((.resets_at - $now) | dur)" else empty end)
        ]
      | "\($color)\(join(" "))\u001b[0m"
    end;
  [(.rate_limits.five_hour | seg("5h")), (.rate_limits.seven_day | seg("week"))]
  | join(" · ")
' 2>/dev/null)

# 作業ディレクトリの git branch（detached HEAD なら短縮 SHA）を左に表示する。
# statusline は頻繁に実行されるため、--no-optional-locks で index.lock を取らない。
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null)
branch=""
if [ -n "$cwd" ]; then
	branch=$(git --no-optional-locks -C "$cwd" branch --show-current 2>/dev/null)
	[ -z "$branch" ] && branch=$(git --no-optional-locks -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

line=""
[ -n "$branch" ] && line=$(printf '\033[36m%s\033[0m' "$branch")
[ -n "$line" ] && [ -n "$cache_line" ] && line="$line · "
line="$line$cache_line"
[ -n "$line" ] && [ -n "$limit_line" ] && line="$line · "
line="$line$limit_line"
[ -n "$line" ] && printf '%s\n' "$line"
exit 0
