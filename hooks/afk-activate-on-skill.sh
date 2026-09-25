#!/bin/bash
# PostToolUseフック: afkスキルの呼び出しを検知し、afkモードの有効フラグを立てる
set -euo pipefail

input=$(cat)

skill=$(echo "$input" | jq -r '.tool_input.skill // empty')
if [ "$skill" != "afk" ]; then
  exit 0
fi

session_id=$(echo "$input" | jq -r '.session_id // empty')
if [ -z "$session_id" ]; then
  exit 0
fi

"$HOME/.claude/hooks/afk-flag.sh" activate "$session_id"
