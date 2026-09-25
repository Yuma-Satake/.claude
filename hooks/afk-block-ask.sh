#!/bin/bash
# PreToolUseフック: afkモード中はAskUserQuestionの呼び出しを常にブロックする
set -euo pipefail

input=$(cat)

session_id=$(echo "$input" | jq -r '.session_id // empty')
if [ -z "$session_id" ]; then
  exit 0
fi

status=$("$HOME/.claude/hooks/afk-flag.sh" status "$session_id")
if [ "$status" != "active" ]; then
  exit 0
fi

reason="ユーザーは現在離席中(afkモード)であり、AskUserQuestionを呼び出しても応答は返ってこない。提示できる選択肢の中から最も妥当な既定解を自分で選び、判断の理由を記録した上で確認を待たずに作業を進める必要がある。afkスキル(~/.claude/skills/afk/SKILL.md)が定める『確認を省略しない対象』に該当する場合のみ、この判断を保留し停止してよい。"

jq -n --arg reason "$reason" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
