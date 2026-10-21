#!/bin/bash
# knowledge-reviewの知見候補の発生とユーザーの判断を、セッションを跨いで蓄積・照合する
# 並行セッションから同時に操作されても記録が失われないよう、候補ファイルは完成した状態で公開し、公開後の書き込みは追記のみとする
# サブコマンド:
#   list <session-id>     全候補を1行ずつ、タブ区切りで出す。発生と判断は指定したセッションの分を除いて集計する
#                         列: slug / status / 過去の発生セッション数 / 最終発生日 / verdict / 直近の判断理由 / summary
#   show <slug>           候補の記録をすべて出す
#   apply <session-id>    標準入力の各行を記録する。1行は「slug・summary・note・decision・reason」のタブ区切り
#                         候補がなければsummaryで新規作成し、あればsummaryは使わない
#                         タブの連続は1つにまとめて読むため、全項目に空ではない値を入れる。判断がない場合はdecisionとreasonを「-」とする
set -euo pipefail

OBS_DIR="$HOME/.claude/state/knowledge-review/observations"

# 記録行は「- <日付> <種別> session=<id>: <本文>」の形式で、種別が発生以外の行は判断を表す
KIND_OCCURRED="occurred"
STATUS_PENDING="pending"
DECISION_ADOPTED="adopted"
DECISION_REJECTED="rejected"
VALID_DECISIONS="$DECISION_ADOPTED $DECISION_REJECTED"
NO_VALUE="-"

# verdictは、過去の記録だけから決まる再発性の扱いを表す
VERDICT_PROMOTE="promote"
VERDICT_RECHECK="recheck"
VERDICT_SKIP="skip"
VERDICT_NONE="none"

# 過去にこの数以上のセッションで発生していれば再発とみなす
MIN_PAST_SESSIONS_FOR_PROMOTE=1

usage() {
  echo "usage: observations.sh <list|show|apply> [args...]" >&2
  exit 1
}

# slugはファイル名に使うため使える文字を制限する
validate_slug() {
  if ! [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "invalid slug: $1" >&2
    exit 1
  fi
}

# 空のIDは別々のセッションを1つに数えてしまい、空白を含むIDは記録行のフィールド分割を壊す
validate_session_id() {
  if ! [[ "$1" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "invalid session-id: $1" >&2
    exit 1
  fi
}

validate_decision() {
  if [[ " $VALID_DECISIONS " != *" $1 "* ]]; then
    echo "invalid decision: $1" >&2
    exit 1
  fi
}

# 記録の1行1件・listのタブ区切りの形式が崩れないようにする
single_line() {
  printf '%s' "$1" | tr '\n\r\t' '   '
}

candidate_exists() {
  [ -f "$OBS_DIR/$1.md" ]
}

create_candidate() {
  local slug="$1" summary="$2"
  local file="$OBS_DIR/$slug.md" tmp
  mkdir -p "$OBS_DIR"
  # ヘッダを書き終えたファイルをlnで公開する。lnは既存の候補を上書きせず、公開前のファイルへ他セッションが追記することもない
  tmp=$(mktemp "$OBS_DIR/.new.XXXXXX")
  printf -- '---\nsummary: %s\n---\n\n## 記録\n\n' "$summary" > "$tmp"
  ln "$tmp" "$file" 2>/dev/null || [ -f "$file" ] || { rm -f "$tmp"; echo "failed to create: $slug" >&2; exit 1; }
  rm -f "$tmp"
}

record_occurrence() {
  local slug="$1" session_id="$2" note="$3"
  printf -- '- %s %s session=%s: %s\n' "$(date +%Y-%m-%d)" "$KIND_OCCURRED" "$session_id" "$note" >> "$OBS_DIR/$slug.md"
}

record_decision() {
  local slug="$1" session_id="$2" decision="$3" reason="$4"
  printf -- '- %s %s session=%s: %s\n' "$(date +%Y-%m-%d)" "$decision" "$session_id" "$reason" >> "$OBS_DIR/$slug.md"
}

subcommand="${1:-}"
[ -n "$subcommand" ] || usage

case "$subcommand" in
  list)
    [ "$#" -eq 2 ] || usage
    session_id="$2"
    validate_session_id "$session_id"
    shopt -s nullglob
    for file in "$OBS_DIR"/*.md; do
      awk -v slug="$(basename "$file" .md)" -v current="session=$session_id" \
        -v occurred="$KIND_OCCURRED" -v pending="$STATUS_PENDING" -v adopted="$DECISION_ADOPTED" -v no_value="$NO_VALUE" \
        -v promote="$VERDICT_PROMOTE" -v recheck="$VERDICT_RECHECK" -v skip="$VERDICT_SKIP" -v no_verdict="$VERDICT_NONE" \
        -v min_sessions="$MIN_PAST_SESSIONS_FOR_PROMOTE" '
        /^summary: / { summary = $0; sub(/^summary: /, "", summary) }
        /^- [0-9]/ && $4 != current ":" {
          if ($3 == occurred) {
            last_date = $2
            if (!($4 in seen)) { seen[$4] = 1; sessions++ }
          } else {
            status = $3
            reason = $0
            sub(/^[^:]*: /, "", reason)
          }
        }
        END {
          if (status == "") status = pending
          if (reason == "") reason = no_value
          if (last_date == "") last_date = no_value
          if (status != pending) verdict = (status == adopted ? recheck : skip)
          else verdict = (sessions >= min_sessions ? promote : no_verdict)
          printf "%s\t%s\t%d\t%s\t%s\t%s\t%s\n", slug, status, sessions, last_date, verdict, reason, summary
        }
      ' "$file"
    done
    ;;
  show)
    [ "$#" -eq 2 ] || usage
    validate_slug "$2"
    if ! candidate_exists "$2"; then
      echo "not found: $2" >&2
      exit 1
    fi
    cat "$OBS_DIR/$2.md"
    ;;
  apply)
    [ "$#" -eq 2 ] || usage
    session_id="$2"
    validate_session_id "$session_id"
    slugs=(); summaries=(); notes=(); decisions=(); reasons=()
    # 末尾に改行がない最終行も読む
    while IFS=$'\t' read -r slug summary note decision reason extra || [ -n "$slug" ]; do
      [ -n "$slug" ] || continue
      if [ -z "$reason" ] || [ -n "${extra:-}" ]; then
        echo "invalid line (every field must be non-empty and the line must have 5 fields): $slug" >&2
        exit 1
      fi
      validate_slug "$slug"
      if [ "$decision" = "$NO_VALUE" ]; then
        if [ "$reason" != "$NO_VALUE" ]; then
          echo "reason without decision: $slug" >&2
          exit 1
        fi
      else
        validate_decision "$decision"
      fi
      slugs+=("$slug"); summaries+=("$(single_line "$summary")"); notes+=("$(single_line "$note")")
      decisions+=("$decision"); reasons+=("$(single_line "$reason")")
    done
    # 途中の行の不備で一部だけ記録される状態を避けるため、書き込みは全行の検証後に行う
    for i in "${!slugs[@]}"; do
      if ! candidate_exists "${slugs[$i]}"; then
        create_candidate "${slugs[$i]}" "${summaries[$i]}"
      fi
      record_occurrence "${slugs[$i]}" "$session_id" "${notes[$i]}"
      if [ "${decisions[$i]}" != "$NO_VALUE" ]; then
        record_decision "${slugs[$i]}" "$session_id" "${decisions[$i]}" "${reasons[$i]}"
      fi
    done
    ;;
  *)
    usage
    ;;
esac
