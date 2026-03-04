#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
BAR_WIDTH=30
FILLED=$((PCT * BAR_WIDTH / 100))
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

echo -e "${MODEL} ${COLOR}[${BAR}] ${PCT}%${RESET}"
