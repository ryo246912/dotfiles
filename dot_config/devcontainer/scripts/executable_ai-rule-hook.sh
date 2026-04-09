#!/bin/bash
# ai-rule-hook.sh
#
# 概要:
#   AI ツール（Claude / Codex / Gemini / Copilot）のセッション終了やコンテキスト圧縮前に
#   hook として呼び出され、会話履歴を分析して以下の候補を提案するスクリプト。
#   - ルール追記候補: CLAUDE.md / agent.md 等への追記
#   - スキル化候補: 定型ワークフローを /skill-name として呼び出せるスキルへ昇格
#
# 動作フロー:
#   1. hook の JSON を stdin から受け取る（session_id / transcript_path / cwd など）
#   2. 無限再帰チェック: AI_RULE_HOOK_RUNNING=1 なら即 exit（ループ防止）
#   3. イベントと条件を判定し、実行不要なら skip
#      - claude / gemini / copilot: session_end / pre_compact で実行
#      - codex: /clear 等のコマンドか十分な行数増加で実行
#   4. 会話履歴（末尾 24KB）・ルールファイル（末尾 12KB）・既存スキル一覧を読み込む
#   5. ai-rule-hook.md の指示文 + メタデータ + ルール抜粋 + スキル一覧 + 履歴抜粋でプロンプトを組み立てる
#   6. 対象 AI ツールにプロンプトを投げて候補を生成し suggestion.md に保存する
#      - claude / copilot: claude -p
#      - codex:            codex exec
#      - gemini:           gemini
#
# 注意:
#   - ルール・スキルを自動で書き換えることはしない。suggestion.md を確認して手動転記する。
#   - ドライラン: AI_RULE_HOOK_DRY_RUN=1 でデバッグ用 JSON を出力（AI は呼ばない）
#   - ステート保存先: ${XDG_STATE_HOME:-~/.local/state}/ai-rule-hook/<tool>/<session>/
#
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_NAME SCRIPT_DIR
readonly STATE_ROOT="${AI_RULE_HOOK_STATE_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/ai-rule-hook}"
readonly PROMPT_TEMPLATE="${AI_RULE_HOOK_PROMPT_TEMPLATE:-$SCRIPT_DIR/ai-rule-hook.md}"
readonly MAX_RULE_BYTES="${AI_RULE_HOOK_MAX_RULE_BYTES:-12000}"
readonly MAX_TRANSCRIPT_BYTES="${AI_RULE_HOOK_MAX_TRANSCRIPT_BYTES:-24000}"
readonly CODEX_STOP_MIN_LINES="${AI_RULE_HOOK_CODEX_STOP_MIN_LINES:-80}"
readonly CODEX_STOP_LINE_DELTA="${AI_RULE_HOOK_CODEX_STOP_LINE_DELTA:-40}"

log() {
	printf '[%s] %s\n' "$SCRIPT_NAME" "$*" >&2
}

usage() {
	cat <<'EOF'
Usage: ai-rule-hook.sh --tool <claude|codex|gemini|copilot> [--dry-run]

Reads hook JSON from stdin, normalizes the payload, and generates a rule-update
suggestion with the current tool's CLI. Use --dry-run to emit normalized JSON
instead of invoking the external CLI.
EOF
}

sanitize_segment() {
	printf '%s' "$1" | tr '/:[:space:]' '_' | tr -cd '[:alnum:]_.-'
}

