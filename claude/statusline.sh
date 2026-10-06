#!/usr/bin/env bash
# Claude Code statusLine。
# prompt cache の残り時間・ヒット率などを表示するキャッシュ・セグメント。
# 参照: https://code.claude.com/docs/en/statusline#prompt-cache-fields

input=$(cat)

command -v jq >/dev/null 2>&1 || exit 0

# prompt_cache が現れるまで（最初の API 応答前・v2.1.251 未満）は何も表示しない。
# 自分のバージョンに存在しないフィールドは空文字となり、表示をスキップする。
cache_line=$(printf '%s' "$input" | jq -r --argjson now "$(date +%s)" '
  .prompt_cache // empty
  | . as $c
  | def kfmt: if . >= 1000 then "\((. / 1000) | round)k" else tostring end;
    def mins: if . >= 60 then "\((. / 60) | floor)m" else "\(.)s" end;
    ({"5m": 300, "1h": 3600}[$c.ttl // ""]) as $ttl_sec
  | (if $c.expires_at != null then $c.expires_at - $now else null end) as $left
  | if ($c.warm == true) and ($left == null or $left > 0) then
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
' 2>/dev/null)

[ -n "$cache_line" ] && printf '%s\n' "$cache_line"
exit 0
