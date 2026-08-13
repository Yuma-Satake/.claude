#!/usr/bin/env bash
# hunk-check: 現在のworktreeに一致するライブHunkセッションとユーザーコメントを収集する。
# SKILL.mdの「実行時コンテキスト」`!`前処理ブロックから呼ばれる。
# 判定根拠・出力形式の理由はここに書く（SKILL.md側に置くと呼び出しごとにコンテキストへ載るため）。
#
# 出力（標準出力、この形式は前処理注入の互換性のため変更不可）:
#   repoRoot: <path>
#   matchingSessionCount: <n>
#   (n>0の場合、マッチした各セッションについて)
#   sessionId: <id>
#   title: <title>
#   userComments: <json>
#   (n==0の場合のみ追加。他worktree・他リポジトリの候補セッションを列挙するが選択は行わない)
#   otherSessionCount: <m>
#   (各候補について)
#   otherSessionId: <id>
#   otherSessionRepoRoot: <repoRoot>
#   otherSessionTitle: <title>
#   otherSessionSourceLabel: <sourceLabel>
#   otherSessionFileCount: <fileCount>
#   エラー時は error: <code> 行（該当する場合は直前にrepoRoot、直後にdetail）
#
# set -e を使わない: 各分岐がprintfで出力してexit 0するため、-eで途中終了すると
# 出力が欠落したまま前処理へ注入される。cdもしない: git rev-parse --show-toplevel は
# 呼び出し元（skill実行時）のcwdに依存するため、ここでcdすると解決先が変わる。
set -uo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$repo_root" ]; then
  printf '%s\n' 'error: not-git-repository'
  exit 0
fi

if ! session_list="$(hunk session list --json 2>&1)"; then
  printf 'repoRoot: %s\nerror: hunk-session-list-failed\ndetail: %s\n' "$repo_root" "$session_list"
  exit 0
fi

if ! matching_sessions="$(printf '%s' "$session_list" | jq -c --arg root "$repo_root" '[.sessions[] | select(.repoRoot == $root) | {sessionId, title}]' 2>&1)"; then
  printf 'repoRoot: %s\nerror: invalid-hunk-session-list\ndetail: %s\n' "$repo_root" "$matching_sessions"
  exit 0
fi

matching_count="$(printf '%s' "$matching_sessions" | jq 'length')"
printf 'repoRoot: %s\nmatchingSessionCount: %s\n' "$repo_root" "$matching_count"

tab="$(printf '\t')"
printf '%s' "$matching_sessions" | jq -r '.[] | [.sessionId, .title] | @tsv' |
while IFS="$tab" read -r session_id title; do
  if user_comments="$(hunk session comment list "$session_id" --type user --json 2>&1)"; then
    printf 'sessionId: %s\ntitle: %s\nuserComments: %s\n' "$session_id" "$title" "$user_comments"
  else
    printf 'sessionId: %s\ntitle: %s\nerror: hunk-comment-list-failed\ndetail: %s\n' "$session_id" "$title" "$user_comments"
  fi
done

# matchingSessionCountが0の場合だけ、他worktree・他リポジトリの候補セッションを列挙する。
# スタックPR（`gh stack`等）の子ブランチ用に軽量worktreeを追加している場合、親ブランチの
# worktreeに紐づく既存セッションのdiff表示先が `hunk session reload -- diff <base>...<head>`
# で子ブランチとの差分へリダイレクトされて使われていることがある。ただし`hunk session list --json`
# にdiffのsource/targetを示す構造化フィールドは無く、title/sourceLabelは表示用文字列に過ぎない。
# 「どのセッションが現在のブランチの差分を表示しているか」を文字列一致等で自動判定すると、
# 誤判定時に無関係なworktreeのコメントを黙って回収し、それに基づいてコードを書き換えてしまう
# リスクがあるため、自動選択はせず候補列挙のみ行い判断はLLMに委ねる。
if [ "$matching_count" -eq 0 ]; then
  other_sessions="$(printf '%s' "$session_list" | jq -c --arg root "$repo_root" '[.sessions[] | select(.repoRoot != $root)]')"
  other_count="$(printf '%s' "$other_sessions" | jq 'length')"
  printf 'otherSessionCount: %s\n' "$other_count"
  printf '%s' "$other_sessions" | jq -r '.[] | [.sessionId, .repoRoot, .title, (.sourceLabel // ""), (.fileCount // 0)] | @tsv' |
  while IFS="$tab" read -r o_id o_root o_title o_source o_filecount; do
    printf 'otherSessionId: %s\notherSessionRepoRoot: %s\notherSessionTitle: %s\notherSessionSourceLabel: %s\notherSessionFileCount: %s\n' \
      "$o_id" "$o_root" "$o_title" "$o_source" "$o_filecount"
  done
fi
