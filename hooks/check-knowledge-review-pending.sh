#!/bin/bash
# Stopフック: commitスキルが立てたknowledge-review保留フラグを検知し、
# 対象リポジトリでの作業終了時にリマインダーをコンテキストへ注入する
set -euo pipefail

input=$(cat)

# サブエージェント内のStopでは発火させない（agent_idが入っている場合はサブエージェント）
agent_id=$(echo "$input" | jq -r '.agent_id // empty')
if [ -n "$agent_id" ]; then
  exit 0
fi

cwd=$(echo "$input" | jq -r '.cwd // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')

if [ -z "$cwd" ] || [ ! -d "$cwd" ] || [ -z "$session_id" ]; then
  exit 0
fi

repo_path=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0

flag_script="$HOME/.claude/hooks/knowledge-review-flag.sh"
# 自セッションが立てたフラグのみを対象にする。同一リポジトリの他セッションのフラグには反応しない
status=$("$flag_script" check "$repo_path" "$session_id")

if [ "$status" != "remind" ]; then
  exit 0
fi

"$flag_script" mark-reminded "$repo_path" "$session_id"

message="commit時にknowledge-reviewが未実行のまま保留されています（対象リポジトリ: ${repo_path}）。現在ユーザーから依頼されている作業、または直前の自分の応答がユーザーへの確認待ちの質問・承認待ちで終わっている（タスクが完了しておらずユーザーの回答を待っている）場合は、それを優先しknowledge-reviewは実行しない。この場合は何もせずそのまま応答を終了し、ユーザーからの返信を待つ。他に依頼作業や確認待ちがなければ、ユーザーに確認を取らずそのままknowledge-reviewスキルを実行する。依頼作業がある場合はそれを優先し、完了した時点で同様に確認なしで実行する。"

jq -n --arg msg "$message" \
  '{hookSpecificOutput: {hookEventName: "Stop", additionalContext: $msg}}'
