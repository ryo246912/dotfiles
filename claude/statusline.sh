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
# 複数セッションが同じファイルを更新するため、各セッションは自分が最後に受け取った（古いかもしれない）値で
# 定期更新する。同じ枠（resets_at が同じ）なら使用率は増える一方なので、使用率の大きい方を新しい観測として残し、
# resets_at が後の値は新しい枠として採用する。表示もこのマージ後の値を使う。
# 青を基本に、残り 20% 未満で黄色、5% 未満で赤。
# 予測: ここまでの消費ペース（使用率 ÷ 経過時間）が続くと仮定し、リセットまで持つなら ✓、
# リセット前に尽きるなら ⚠ empty <尽きるまでの時間>（黄色、リセットまでの半分も持たないなら赤）。
# window 開始直後（経過 10% 未満）はペースが不安定なため予測しない。
# 参照: https://code.claude.com/docs/en/statusline#rate-limit-usage
now=$(date +%s)
rl_file="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/statusline-rate-limits.json"
rl_now=$(printf '%s' "$input" | jq -c '
  .rate_limits // {} | {five_hour, seven_day} | with_entries(select(.value.used_percentage != null and .value.resets_at != null))
  | if length > 0 then . else empty end
' 2>/dev/null)
rl_saved=$(jq -c 'objects' "$rl_file" 2>/dev/null)
if [ -n "$rl_now" ]; then
	# window ごとに新しい方の観測を残す。今回の payload に無い window の保存値は保持する。
	# resets_at は応答ごとに数秒ずれうるため、60 秒以上後なら新しい枠とみなす。
	rl_merged=$(jq -nc --argjson old "${rl_saved:-null}" --argjson new "$rl_now" '
    ($old // {}) as $o
    | $o + ($new | with_entries(
        $o[.key] as $s
        | if $s == null or ($s.resets_at // 0) + 60 < .value.resets_at then .
          elif ($s.resets_at // 0) > .value.resets_at + 60 or ($s.used_percentage // 0) > .value.used_percentage then .value = $s
          else . end))
  ' 2>/dev/null)
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
  # $saved は今回の値とマージ済み。リセット時刻を過ぎた枠は使わない（Claude Code も同様に window を落とす）。
  def pick($k): $saved[$k]? | select(.used_percentage != null and .resets_at != null and .resets_at > $now);
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

# モデル名（紫）と reasoning effort。effort 非対応モデル（`effort` が無い）ではモデル名のみ。
# effort は 5 段階のゲージと色で表示する（low 灰・medium 緑・high シアン・xhigh 黄・max 赤）。
# fast mode が有効なら ⚡ を付ける。`/effort` の変更はセッション中でも次の更新で反映される。
# 参照: https://code.claude.com/docs/en/model-config#adjust-effort-level
model_line=$(printf '%s' "$input" | jq -r '
  (.effort.level // null) as $lv
  | ({"low": 1, "medium": 2, "high": 3, "xhigh": 4, "max": 5}[$lv // ""]) as $n
  | ({"low": "90", "medium": "32", "high": "36", "xhigh": "33", "max": "1;31"}[$lv // ""] // "0") as $c
  | [
      (if .model.display_name != null then "\u001b[35m\(.model.display_name)\u001b[0m" else empty end),
      (if .fast_mode == true then "\u001b[33m⚡\u001b[0m" else empty end),
      (if $lv == null then empty
       elif $n != null then "\u001b[\($c)m\("▰" * $n)\("▱" * (5 - $n)) \($lv)\u001b[0m"
       else "\u001b[\($c)m\($lv)\u001b[0m" end)
    ]
  | if length > 0 then join(" ") else empty end
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

# ログイン中のアカウントを先頭にバッジで表示する（例: [account2] foo@example.com）。
# ラベルは config dir 名から決める: ~/.claude → account1、~/.claude-<name> → <name>。
# バッジの色はアカウントごとに固定（account1 青・account2 紫・work3 黄・その他 灰）。
# メールアドレスは Claude Code の global config（CLAUDE_CONFIG_DIR 指定時は <dir>/.claude.json、
# 未指定時は ~/.claude.json）の oauthAccount.emailAddress。API キー利用などで無い場合はラベルのみ。
config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
config_dir="${config_dir%/}"
config_name="${config_dir##*/}"
case "$config_name" in
.claude) account_label="account1" ;;
.claude-*) account_label="${config_name#.claude-}" ;;
*) account_label="$config_name" ;;
esac
case "$account_label" in
account1) account_color='\033[1;97;44m' ;;
account2) account_color='\033[1;97;45m' ;;
work3) account_color='\033[1;30;43m' ;;
*) account_color='\033[1;97;100m' ;;
esac
if [ -n "$CLAUDE_CONFIG_DIR" ]; then
	account_file="$config_dir/.claude.json"
else
	account_file="$HOME/.claude.json"
fi
# global config は projects の履歴などで数 MB になりうるため、毎回 parse せず、
# config dir に保存したメールアドレスを global config が更新されるまで使う。
email_cache="$config_dir/statusline-account-email"
if [ -f "$email_cache" ] && [ -f "$account_file" ] && [ "$email_cache" -nt "$account_file" ]; then
	email=$(cat "$email_cache" 2>/dev/null)
else
	email=$(jq -r '.oauthAccount.emailAddress // empty' "$account_file" 2>/dev/null)
	# 書き込めない環境（読み取り専用 mount 等）では保存しないだけで表示は続ける。
	if [ -f "$account_file" ]; then
		tmp="$email_cache.$$"
		{ printf '%s' "$email" >"$tmp" && mv -f "$tmp" "$email_cache" || rm -f "$tmp"; } 2>/dev/null
	fi
fi
account=$(printf '%b %s \033[0m' "$account_color" "$account_label")
[ -n "$email" ] && account="$account $(printf '\033[1m%s\033[0m' "$email")"

# session id（`claude --resume <id>` 用）を灰色で表示する。
session=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$session" ] && session=$(printf '\033[90m%s\033[0m' "$session")

# セッションで最初に送ったメッセージ（1 行目を 30 文字まで）とその時刻を表示し、何のセッションか分かるようにする。
# transcript の先頭から最初の人間の入力だけを読む（first で打ち切るため長いセッションでも軽い）。
# isMeta や "<" で始まるもの（slash command・hook 由来の内部メッセージ）は除外する。
# 時刻は MM/DD HH:MM で 💬 の前に置く。
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
first_msg=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
	first_msg=$(jq -nr '
    first(inputs
      | select(.type == "user" and .isMeta != true)
      | select(.message.content | type == "string" and (startswith("<") | not)))
    | (.message.content | split("\n")[0] | if length > 30 then .[0:30] + "…" else . end) as $text
    | (.timestamp // empty | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) as $t
    | "\u001b[90m\($t | strflocaltime("%m/%d %H:%M"))~\u001b[0m \u001b[33m💬 \($text)\u001b[0m"
  ' "$transcript" 2>/dev/null)
fi

# 空でない引数を " · " で連結する。
join_parts() {
	local out="" p
	for p in "$@"; do
		[ -z "$p" ] && continue
		out="${out:+$out · }$p"
	done
	printf '%s' "$out"
}

# 1 行目: アカウント・branch・モデル・最初のメッセージ / 2 行目: コンテキスト・session id・rate limit・cache
line1=$(join_parts "$account" "$branch" "$model_line" "$first_msg")
line2=$(join_parts "$ctx_line" "$session" "$limit_line" "$cache_line")
[ -n "$line1" ] && printf '%s\n' "$line1"
[ -n "$line2" ] && printf '%s\n' "$line2"
exit 0
