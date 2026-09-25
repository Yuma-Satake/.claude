#!/bin/bash
# PostToolUseフック: git add成功後にgit statusをadditionalContextとして注入する
# ステージ結果の確認漏れ（git.md: "git addの実施後は、必ずgit statusでステージ結果を確認する"）を防ぐ
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

pattern='(^|[;&|(`[:space:]])git([[:space:]]+-[A-Za-z-]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+add([[:space:]]|$)'

if [[ ! "$command" =~ $pattern ]]; then
  exit 0
fi

if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then
  exit 0
fi

status=$(git -C "$cwd" status 2>/dev/null) || exit 0

jq -n --arg status "$status" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ("git addの直後のgit status結果である。意図した内容が正しくステージされているか確認すること。\n\n" + $status)
  }
}'