expand_home_path() {
	local path="$1"

	case "$path" in
	"~")
		printf '%s\n' "$HOME"
		;;
	~/*)
		printf '%s/%s\n' "$HOME" "${path#~/}"
		;;
	*)
		printf '%s\n' "$path"
		;;
	esac
}

json_get_raw() {
	local filter="$1"

	printf '%s' "$HOOK_INPUT_JSON" | jq -r "$filter"
}

canonical_event() {
	case "$1" in
	SessionStart | sessionStart)
		printf 'session_start\n'
		;;
	SessionEnd | sessionEnd)
		printf 'session_end\n'
		;;
	PreCompact | preCompact)
		printf 'pre_compact\n'
		;;
	Stop | agentStop)
		printf 'stop\n'
		;;
	UserPromptSubmit | userPromptSubmitted)
		printf 'user_prompt_submit\n'
		;;
	*)
		printf 'unknown\n'
		;;
	esac
}

resolve_transcript_path() {
	local transcript_path="$1"

	if [[ -n "$transcript_path" ]]; then
		expand_home_path "$transcript_path"
	fi

	return 0
}

read_tail_bytes() {
	local path="$1"
	local limit="$2"

	if [[ ! -f "$path" ]]; then
		return 0
	fi

	local size
	size="$(wc -c <"$path" | tr -d '[:space:]')"
	if ((size > limit)); then
		tail -c "$limit" "$path"
	else
		cat "$path"
	fi
}

line_count_of() {
	local path="$1"

	if [[ ! -f "$path" ]]; then
		printf '0\n'
		return 0
	fi

	wc -l <"$path" | tr -d '[:space:]'
}

write_json() {
	local path="$1"
	local payload="$2"

	printf '%s\n' "$payload" >"$path"
}

tool_paths() {
	case "$TOOL" in
	claude)
		RULE_SOURCE_PATH="$HOME/.claude/CLAUDE.md"
		SKILLS_DIR="$HOME/.claude/skills"
		ANALYZER_BIN="claude"
		;;
	codex)
		RULE_SOURCE_PATH="$HOME/.codex/AGENTS.md"
		SKILLS_DIR=""
		ANALYZER_BIN="codex"
		;;
	gemini)
		RULE_SOURCE_PATH="$HOME/.gemini/GEMINI.md"
		SKILLS_DIR=""
		ANALYZER_BIN="gemini"
		;;
	copilot)
		RULE_SOURCE_PATH="$HOME/.config/gh-copilot/COPILOTCLI.md"
		SKILLS_DIR=""
		ANALYZER_BIN="claude"
		;;
	*)
		log "unsupported tool: $TOOL"
		exit 0
		;;
	esac
}

list_skills() {
	local skills_dir="${1:-}"
	if [[ -z "$skills_dir" ]] || [[ ! -d "$skills_dir" ]]; then
		printf '_スキルなし_\n'
		return 0
	fi
	local found=0
	while IFS= read -r -d '' skill_file; do
		local skill_name desc
		skill_name="$(basename "$(dirname "$skill_file")")"
		desc="$(grep -m1 '^description:' "$skill_file" 2>/dev/null |
			sed 's/^description:[[:space:]]*//' |
			cut -c1-200 || true)"
		if [[ -z "$desc" ]]; then
			desc="(description なし)"
		fi
		printf -- '- %s: %s\n' "$skill_name" "$desc"
		found=1
	done < <(find "$skills_dir" -name "SKILL.md" -print0 2>/dev/null | sort -z)
	if [[ $found -eq 0 ]]; then
		printf '_スキルなし_\n'
	fi
}

should_run_for_event() {
	case "$TOOL:$CANONICAL_EVENT" in
	claude:session_end | claude:pre_compact | gemini:session_end | gemini:pre_compact | copilot:session_end)
		return 0
		;;
	codex:user_prompt_submit)
		if [[ "$PROMPT_TEXT" =~ ^/(clear|new|compact)([[:space:]]|$) ]]; then
			return 0
		fi
		SKIP_REASON="codex_prompt_not_targeted"
		return 1
		;;
	codex:stop)
		if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
			SKIP_REASON="missing_transcript"
			return 1
		fi

		local current_lines
		current_lines="$(line_count_of "$TRANSCRIPT_PATH")"
		if ((current_lines < CODEX_STOP_MIN_LINES)); then
			SKIP_REASON="codex_stop_below_min_lines"
			return 1
		fi

		local stop_state_path="${SESSION_STATE_DIR}/codex-stop-state.json"
		local last_lines=0
		if [[ -f "$stop_state_path" ]]; then
			last_lines="$(jq -r '.last_lines // 0' "$stop_state_path" 2>/dev/null || printf '0')"
		fi
		if ((current_lines - last_lines < CODEX_STOP_LINE_DELTA)); then
			SKIP_REASON="codex_stop_below_line_delta"
			return 1
		fi
		CODEX_STOP_CURRENT_LINES="$current_lines"
		return 0
		;;
	*)
		SKIP_REASON="unsupported_event"
		return 1
		;;
	esac
}

