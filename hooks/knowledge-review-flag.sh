#!/bin/bash
# knowledge-review の実行保留フラグをセッション単位で管理する
# 同一リポジトリで複数セッションが並行する場合に、他セッションのフラグを誤って
# 検知・上書き・消去しないよう、フラグはリポジトリ×セッションIDの組でスコープする
# サブコマンド:
#   set <repo-path> <session-id>              保留フラグを立てる
#   check <repo-path> <session-id>            保留中かどうかを判定する。標準出力に "remind" (要リマインド) / "silent" (保留中だがcooldown内) / "none" (保留なし) を出す
#   mark-reminded <repo-path> <session-id>    直近リマインド時刻を更新する
#   clear <repo-path> <session-id>            保留フラグを消す
set -euo pipefail

STATE_DIR="$HOME/.claude/state/knowledge-review"
TTL_SECONDS=$((24 * 60 * 60))
COOLDOWN_SECONDS=$((15 * 60))

subcommand="${1:-}"
repo_path="${2:-}"
session_id="${3:-}"

if [ -z "$subcommand" ] || [ -z "$repo_path" ] || [ -z "$session_id" ]; then
  echo "usage: knowledge-review-flag.sh <set|check|mark-reminded|clear> <repo-path> <session-id>" >&2
  exit 1
fi

# session_id はファイル名に使うため英数字・ハイフン・アンダースコアのみに制限する
if ! [[ "$session_id" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "invalid session-id: $session_id" >&2
  exit 1
fi

mkdir -p "$STATE_DIR"

repo_hash=$(printf '%s' "$repo_path" | shasum -a 256 | cut -d' ' -f1)
flag_file="$STATE_DIR/${repo_hash}-${session_id}.json"

now=$(date +%s)

case "$subcommand" in
  set)
    # 既存フラグがある場合は last_reminded を温存する（連続commitのたびにcooldownがリセットされるのを防ぐ）
    if [ -f "$flag_file" ]; then
      last_reminded=$(jq -r '.last_reminded' "$flag_file")
    else
      last_reminded=0
    fi
    jq -n --arg repo "$repo_path" --arg session "$session_id" --argjson set_at "$now" --argjson last_reminded "$last_reminded" \
      '{repo: $repo, session_id: $session, set_at: $set_at, last_reminded: $last_reminded}' > "$flag_file"
    ;;
  check)
    if [ ! -f "$flag_file" ]; then
      echo "none"
      exit 0
    fi
    set_at=$(jq -r '.set_at' "$flag_file")
    last_reminded=$(jq -r '.last_reminded' "$flag_file")
    if [ $((now - set_at)) -gt "$TTL_SECONDS" ]; then
      rm -f "$flag_file"
      echo "none"
      exit 0
    fi
    if [ $((now - last_reminded)) -lt "$COOLDOWN_SECONDS" ]; then
      echo "silent"
      exit 0
    fi
    echo "remind"
    ;;
  mark-reminded)
    if [ -f "$flag_file" ]; then
      tmp_file=$(mktemp "$STATE_DIR/.tmp.XXXXXX")
      jq --argjson now "$now" '.last_reminded = $now' "$flag_file" > "$tmp_file"
      mv "$tmp_file" "$flag_file"
    fi
    ;;
  clear)
    rm -f "$flag_file"
    ;;
  *)
    echo "unknown subcommand: $subcommand" >&2
    exit 1
    ;;
esac
