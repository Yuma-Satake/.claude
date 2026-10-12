#!/bin/bash
# PreToolUseフック: 未コミットの変更が残っている状態でのgit switchをブロックする
# 未コミットの変更はブランチ切り替え時にそのまま持ち越され、意図しないブランチへ混入するため
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

pattern='(^|[;&|(`[:space:]])git([[:space:]]+-[A-Za-z-]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+switch([[:space:]]|$)'

if [[ ! "$command" =~ $pattern ]]; then
  exit 0
fi

if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then
  exit 0
fi

dirty=$(git -C "$cwd" status --porcelain 2>/dev/null) || exit 0

if [ -n "$dirty" ]; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "未コミットの変更が残っている状態でのgit switchはブロックされています。変更はブランチ切り替え時にそのまま持ち越されるため、意図しないブランチへ混入する可能性があります。コミットするか、git stash push -u -m \"<タグ>\"で退避してから切り替えてください。"
    }
  }'
fi