build_prompt_file() {
	local prompt_path="$1"
	local transcript_excerpt_path="$2"
	local rules_excerpt_path="$3"
	local transcript_size="$4"
	local transcript_truncated="$5"
	local rules_size="$6"
	local rules_truncated="$7"
	local skills_list="${8:-_スキルなし_}"

	{
		cat "$PROMPT_TEMPLATE"
		cat <<EOF

## 実行メタデータ

- tool: ${TOOL}
- event: ${HOOK_EVENT_NAME}
- canonical_event: ${CANONICAL_EVENT}
- session_id: ${SESSION_ID:-unknown}
- cwd: ${CWD_PATH:-unknown}
- transcript_path: ${TRANSCRIPT_PATH:-missing}
- rule_source_path: ${RULE_SOURCE_PATH}
- source: ${EVENT_SOURCE:-}
- reason: ${EVENT_REASON:-}
- trigger: ${EVENT_TRIGGER:-}
- prompt: ${PROMPT_TEXT:-}

## 現在のルールファイル抜粋

- bytes: ${rules_size}
- truncated: ${rules_truncated}

\`\`\`md
EOF
		cat "$rules_excerpt_path"
		cat <<EOF
\`\`\`

## 既存スキル一覧

${skills_list}

## transcript 生データ抜粋

- bytes: ${transcript_size}
- truncated: ${transcript_truncated}

\`\`\`jsonl
EOF
		cat "$transcript_excerpt_path"
		cat <<'EOF'
```
EOF
	} >"$prompt_path"
}

emit_dry_run() {
	jq -n \
		--arg tool "$TOOL" \
		--arg hook_event_name "$HOOK_EVENT_NAME" \
		--arg canonical_event "$CANONICAL_EVENT" \
		--arg session_id "$SESSION_ID" \
		--arg cwd "$CWD_PATH" \
		--arg transcript_path "$TRANSCRIPT_PATH" \
		--arg rule_source_path "$RULE_SOURCE_PATH" \
		--arg skills_dir "${SKILLS_DIR:-}" \
		--arg analyzer "$ANALYZER_BIN" \
		--arg output_dir "$SESSION_STATE_DIR" \
		--arg prompt_file "$PROMPT_OUTPUT_PATH" \
		--arg skip_reason "$SKIP_REASON" \
		--arg source "$EVENT_SOURCE" \
		--arg reason "$EVENT_REASON" \
		--arg trigger "$EVENT_TRIGGER" \
		--arg prompt "$PROMPT_TEXT" \
		'{
			tool: $tool,
			hook_event_name: $hook_event_name,
			canonical_event: $canonical_event,
			session_id: (if $session_id == "" then null else $session_id end),
			cwd: (if $cwd == "" then null else $cwd end),
			transcript_path: (if $transcript_path == "" then null else $transcript_path end),
			rule_source_path: $rule_source_path,
			skills_dir: (if $skills_dir == "" then null else $skills_dir end),
			analyzer: $analyzer,
			output_dir: $output_dir,
			prompt_file: $prompt_file,
			source: (if $source == "" then null else $source end),
			reason: (if $reason == "" then null else $reason end),
			trigger: (if $trigger == "" then null else $trigger end),
			prompt: (if $prompt == "" then null else $prompt end),
			should_run: ($skip_reason == ""),
			skip_reason: (if $skip_reason == "" then null else $skip_reason end)
		}'
}

