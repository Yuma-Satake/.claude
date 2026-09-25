#!/bin/bash
# afkモードの有効フラグをセッション単位で管理する
# サブコマンド:
#   activate <session-id>   有効にする
#   status <session-id>     active / inactive を標準出力に出す
#   clear <session-id>      無効にする
set -euo pipefail

STATE_DIR="$HOME/.claude/state/afk"

subcommand="${1:-}"
session_id="${2:-}"

if [ -z "$subcommand" ] || [ -z "$session_id" ]; then
  echo "usage: afk-flag.sh <activate|status|clear> <session-id>" >&2
  exit 1
fi

# session_id はファイル名に使うため英数字・ハイフン・アンダースコアのみに制限する
if ! [[ "$session_id" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "invalid session-id: $session_id" >&2
  exit 1
fi

mkdir -p "$STATE_DIR"
flag_file="$STATE_DIR/${session_id}.flag"

case "$subcommand" in
  activate)
    touch "$flag_file"
    ;;
  status)
    if [ -f "$flag_file" ]; then
      echo "active"
    else
      echo "inactive"
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
