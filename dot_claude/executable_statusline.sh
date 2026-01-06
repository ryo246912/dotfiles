#!/bin/bash
# Claude Code ステータスライン - セッション料金と詳細なトークン情報を表示

input=$(cat)

# モデル名を取得
MODEL=$(echo "$input" | jq -r '.model.display_name // "Unknown"')

# 料金情報を取得
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
LINES_ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# コンテキストウィンドウ情報を取得
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
TOTAL_INPUT=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
TOTAL_OUTPUT=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
USAGE=$(echo "$input" | jq '.context_window.current_usage')

# コンテキスト使用状況と残りを計算
if [ "$USAGE" != "null" ]; then
	INPUT_TOKENS=$(echo "$USAGE" | jq '.input_tokens // 0')
	OUTPUT_TOKENS=$(echo "$USAGE" | jq '.output_tokens // 0')
	CACHE_CREATION=$(echo "$USAGE" | jq '.cache_creation_input_tokens // 0')
	CACHE_READ=$(echo "$USAGE" | jq '.cache_read_input_tokens // 0')

	CURRENT_TOKENS=$((INPUT_TOKENS + CACHE_CREATION + CACHE_READ))
	REMAINING_TOKENS=$((CONTEXT_SIZE - CURRENT_TOKENS))
	PERCENT_REMAINING=$(((REMAINING_TOKENS * 100) / CONTEXT_SIZE))

	# K単位に変換
	REMAINING_K=$((REMAINING_TOKENS / 1000))
	TOTAL_INPUT_K=$((TOTAL_INPUT / 1000))
	TOTAL_OUTPUT_K=$((TOTAL_OUTPUT / 1000))
	INPUT_K=$((INPUT_TOKENS / 1000))
	OUTPUT_K=$((OUTPUT_TOKENS / 1000))

	CONTEXT_INFO="残り ${REMAINING_K}K (${PERCENT_REMAINING}%) | 現在 in:${INPUT_K}K out:${OUTPUT_K}K | 累計 in:${TOTAL_INPUT_K}K out:${TOTAL_OUTPUT_K}K"
else
	REMAINING_K=$((CONTEXT_SIZE / 1000))
	TOTAL_INPUT_K=$((TOTAL_INPUT / 1000))
	TOTAL_OUTPUT_K=$((TOTAL_OUTPUT / 1000))
	CONTEXT_INFO="残り ${REMAINING_K}K (100%) | 累計 in:${TOTAL_INPUT_K}K out:${TOTAL_OUTPUT_K}K"
fi

# ステータスラインを出力
echo "[$MODEL] 💰 \$$COST | 📝 +$LINES_ADDED/-$LINES_REMOVED | 📊 $CONTEXT_INFO"
