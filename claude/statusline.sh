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
# rate limit はアカウント単位なので、受け取った値を config dir ごとに保存し、
# prompt を送る前（rate_limits がまだ無い間）はリセット前の保存値を表示する。
# 青を基本に、残り 20% 未満で黄色、5% 未満で赤。
# 予測: ここまでの消費ペース（使用率 ÷ 経過時間）が続くと仮定し、リセットまで持つなら ✓、
# リセット前に尽きるなら ⚠ empty <尽きるまでの時間>（黄色、リセットまでの半分も持たないなら赤）。
# window 開始直後（経過 10% 未満）はペースが不安定なため予測しない。
# 参照: https://code.claude.com/docs/en/statusline#rate-limit-usage
now=$(date +%s)
rl_file="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/statusline-rate-limits.json"
rl_now=$(printf '%s' "$input" | jq -c '
  .rate_limits // {} | {five_hour, seven_day} | with_entries(select(.value.used_percentage != null))
  | if length > 0 then . else empty end
' 2>/dev/null)
rl_saved=$(jq -c 'objects' "$rl_file" 2>/dev/null)
if [ -n "$rl_now" ]; then
	# 今回の payload に無い window の保存値は保持する（既存の保存値とマージ）。
	rl_merged=$(jq -nc --argjson old "${rl_saved:-null}" --argjson new "$rl_now" '($old // {}) + $new' 2>/dev/null)
	rl_merged=${rl_merged:-$rl_now}
	if [ "$rl_merged" != "$rl_saved" ]; then
		# 書き込めない環境（読み取り専用 mount 等）では保存しないだけで表示は続ける。
		tmp="$rl_file.$$"
		{ printf '%s' "$rl_merged" >"$tmp" && mv -f "$tmp" "$rl_file" || rm -f "$tmp"; } 2>/dev/null
	fi
	rl_saved="$rl_merged"
fi
limit_line=$(printf '%s' "$input" | jq -r --argjson now "$now" --argjson saved "${rl_saved:-null}" '
  def dur: if . >= 86400 then "\((. / 86400) | floor)d\(((. % 86400) / 3600) | floor)h"
           elif . >= 3600 then "\((. / 3600) | floor)h\(((. % 3600) / 60) | floor)m"
           else "\((. / 60) | floor)m" end;
  # 保存値はリセット時刻を過ぎていたら使わない（Claude Code も同様に window を落とす）。
  def pick($k):
    if .rate_limits[$k].used_percentage? != null then .rate_limits[$k]
    else $saved[$k]? | select(.resets_at != null and .resets_at > $now) end;
  def seg($label; $win):
    if . == null or .used_percentage == null then empty else
      ([[100 - .used_percentage, 0] | max, 100] | min) as $left
      | (if $left < 5 then "\u001b[31m" elif $left < 20 then "\u001b[33m" else "\u001b[34m" end) as $color
      | ((($left / 100 * 6) | ceil) as $n | ("█" * $n) + ("░" * (6 - $n))) as $bar
      | (if .resets_at != null and .resets_at > $now then .resets_at - $now else null end) as $remain
      | [
          "\($label) \($bar) \($left | round)% left",
          (if $remain != null then "reset \($remain | dur)" else empty end),
          (if $remain != null then
             ([[$win - $remain, 0] | max, $win] | min) as $elapsed
             | if $elapsed < $win * 0.1 then empty
               elif .used_percentage <= 0 then "✓"
               else ($left / (.used_percentage / $elapsed)) as $tte
                 | if $tte >= $remain then "✓"
                   else "\(if $tte < $remain / 2 then "\u001b[31m" else "\u001b[33m" end)⚠ empty \($tte | dur)\($color)"
                   end
               end
           else empty end)
        ]
      | "\($color)\(join(" "))\u001b[0m"
    end;
  [(pick("five_hour") | seg("5h"; 18000)), (pick("seven_day") | seg("week"; 604800))]
  | join(" · ")
' 2>/dev/null)

# モデル名と reasoning effort（例: Opus 5.5 xhigh）。effort 非対応モデルではモデル名のみ。
model_line=$(printf '%s' "$input" | jq -r '
  [.model.display_name // empty, .effort.level // empty]
  | if length > 0 then "\u001b[35m\(join(" "))\u001b[0m" else empty end
' 2>/dev/null)

# コンテキストウィンドウの残り。最初の API 応答前・/compact 直後は null のため灰色で waiting を表示する。
# 残り 20% 未満で黄色、10% 未満で赤（auto-compact が近い）。
# 参照: https://code.claude.com/docs/en/statusline#context-window-fields
ctx_line=$(printf '%s' "$input" | jq -r '
  .context_window
  | if . == null or .used_percentage == null then "\u001b[90mctx – waiting\u001b[0m" else
      def kfmt: if . >= 1000000 then "\((. / 100000 | round) / 10)M"
                elif . >= 1000 then "\((. / 1000) | round)k" else tostring end;
      ([[100 - .used_percentage, 0] | max, 100] | min) as $left
      | (if $left < 10 then "\u001b[31m" elif $left < 20 then "\u001b[33m" else "\u001b[32m" end) as $color
      | ((($left / 100 * 6) | ceil) as $n | ("█" * $n) + ("░" * (6 - $n))) as $bar
      | [
          "ctx \($bar) \($left | round)% left",
          (if .context_window_size != null then
             "\((.used_percentage / 100 * .context_window_size) | kfmt)/\(.context_window_size | kfmt)"
           else empty end)
        ]
      | "\($color)\(join(" "))\u001b[0m"
    end
' 2>/dev/null)

# 作業ディレクトリの git branch（detached HEAD なら短縮 SHA）を左に表示する。
# statusline は頻繁に実行されるため、--no-optional-locks で index.lock を取らない。
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null)
branch=""
if [ -n "$cwd" ]; then
	branch=$(git --no-optional-locks -C "$cwd" branch --show-current 2>/dev/null)
	[ -z "$branch" ] && branch=$(git --no-optional-locks -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi
[ -n "$branch" ] && branch=$(printf '\033[36m%s\033[0m' "$branch")

# 空でない引数を " · " で連結する。
join_parts() {
	local out="" p
	for p in "$@"; do
		[ -z "$p" ] && continue
		out="${out:+$out · }$p"
	done
	printf '%s' "$out"
}

# 1 行目: branch・モデル・コンテキスト / 2 行目: rate limit・cache
line1=$(join_parts "$branch" "$model_line" "$ctx_line")
line2=$(join_parts "$limit_line" "$cache_line")
[ -n "$line1" ] && printf '%s\n' "$line1"
[ -n "$line2" ] && printf '%s\n' "$line2"
exit 0
