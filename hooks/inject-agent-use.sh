#!/bin/bash
# PreToolUse(Agent)フック: agent-useスキルの本文をコンテキストに直接注入する
# 同一セッションでは1回だけ注入する（Agent呼び出しごとに同文が重複するのを防ぐ）
set -euo pipefail

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
flag="${TMPDIR:-/tmp}/claude-agent-use-injected-${session_id}"

if [ -f "$flag" ]; then
  exit 0
fi
touch "$flag"

# frontmatter（1つ目の --- から2つ目の --- まで）を除いた本文を注入する
awk 'c==2{print} /^---$/{if(c<2){c++; next}}' "$HOME/.claude/skills/agent-use/SKILL.md" \
  | jq -Rs '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":.}}'
