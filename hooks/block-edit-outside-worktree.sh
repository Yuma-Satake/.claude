#!/bin/bash
# PreToolUseフック: Yuma-Satake以外のgitリポジトリで、worktree外のファイルをEdit/Writeしようとした場合にブロックする
# git管理外のパス、origin未設定のリポジトリ、originがYuma-Satakeのリポジトリは対象外とする
set -uo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')

[ -z "$file_path" ] && exit 0

# 新規ファイルの場合は存在する最も近い親ディレクトリで判定する
dir=$(dirname "$file_path")
while [ ! -d "$dir" ] && [ "$dir" != "/" ]; do
  dir=$(dirname "$dir")
done

git_dir=$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null) || exit 0

origin_url=$(git -C "$dir" remote get-url origin 2>/dev/null) || exit 0

if echo "$origin_url" | grep -qiE '[:/]Yuma-Satake/'; then
  exit 0
fi

# worktreeのgit-dirは`.git/worktrees/`配下になる（submoduleのworktreeも同様）
case "$git_dir" in
  */worktrees/*) exit 0 ;;
esac

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "Yuma-Satake以外のリポジトリでは、worktree外のファイルを編集できません。EnterWorktreeツールでworktreeを作成・切り替えてから編集してください。"
  }
}'
