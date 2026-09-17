#!/bin/bash
# PreToolUseフック: `rtk hook claude`への薄いラッパー
# git worktree内で実行されるgitコマンドは、rtkのコマンドリライト（git ... -> rtk git ...）を経由させず
# 素のgitコマンドとしてそのまま許可する。rtkが先頭トークンをrtkに書き換えると、
# worktree-isolatedセッション向けのgit検証ロジック（実行バイナリの直後にgitが来ることを要求する）が
# コマンドをgitと認識できず、worktree内の全gitコマンドが拒否されるため。
# フック入力のcwdはハーネスが追跡するセッションの作業ディレクトリであり、実際にコマンドが対象とする
# ディレクトリ（submodule配下など）と食い違うことがある。cwd自体がworktreeでなくても、
# そのリポジトリにlinked worktreeが存在する場合は安全側でrtkをスキップする
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

if echo "$command" | grep -qE '^[[:space:]]*git([[:space:]]|$)' && [ -n "$cwd" ] && [ -d "$cwd" ]; then
  git_dir=$(git -C "$cwd" rev-parse --absolute-git-dir 2>/dev/null || true)
  common_dir_raw=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null || true)
  is_worktree=false
  if [ -n "$git_dir" ] && [ -n "$common_dir_raw" ]; then
    common_dir=$(cd "$cwd" && realpath "$common_dir_raw" 2>/dev/null || true)
    if [ -n "$common_dir" ] && [ "$git_dir" != "$common_dir" ]; then
      is_worktree=true
    fi
  fi
  # submodule のリンク worktree は、そのリポジトリ専用の worktree 領域 (.git/worktrees/<name>/modules/...)
  # 内に git_dir 自体が作られるため git_dir と common_dir が同一パスになり、上の比較では判定できない。
  # このパス形状自体が worktree 内であることの証拠になる
  if [ "$is_worktree" = false ] && [ -n "$git_dir" ] && [[ "$git_dir" == *"/.git/worktrees/"* ]]; then
    is_worktree=true
  fi

  worktree_count=$(git -C "$cwd" worktree list 2>/dev/null | wc -l | tr -d ' ')

  if [ "$is_worktree" = true ] || [ "${worktree_count:-0}" -gt 1 ]; then
    exit 0
  fi
fi

echo "$input" | rtk hook claude
