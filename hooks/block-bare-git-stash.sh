#!/bin/bash
# PreToolUseフック: bareなgit stash/git stash pop/git stash saveを直接実行しようとした場合にブロックする
# stashスタックはメインチェックアウトと全worktreeで共有され他セッションと衝突しうるため、
# tool.md/git.mdの規約に従いgit stash push -u -m "<タグ>" + git stash apply <sha>の手順に統一する
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

pattern='(^|[;&|(`[:space:]])git([[:space:]]+-[A-Za-z-]+([[:space:]]+[^[:space:]]+)?)*[[:space:]]+stash([[:space:]]+([A-Za-z_-]+))?'

if [[ ! "$command" =~ $pattern ]]; then
  exit 0
fi

subcmd="${BASH_REMATCH[5]:-}"

case "$subcmd" in
  push|apply|list|drop|show|clear|branch|create|store)
    exit 0
    ;;
esac

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "git stash / git stash pop / git stash saveを直接使わず、git stash push -u -m \"<一意なタグ>\"で退避し、git stash apply <sha>（popではない）で復元してください。stashスタックはメインチェックアウトと全worktreeで共有され、他セッションが同時にpush/popしうるためbareな操作は避ける必要があります。"
  }
}'
