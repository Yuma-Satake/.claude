#!/bin/bash
# PreToolUseフック: Bashで`git worktree add`を直接実行しようとした場合にブロックする
# worktree作成はEnterWorktreeツール経由に統一し、gitignore対象ファイル(.env等)の自動コピーを保証する
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

pattern='(^|[;&|(`[:space:]])git([[:space:]]+-[A-Za-z-]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+worktree[[:space:]]+add([[:space:]]|$)'

if echo "$command" | grep -qE "$pattern"; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "worktreeの作成にはgit worktree addを直接使わず、EnterWorktreeツールを使ってください。gitignore対象ファイル（.env等）の自動コピーはEnterWorktree経由でのみ行われます。"
    }
  }'
fi
