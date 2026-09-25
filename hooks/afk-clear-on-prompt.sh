#!/bin/bash
# UserPromptSubmitフック: ユーザーの実際の発言を検知し、afkモードの有効フラグを解除する
set -euo pipefail

input=$(cat)

session_id=$(echo "$input" | jq -r '.session_id // empty')
if [ -z "$session_id" ]; then
  exit 0
fi

"$HOME/.claude/hooks/afk-flag.sh" clear "$session_id"
