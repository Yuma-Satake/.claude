#!/bin/bash
# WorktreeCreateフック: EnterWorktree等のデフォルトgit worktree処理をworktrunk(wt)経由に差し替える
# wtのpre-startフック(copy-ignored)がgitignore対象ファイル(.env等)を自動コピーする
# nameが既存のローカル/リモートブランチ名ならそのブランチをチェックアウトし、なければ新規ブランチを作る
set -euo pipefail

input=$(cat)
name=$(echo "$input" | jq -r '.name')
cwd=$(echo "$input" | jq -r '.cwd')

branch_exists() {
  # ローカルブランチ、または任意のリモートの追跡ブランチ
  git -C "$cwd" show-ref --verify --quiet "refs/heads/$1" && return 0
  local remote
  for remote in $(git -C "$cwd" remote); do
    git -C "$cwd" show-ref --verify --quiet "refs/remotes/$remote/$1" && return 0
  done
  return 1
}

# --createを付けると、リモートにしかないブランチ名でも警告のみで別ブランチをmainから新規作成してしまう
create_flag=(--create)
if branch_exists "$name"; then
  create_flag=()
fi

result=$(mise exec worktrunk -- wt switch -C "$cwd" "$name" ${create_flag[@]+"${create_flag[@]}"} --no-cd --format json)
path=$(echo "$result" | jq -r '.path // empty')
action=$(echo "$result" | jq -r '.action // empty')

if [ -z "$path" ]; then
  echo "wt switch did not return a worktree path: $result" >&2
  exit 1
fi

# 既存worktreeのパスを返すと新規作成したものとして扱われ、WorktreeRemoveで削除されうる
if [ "$action" != "created" ]; then
  echo "branch '$name' already has a worktree at $path (action=$action); use EnterWorktree with path instead" >&2
  exit 1
fi

echo "$path"
