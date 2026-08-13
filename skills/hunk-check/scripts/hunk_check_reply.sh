#!/usr/bin/env bash
# hunk-check: 元のユーザーコメント1件に対する返信注記（対応済み注記/説明注記）を追加する。
# author固定・source-note付与・newRange/oldRangeの先頭選択・重複チェックをここで行う。
# summary/rationaleの文言そのもの（`対応済み: <...>`/`説明: <...>`の書式、書いてはいけない内容）は
# LLMがSKILL.md側の指示に従って判断・生成し、そのまま引数として渡す。
#
# 使い方:
#   hunk_check_reply.sh --session <id> --file <path> --note-id <noteId> \
#     [--new-range-start <n>] [--old-range-start <n>] \
#     --summary <text> --rationale <text> [--dry-run]
#
# --note-id: 返信対象の元コメントのnoteId（`hunk session comment list --type user --json`のnoteId）。
# --new-range-start / --old-range-start: 元コメントのnewRange/oldRangeの先頭行。両方渡された場合は
#   --new-range-start を優先する（newRangeがあれば新側の行を使うというHunkの表示側の扱いに合わせる）。
#   少なくとも一方が必須。
# --rationale: 空文字列も許容する（説明が無いケース）。source-noteタグは常にこちらで先頭に付与するため
#   呼び出し側でsource-noteを含めてはならない。
# --dry-run: comment addを実行せず、重複判定の結果（would-add/would-skip）のみ出力する（検証用）。
#
# 重複チェック根拠: `comment list`はaddしたsummary/rationaleを`body`へ"<summary>\n\n<rationale>"の形で
# 結合して返す（実測確認済み）。既存コメントのうちauthorが"hunk-check"かつbodyに同じ
# "source-note: <noteId>"を含むものがあれば、同じ元コメントへの返信を既に追加済みと判断しno-opにする。
#
# 標準出力の最後の1行が最終ステータス。呼び出し元はこの1行のみを報告する。

set -uo pipefail

STATUS_MISSING_ARG="hunk-check-reply: failed (missing argument)"
STATUS_LIST_FAILED="hunk-check-reply: failed (list)"
STATUS_ADD_FAILED="hunk-check-reply: failed (add)"
STATUS_DUPLICATE="hunk-check-reply: skipped (duplicate)"
STATUS_DRY_DUPLICATE="hunk-check-reply: would-skip (duplicate)"

fail() { echo "$1"; exit 0; }

session_id=""
file_path=""
note_id=""
new_range_start=""
old_range_start=""
summary=""
rationale=""
dry_run=0

while [ $# -gt 0 ]; do
  case "$1" in
    --session) session_id="$2"; shift 2 ;;
    --file) file_path="$2"; shift 2 ;;
    --note-id) note_id="$2"; shift 2 ;;
    --new-range-start) new_range_start="$2"; shift 2 ;;
    --old-range-start) old_range_start="$2"; shift 2 ;;
    --summary) summary="$2"; shift 2 ;;
    --rationale) rationale="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$session_id" ] || [ -z "$file_path" ] || [ -z "$note_id" ] || [ -z "$summary" ]; then
  fail "$STATUS_MISSING_ARG"
fi
if [ -z "$new_range_start" ] && [ -z "$old_range_start" ]; then
  fail "$STATUS_MISSING_ARG"
fi

tag="source-note: $note_id"
if [ -n "$rationale" ]; then
  full_rationale="$tag"$'\n'"$rationale"
else
  full_rationale="$tag"
fi

existing="$(hunk session comment list "$session_id" --type all --json 2>&1)" || fail "$STATUS_LIST_FAILED"
if jq -e --arg tag "$tag" '.comments[]? | select(.author == "hunk-check" and (.body | contains($tag)))' \
    >/dev/null 2>&1 <<< "$existing"; then
  if [ "$dry_run" -eq 1 ]; then
    fail "$STATUS_DRY_DUPLICATE"
  fi
  fail "$STATUS_DUPLICATE"
fi

if [ -n "$new_range_start" ]; then
  line_args=(--new-line "$new_range_start")
else
  line_args=(--old-line "$old_range_start")
fi

if [ "$dry_run" -eq 1 ]; then
  fail "hunk-check-reply: would-add (${line_args[0]} ${line_args[1]})"
fi

add_json="$(hunk session comment add "$session_id" --file "$file_path" "${line_args[@]}" \
  --summary "$summary" --rationale "$full_rationale" --author "hunk-check" --json 2>&1)" || fail "$STATUS_ADD_FAILED"

comment_id="$(jq -r '.result.commentId // empty' <<< "$add_json")"
if [ -z "$comment_id" ]; then
  fail "$STATUS_ADD_FAILED"
fi
fail "hunk-check-reply: added $comment_id"
