#!/usr/bin/env bash
# 新しいHerdr workspaceを作り、その中でclaudeを起動して指示を渡す。
# 使い方: herdr_pass.sh --name <agent名> --cwd <dir> --prompt-file <file> [--launcher cc|ccaws]
# 標準出力: 成功時は key=value の行(workspace/pane/agent)、失敗時は "herdr-pass: failed (<reason>)"
set -u

fail() { echo "herdr-pass: failed ($1)"; exit 1; }

name="" cwd="$PWD" prompt_file="" launcher="cc"
while [ $# -gt 0 ]; do
  case "$1" in
    --name) name="$2"; shift 2 ;;
    --cwd) cwd="$2"; shift 2 ;;
    --prompt-file) prompt_file="$2"; shift 2 ;;
    --launcher) launcher="$2"; shift 2 ;;
    *) fail "unknown option $1" ;;
  esac
done

# Herdr外からは他のセッションを操作しないため何もしない
[ "${HERDR_ENV:-}" = 1 ] || { echo "herdr-pass: skipped (not herdr)"; exit 0; }
[ -n "$name" ] && [ -f "$prompt_file" ] || fail "missing --name or --prompt-file"
# 起動はzshの関数(cc/ccaws)経由で行う。これらは.env.1passwordの注入やBedrock用の環境変数を設定するため、agent startでは代替できない
case "$launcher" in cc|ccaws) ;; *) fail "invalid launcher" ;; esac
# herdrのagent名の制約: [a-z][a-z0-9_-]{0,31}
printf '%s' "$name" | grep -Eq '^[a-z][a-z0-9_-]{0,31}$' || fail "invalid agent name"

ws_json=$(herdr workspace create --cwd "$cwd" --label "$name" --no-focus) || fail "workspace create"
workspace=$(printf '%s' "$ws_json" | jq -r '.result.workspace.workspace_id // empty')
pane=$(printf '%s' "$ws_json" | jq -r '.result.root_pane.pane_id // empty')
[ -n "$pane" ] || fail "no root pane in response"

herdr pane run "$pane" "$launcher" >/dev/null || fail "pane run $launcher (workspace=$workspace pane=$pane)"

# agentとして検出され、入力可能になるまで待つ(1Password認証を含むため長めに待つ)
ready=""
for _ in $(seq 1 90); do
  ready=$(herdr agent get "$pane" 2>/dev/null | jq -r '.result.agent | select(.agent == "claude" and .agent_status == "idle") | .pane_id // empty')
  [ -n "$ready" ] && break
  sleep 2
done
[ -n "$ready" ] || fail "$launcher did not become ready (workspace=$workspace pane=$pane)"
herdr agent rename "$pane" "$name" >/dev/null || fail "agent rename (workspace=$workspace pane=$pane)"

# 送信のみ。完了待ちや稼働確認は呼び出し側が行う
herdr agent prompt "$name" "$(cat "$prompt_file")" >/dev/null || fail "agent prompt (workspace=$workspace pane=$pane)"

echo "workspace=$workspace"
echo "pane=$pane"
echo "agent=$name"
