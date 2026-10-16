#!/bin/bash
# 再発性の判定で見送った知見候補を、セッションを跨いで蓄積・照合する
# サブコマンド:
#   list                                              全候補を1行ずつ出す（slug / status / 発生セッション数 / 最終発生日 / summary）
#   show <slug>                                       候補の内容を出す
#   record <slug> <session-id> <summary> <note>       発生を記録する。候補がなければsummaryで新規作成する
#   reject <slug> <reason>                            ユーザーが反映を却下した候補として記録する
#   resolve <slug>                                    rules・skills等へ反映済みの候補を削除する
set -euo pipefail

OBS_DIR="$HOME/.claude/state/knowledge-review/observations"
mkdir -p "$OBS_DIR"

usage() {
  echo "usage: observations.sh <list|show|record|reject|resolve> [args...]" >&2
  exit 1
}

subcommand="${1:-}"
[ -n "$subcommand" ] || usage

# slugはファイル名に使うため英小文字・数字・ハイフンのみに制限する
validate_slug() {
  if ! [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "invalid slug: $1" >&2
    exit 1
  fi
}

# 改行を含む引数で発生記録の1行1件の形式が崩れないようにする
single_line() {
  printf '%s' "$1" | tr '\n\r' '  '
}

case "$subcommand" in
  list)
    shopt -s nullglob
    for file in "$OBS_DIR"/*.md; do
      slug=$(basename "$file" .md)
      summary=$(sed -n 's/^summary: //p' "$file" | head -n 1)
      status=$(sed -n 's/^status: //p' "$file" | head -n 1)
      sessions=$(grep -o 'session=[^ ]*' "$file" | sort -u | wc -l | tr -d ' ')
      last_date=$(grep '^- [0-9]' "$file" | tail -n 1 | cut -d' ' -f2)
      printf '%s\t%s\t%s\t%s\t%s\n' "$slug" "$status" "$sessions" "$last_date" "$summary"
    done
    ;;
  show)
    slug="${2:-}"
    [ -n "$slug" ] || usage
    validate_slug "$slug"
    cat "$OBS_DIR/$slug.md"
    ;;
  record)
    [ "$#" -eq 5 ] || usage
    slug="$2"; session_id="$3"; summary=$(single_line "$4"); note=$(single_line "$5")
    validate_slug "$slug"
    file="$OBS_DIR/$slug.md"
    if [ ! -f "$file" ]; then
      printf -- '---\nsummary: %s\nstatus: pending\n---\n\n## 発生記録\n\n' "$summary" > "$file"
    fi
    printf -- '- %s session=%s cwd=%s: %s\n' "$(date +%Y-%m-%d)" "$session_id" "$PWD" "$note" >> "$file"
    ;;
  reject)
    [ "$#" -eq 3 ] || usage
    slug="$2"; reason=$(single_line "$3")
    validate_slug "$slug"
    file="$OBS_DIR/$slug.md"
    [ -f "$file" ] || { echo "not found: $slug" >&2; exit 1; }
    tmp=$(mktemp)
    sed 's/^status: .*/status: rejected/' "$file" > "$tmp" && mv "$tmp" "$file"
    printf -- '- %s rejected: %s\n' "$(date +%Y-%m-%d)" "$reason" >> "$file"
    ;;
  resolve)
    slug="${2:-}"
    [ -n "$slug" ] || usage
    validate_slug "$slug"
    rm -f "$OBS_DIR/$slug.md"
    ;;
  *)
    usage
    ;;
esac