run_claude_analysis() {
	local prompt_path="$1"
	local output_path="$2"
	local stderr_path="$3"

	claude \
		-p \
		--output-format text \
		--no-session-persistence \
		--tools "" \
		<"$prompt_path" >"$output_path" 2>"$stderr_path"
}

run_codex_analysis() {
	local prompt_path="$1"
	local output_path="$2"
	local stderr_path="$3"

	codex exec \
		-C "${CWD_PATH:-$PWD}" \
		--skip-git-repo-check \
		-s read-only \
		-a never \
		-o "$output_path" \
		- \
		<"$prompt_path" >/dev/null 2>"$stderr_path"
}

run_gemini_analysis() {
	local prompt_path="$1"
	local output_path="$2"
	local stderr_path="$3"

	gemini \
		<"$prompt_path" >"$output_path" 2>"$stderr_path"
}

run_analysis() {
	local prompt_path="$1"
	local output_path="$2"
	local stderr_path="$3"

	if ! command -v "$ANALYZER_BIN" >/dev/null 2>&1; then
		log "analyzer not found: $ANALYZER_BIN"
		return 127
	fi

	case "$TOOL" in
	claude | copilot)
		run_claude_analysis "$prompt_path" "$output_path" "$stderr_path"
		;;
	codex)
		run_codex_analysis "$prompt_path" "$output_path" "$stderr_path"
		;;
	gemini)
		run_gemini_analysis "$prompt_path" "$output_path" "$stderr_path"
		;;
	esac
}

TOOL=""
DRY_RUN=0

while (($# > 0)); do
	case "$1" in
	--tool)
		TOOL="${2:-}"
		shift 2
		;;
	--dry-run)
		DRY_RUN=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		log "unknown argument: $1"
		usage >&2
		exit 1
		;;
	esac
done

if [[ -z "$TOOL" ]]; then
	usage >&2
	exit 1
fi

if [[ "${AI_RULE_HOOK_DRY_RUN:-0}" == "1" ]]; then
	DRY_RUN=1
fi

if [[ "${AI_RULE_HOOK_RUNNING:-0}" == "1" ]]; then
	exit 0
fi
export AI_RULE_HOOK_RUNNING=1

HOOK_INPUT_JSON="$(cat)"
if [[ -z "$HOOK_INPUT_JSON" ]]; then
	HOOK_INPUT_JSON='{}'
fi

HOOK_EVENT_NAME="$(json_get_raw '.hook_event_name // .hookEventName // empty')"
CANONICAL_EVENT="$(canonical_event "$HOOK_EVENT_NAME")"
SESSION_ID="$(json_get_raw '.session_id // .sessionId // empty')"
CWD_PATH="$(json_get_raw '.cwd // empty')"
PROMPT_TEXT="$(json_get_raw '.prompt // empty')"
EVENT_SOURCE="$(json_get_raw '.source // empty')"
EVENT_REASON="$(json_get_raw '.reason // empty')"
EVENT_TRIGGER="$(json_get_raw '.trigger // empty')"
TRANSCRIPT_PATH="$(resolve_transcript_path "$(json_get_raw '.transcript_path // .transcriptPath // empty')")"

tool_paths

SESSION_SLUG="$(sanitize_segment "${SESSION_ID:-unknown}")"
TIMESTAMP_SLUG="$(date '+%Y%m%d-%H%M%S')"
SESSION_STATE_DIR="${STATE_ROOT}/${TOOL}/${SESSION_SLUG}"
mkdir -p "$SESSION_STATE_DIR"

HOOK_INPUT_PATH="${SESSION_STATE_DIR}/${TIMESTAMP_SLUG}-${CANONICAL_EVENT}.input.json"
write_json "$HOOK_INPUT_PATH" "$HOOK_INPUT_JSON"

SKIP_REASON=""
CODEX_STOP_CURRENT_LINES=0

if ! should_run_for_event; then
	if ((DRY_RUN == 1)); then
		PROMPT_OUTPUT_PATH=""
		emit_dry_run
	fi
	exit 0
