#!/bin/bash
# Monitor呼び出し時に、タイムアウトが形骸化している設定を警告する

input=$(cat)
timeout_ms=$(jq -r '.tool_input.timeout_ms // empty' <<<"$input")
command=$(jq -r '.tool_input.command // empty' <<<"$input")

# Monitorツールのtimeout_msの既定値。スキーマ上timeout_msは必須のため、省略は既定値との一致で検知する
default_timeout_ms=300000

# ループ内の経過時間上限とみなす表現
time_bound_pattern='SECONDS|date[[:space:]]+\+%s|\btimeout\b|deadline|elapsed|\bseq\b'

warnings=()

if [[ "$timeout_ms" == "$default_timeout_ms" ]]; then
  warnings+=("timeout_msが既定値のままである。監視対象の想定所要時間に余裕を持たせた値を明示的に指定する")
fi

if [[ "$command" =~ (while[[:space:]]+(true|:)|until[[:space:]]) ]] && ! [[ "$command" =~ $time_bound_pattern ]]; then
  warnings+=("commandのループに経過時間の上限が見当たらない。判定条件が誤っていると監視が終わらないため、ループ内にも上限を設ける")
fi

if [[ ${#warnings[@]} -eq 0 ]]; then
  exit 0
fi

message="Monitorのタイムアウト設定に問題がある可能性がある（tool.mdのMonitorタイムアウトのルール参照）。"
for w in "${warnings[@]}"; do
  message+=" / $w"
done

jq -n --arg msg "$message" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $msg}}'
