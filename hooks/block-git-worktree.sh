#!/bin/bash
# PreToolUseフック: Bashで`git worktree add/remove/prune`を直接実行しようとした場合にブロックする
# worktree作成・削除はEnterWorktree/ExitWorktreeツール経由に統一し、gitignore対象ファイル(.env等)の自動コピーを保証する
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

pattern='(^|[;&|(`[:space:]])git([[:space:]]+-[A-Za-z-]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+worktree[[:space:]]+(add|remove|prune)([[:space:]]|$)'

if echo "$command" | grep -qE "$pattern"; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "worktreeの作成・削除にはgit worktreeを直接使わず、EnterWorktree/ExitWorktreeツールを使ってください。gitignore対象ファイル（.env等）の自動コピーはEnterWorktree経由でのみ行われます。"
    }
  }'
fi
