#!/bin/bash
# knowledge-reviewの知見候補の発生とユーザーの判断を、セッションを跨いで蓄積・照合する
# 並行セッションから同時に操作されても記録が失われないよう、作成後のファイルへの書き込みは追記のみとする
# サブコマンド:
#   list <session-id>                                 全候補の概要を1行ずつ出す。発生セッション数は指定したセッションを除いて数える
#   decisions                                         過去のユーザーの判断と理由を1行ずつ出す
#   show <slug>                                       候補の記録をすべて出す
#   record <slug> <session-id> <summary> <note>       発生を記録する。候補がなければsummaryで新規作成する
#   decide <slug> <session-id> <decision> <reason>    ユーザーの判断を記録する
set -euo pipefail

OBS_DIR="$HOME/.claude/state/knowledge-review/observations"
mkdir -p "$OBS_DIR"

usage() {
  echo "usage: observations.sh <list|decisions|show|record|decide> [args...]" >&2
  exit 1
}

# slugはファイル名に使うため使える文字を制限する
validate_slug() {
  if ! [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "invalid slug: $1" >&2
    exit 1
  fi
}

# 空のIDを許すと別々のセッションが1セッションとして数えられ、再発を検知できなくなる
validate_session_id() {
  if ! [[ "$1" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "invalid session-id: $1" >&2
    exit 1
  fi
}

require_file() {
  if [ ! -f "$OBS_DIR/$1.md" ]; then
    echo "not found: $1" >&2
    exit 1
  fi
}

# 記録の1行1件・listのタブ区切りの形式が崩れないようにする
single_line() {
  printf '%s' "$1" | tr '\n\r\t' '   '
}

subcommand="${1:-}"
[ -n "$subcommand" ] || usage

case "$subcommand" in
  list)
    [ "$#" -eq 2 ] || usage
    current_session="$2"
    validate_session_id "$current_session"
    shopt -s nullglob
    for file in "$OBS_DIR"/*.md; do
      awk -v slug="$(basename "$file" .md)" -v current="session=$current_session" '
        /^summary: / { summary = substr($0, 10) }
        /^- [0-9]/ {
          if ($3 == "occurred") {
            last_date = $2
            if ($4 != current ":" && !($4 in seen)) { seen[$4] = 1; sessions++ }
          } else {
            status = $3
          }
        }
        END {
          printf "%s\t%s\t%d\t%s\t%s\n", slug, (status == "" ? "pending" : status), sessions, last_date, summary
        }
      ' "$file"
    done
    ;;
  decisions)
    shopt -s nullglob
    for file in "$OBS_DIR"/*.md; do
      awk -v slug="$(basename "$file" .md)" '
        /^- [0-9]/ && $3 != "occurred" {
          reason = $0
          sub(/^[^:]*: /, "", reason)
          printf "%s\t%s\t%s\t%s\n", slug, $2, $3, reason
        }
      ' "$file"
    done
    ;;
  show)
    [ "$#" -eq 2 ] || usage
    validate_slug "$2"
    require_file "$2"
    cat "$OBS_DIR/$2.md"
    ;;
  record)
    [ "$#" -eq 5 ] || usage
    slug="$2"; session_id="$3"; summary=$(single_line "$4"); note=$(single_line "$5")
    validate_slug "$slug"
    validate_session_id "$session_id"
    file="$OBS_DIR/$slug.md"
    # 同じslugを並行セッションが同時に新規作成した場合に、後発がヘッダで上書きしないようにする
    ( set -C; printf -- '---\nsummary: %s\n---\n\n## 記録\n\n' "$summary" > "$file" ) 2>/dev/null || true
    printf -- '- %s occurred session=%s: %s (cwd=%s)\n' "$(date +%Y-%m-%d)" "$session_id" "$note" "$PWD" >> "$file"
    ;;
  decide)
    [ "$#" -eq 5 ] || usage
    slug="$2"; session_id="$3"; decision="$4"; reason=$(single_line "$5")
    validate_slug "$slug"
    validate_session_id "$session_id"
    case "$decision" in
      adopted|rejected|dismissed) ;;
      *) echo "invalid decision: $decision" >&2; exit 1 ;;
    esac
    require_file "$slug"
    printf -- '- %s %s session=%s: %s\n' "$(date +%Y-%m-%d)" "$decision" "$session_id" "$reason" >> "$OBS_DIR/$slug.md"
    ;;
  *)
    usage
    ;;
esac