fi

if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
	SKIP_REASON="missing_transcript"
	if ((DRY_RUN == 1)); then
		PROMPT_OUTPUT_PATH=""
		emit_dry_run
	fi
	exit 0
fi

if [[ ! -f "$PROMPT_TEMPLATE" ]]; then
	log "prompt template not found: $PROMPT_TEMPLATE"
	exit 0
fi

TRANSCRIPT_SIZE="$(wc -c <"$TRANSCRIPT_PATH" | tr -d '[:space:]')"
TRANSCRIPT_TRUNCATED="false"
if ((TRANSCRIPT_SIZE > MAX_TRANSCRIPT_BYTES)); then
	TRANSCRIPT_TRUNCATED="true"
fi

RULE_SOURCE_RESOLVED="$(expand_home_path "$RULE_SOURCE_PATH")"
RULE_SIZE=0
RULE_TRUNCATED="false"
if [[ -f "$RULE_SOURCE_RESOLVED" ]]; then
	RULE_SIZE="$(wc -c <"$RULE_SOURCE_RESOLVED" | tr -d '[:space:]')"
	if ((RULE_SIZE > MAX_RULE_BYTES)); then
		RULE_TRUNCATED="true"
	fi
fi

TRANSCRIPT_EXCERPT_PATH="${SESSION_STATE_DIR}/${TIMESTAMP_SLUG}-${CANONICAL_EVENT}.transcript.jsonl"
RULE_EXCERPT_PATH="${SESSION_STATE_DIR}/${TIMESTAMP_SLUG}-${CANONICAL_EVENT}.rule.md"
PROMPT_OUTPUT_PATH="${SESSION_STATE_DIR}/${TIMESTAMP_SLUG}-${CANONICAL_EVENT}.prompt.md"
ANALYSIS_OUTPUT_PATH="${SESSION_STATE_DIR}/${TIMESTAMP_SLUG}-${CANONICAL_EVENT}.suggestion.md"
ANALYSIS_STDERR_PATH="${SESSION_STATE_DIR}/${TIMESTAMP_SLUG}-${CANONICAL_EVENT}.stderr.log"

read_tail_bytes "$TRANSCRIPT_PATH" "$MAX_TRANSCRIPT_BYTES" >"$TRANSCRIPT_EXCERPT_PATH"
if [[ -f "$RULE_SOURCE_RESOLVED" ]]; then
	read_tail_bytes "$RULE_SOURCE_RESOLVED" "$MAX_RULE_BYTES" >"$RULE_EXCERPT_PATH"
else
	printf '_ルールファイルが見つかりません: %s_\n' "$RULE_SOURCE_RESOLVED" >"$RULE_EXCERPT_PATH"
fi

SKILLS_LIST="$(list_skills "${SKILLS_DIR:-}")"

build_prompt_file \
	"$PROMPT_OUTPUT_PATH" \
	"$TRANSCRIPT_EXCERPT_PATH" \
	"$RULE_EXCERPT_PATH" \
	"$TRANSCRIPT_SIZE" \
	"$TRANSCRIPT_TRUNCATED" \
	"$RULE_SIZE" \
	"$RULE_TRUNCATED" \
	"$SKILLS_LIST"

if ((DRY_RUN == 1)); then
	emit_dry_run
	exit 0
fi

if run_analysis "$PROMPT_OUTPUT_PATH" "$ANALYSIS_OUTPUT_PATH" "$ANALYSIS_STDERR_PATH"; then
	log "wrote suggestion: $ANALYSIS_OUTPUT_PATH"
	if [[ "$TOOL" == "codex" ]] && [[ "$CANONICAL_EVENT" == "stop" ]]; then
		jq -n --argjson last_lines "$CODEX_STOP_CURRENT_LINES" '{last_lines: $last_lines}' \
			>"${SESSION_STATE_DIR}/codex-stop-state.json"
	fi
else
	log "analysis command failed; see $ANALYSIS_STDERR_PATH"
	exit 0
fi
