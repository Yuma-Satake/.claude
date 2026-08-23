#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
USED_TOKENS=$(echo "$input" | jq -r '((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0))')
CONTEXT_WINDOW_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
CONTEXT_LIMIT=$CONTEXT_WINDOW_SIZE
[ -n "$CLAUDE_CODE_AUTO_COMPACT_WINDOW" ] && [ "$CLAUDE_CODE_AUTO_COMPACT_WINDOW" -gt "$CONTEXT_WINDOW_SIZE" ] && CONTEXT_LIMIT=$CLAUDE_CODE_AUTO_COMPACT_WINDOW
PCT=$((USED_TOKENS * 100 / CONTEXT_LIMIT))
BAR_WIDTH=21
FILLED=$((PCT * BAR_WIDTH / 100))
[ "$FILLED" -gt "$BAR_WIDTH" ] && FILLED=$BAR_WIDTH
EMPTY=$((BAR_WIDTH - FILLED))

BAR=""
[ "$FILLED" -gt 0 ] && BAR=$(printf "%${FILLED}s" | tr ' ' '█')
[ "$EMPTY" -gt 0 ] && BAR="${BAR}$(printf "%${EMPTY}s" | tr ' ' '░')"

if [ "$PCT" -ge 80 ]; then
  COLOR='\033[31m'
elif [ "$PCT" -ge 70 ]; then
  COLOR='\033[33m'
else
  COLOR='\033[32m'
fi
RESET='\033[0m'
BOLD='\033[1m'

RATE_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // 0' | cut -d. -f1)
RATE_FILLED=$((RATE_PCT * BAR_WIDTH / 100))
RATE_EMPTY=$((BAR_WIDTH - RATE_FILLED))

RATE_BAR=""
[ "$RATE_FILLED" -gt 0 ] && RATE_BAR=$(printf "%${RATE_FILLED}s" | tr ' ' '█')
[ "$RATE_EMPTY" -gt 0 ] && RATE_BAR="${RATE_BAR}$(printf "%${RATE_EMPTY}s" | tr ' ' '░')"

RATE_COLOR='\033[34m'

GIT_BRANCH=$(git branch --show-current 2>/dev/null)

RESETS_AT=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
RESET_LABEL=""
if [ -n "$RESETS_AT" ] && [ "$RATE_PCT" -ge 80 ]; then
  RESET_TIME=$(date -r "$RESETS_AT" '+%H:%M' 2>/dev/null || date -d "@$RESETS_AT" '+%H:%M' 2>/dev/null)
  RESET_LABEL=" (reset:${RESET_TIME})"
fi

CWD=$(basename "$(pwd)")

HAS_RATE_LIMITS=$(echo "$input" | jq -r 'if .rate_limits.five_hour.used_percentage != null then "1" else "0" end')

PREFIX="${BOLD}${MODEL}${RESET}"
[ -n "$GIT_BRANCH" ] && PREFIX="${BOLD}⎇ ${GIT_BRANCH}${RESET} ${BOLD}${MODEL}${RESET}"
LABEL=""
[ "${CLAUDE_CODE_USE_BEDROCK}" = "1" ] && LABEL=" (🧠Bedrock)"

if [ "$HAS_RATE_LIMITS" = "0" ]; then
  echo -e "${BOLD}/${CWD}${RESET} ${PREFIX}${LABEL} ${COLOR}[${BAR}] ${PCT}%${RESET}"
else
  echo -e "${BOLD}/${CWD}${RESET} ${PREFIX} ctx:${COLOR}[${BAR}] ${PCT}%${RESET} limit:${RATE_COLOR}[${RATE_BAR}] ${RATE_PCT}%${RESET_LABEL}${RESET}"
fi
