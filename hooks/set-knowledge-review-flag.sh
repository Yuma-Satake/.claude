#!/bin/bash
# PostToolUseフック: git commitの成功を検知し、knowledge-reviewの実行保留フラグを自動で立てる
# commitスキル経由か直接コマンド実行かを問わず、コミットが成立した時点で発火する
set -euo pipefail

input=$(cat)

# gitOperation.commit.kindが"committed"の場合のみ成立したコミットとみなす
# (nothing to commit等の失敗はBashツール自体がエラー終了しPostToolUseが発火しないため、
#  ここへ来る時点で基本的に成立しているが、念のため構造化フィールドでも確認する)
kind=$(echo "$input" | jq -r '.tool_response.gitOperation.commit.kind // empty')
if [ "$kind" != "committed" ]; then
  exit 0
fi

cwd=$(echo "$input" | jq -r '.cwd // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')

if [ -z "$cwd" ] || [ ! -d "$cwd" ] || [ -z "$session_id" ]; then
  exit 0
fi

repo_path=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0

"$HOME/.claude/hooks/knowledge-review-flag.sh" set "$repo_path" "$session_id"
