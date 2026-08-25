#!/bin/bash
# WorktreeCreateフック: EnterWorktree等のデフォルトgit worktree処理をworktrunk(wt)経由に差し替える
# wtのpost-startフック(copy-ignored)がgitignore対象ファイル(.env等)を自動コピーする
set -euo pipefail

input=$(cat)
name=$(echo "$input" | jq -r '.name')
cwd=$(echo "$input" | jq -r '.cwd')

result=$(mise exec worktrunk -- wt switch -C "$cwd" "$name" --create --no-cd --format json)
path=$(echo "$result" | jq -r '.path // empty')

if [ -z "$path" ]; then
  echo "wt switch did not return a worktree path: $result" >&2
  exit 1
fi

echo "$path"
