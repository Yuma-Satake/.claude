#!/usr/bin/env bash
# hunk-open-pr: GitHub PRのURLからowner/repo/PR番号を解析し、ワークスペース内の対応するローカルリポジトリ
# （root/submodule/その兄弟worktree）を特定して、PRのhead/baseをfetchし、Hunk diffペインの
# 起動/リロード/再起動までを1回のBash呼び出しで行う。判定根拠・分岐理由はここに書く
# （SKILL.md側に置くとスキル呼び出しごとにコンテキストへ載るため）。
#
# 使い方:
#   hunk_open_pr.sh --pr-url <url> [--dry-run]
#
# --pr-url: 対象PRのURL（https://github.com/<owner>/<repo>/pull/<number> の形式）。
# --dry-run: ペイン操作を行わず、解決した target_dir / diff_spec のみ出力する（検証用）。
#
# 標準出力の最後の1行が最終ステータス（例: "hunk: opened /path (PR #161)"）。呼び出し元はこの1行のみを報告する。
#
# PRのdiffはGitHubのPR差分表示と同じ「merge-base(base, head)からheadへの差分」で再現する必要があるため、
# git diffのtriple-dot記法（base_sha...head_sha）を使う（two-dotはmerge-baseを考慮せず両ブランチの
# 単純比較になり、baseが進んでいる場合にPR本来のdiffと異なる余計な差分が混入する）。

set -uo pipefail

STATUS_NOT_HERDR="hunk: skipped (not herdr)"
STATUS_INVALID_URL="hunk: failed (invalid PR URL)"
STATUS_REPO_NOT_FOUND="hunk: failed (local repo not found)"
STATUS_GH_FAILED="hunk: failed (gh pr view failed)"
STATUS_FETCH_FAILED="hunk: failed (fetch failed)"
STATUS_NO_DIFF="hunk: failed (no diff to show)"
STATUS_PANE_BUSY="hunk: skipped (pane busy)"
STATUS_LAUNCH_FAIL="hunk: failed (launch not confirmed)"
STATUS_SESSION_NOT_FOUND="hunk: failed (session not found)"
STATUS_RELOAD_FAIL="hunk: failed (reload failed)"
STATUS_STOP_FAIL="hunk: failed (stop not confirmed)"
STATUS_RESTART_FAIL="hunk: failed (restart not confirmed)"
STATUS_WORKTREE_MISMATCH="hunk: failed (worktree mismatch)"

fail() { echo "$1"; exit 0; }

pr_url=""
dry_run=0

while [ $# -gt 0 ]; do
  case "$1" in
    --pr-url) pr_url="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ "${HERDR_ENV:-}" != "1" ]; then
  fail "$STATUS_NOT_HERDR"
fi

if [[ ! "$pr_url" =~ github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
  fail "$STATUS_INVALID_URL"
fi
owner="${BASH_REMATCH[1]}"
repo="${BASH_REMATCH[2]}"
pr_number="${BASH_REMATCH[3]}"
owner_repo_lc="$(printf '%s/%s' "$owner" "$repo" | tr '[:upper:]' '[:lower:]')"

physical_path() {
  ( cd "$1" 2>/dev/null && pwd -P )
}

# ssh形式（git@github.com:owner/repo.git）とhttps形式（https://github.com/owner/repo.git）の
# どちらでも"owner/repo"部分だけを取り出して比較できるようにする。
normalize_owner_repo() {
  local url="$1" rest
  rest="${url#*github.com:}"
  [ "$rest" = "$url" ] && rest="${url#*github.com/}"
  rest="${rest%.git}"
  printf '%s' "$rest" | tr '[:upper:]' '[:lower:]'
}

submodule_paths() {
  local repo_dir="$1"
  [ -f "$repo_dir/.gitmodules" ] || return 0
  git -C "$repo_dir" config --file .gitmodules --get-regexp path 2>/dev/null | awk '{print $2}'
}

# cwdがsubmodule内部の場合、超プロジェクト（ワークスペースroot）を辿って戻す。
# rev-parse --show-toplevelだけだとsubmoduleのrootで止まり、他submoduleを候補に含められない。
find_workspace_root() {
  local cwd_root sp_root
  cwd_root="$(git rev-parse --show-toplevel 2>/dev/null)"
  [ -z "$cwd_root" ] && return 1
  sp_root="$(git -C "$cwd_root" rev-parse --show-superproject-working-tree 2>/dev/null)"
  if [ -n "$sp_root" ]; then
    physical_path "$sp_root"
  else
    physical_path "$cwd_root"
  fi
}

collect_repo_dirs() {
  local base="$1" sp subpath
  physical_path "$base"
  while IFS= read -r sp; do
    [ -z "$sp" ] && continue
    subpath="$base/$sp"
    git -C "$subpath" rev-parse --show-toplevel >/dev/null 2>&1 || continue
    physical_path "$subpath"
  done < <(submodule_paths "$base")
}

collect_worktrees() {
  local repo_dir="$1"
  git -C "$repo_dir" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10)}'
}

# selected以外の候補を最終ステータス行向けに注記する。候補が無ければ空文字。
build_other_note() {
  local selected="$1"; shift
  local others=() c joined
  for c in "$@"; do
    [ "$c" = "$selected" ] && continue
    others+=("$c")
  done
  [ "${#others[@]}" -eq 0 ] && return 0
  joined="$(printf '%s, ' "${others[@]}")"
  printf ' (他にも一致するローカルリポジトリあり、未使用: %s)' "${joined%, }"
}

workspace_root="$(find_workspace_root)"
if [ -z "$workspace_root" ]; then
  fail "$STATUS_REPO_NOT_FOUND"
fi

candidates=()
while IFS= read -r c; do [ -n "$c" ] && candidates+=("$c"); done < <(collect_repo_dirs "$workspace_root")

# root自身・各submoduleそれぞれについて、兄弟worktree（feature branch用の別チェックアウト等）も候補に含める。
extra=()
for c in "${candidates[@]}"; do
  while IFS= read -r wt; do
    [ -z "$wt" ] && continue
    # submoduleの主worktreeは`git worktree list`がgitdir自体を返すことがあるため、
    # 生のパスではなくshow-toplevelで解決した実際のworktreeパスを使う。
    resolved="$(git -C "$wt" rev-parse --show-toplevel 2>/dev/null)"
    [ -z "$resolved" ] && resolved="$wt"
    p="$(physical_path "$resolved")"
    [ -n "$p" ] && extra+=("$p")
  done < <(collect_worktrees "$c")
done
candidates+=("${extra[@]}")
if [ "${#candidates[@]}" -gt 0 ]; then
  mapfile -t candidates < <(printf '%s\n' "${candidates[@]}" | sort -u)
fi

matches=()
for c in "${candidates[@]}"; do
  remote_url="$(git -C "$c" remote get-url origin 2>/dev/null)" || continue
  [ -z "$remote_url" ] && continue
  [ "$(normalize_owner_repo "$remote_url")" = "$owner_repo_lc" ] && matches+=("$c")
done

if [ "${#matches[@]}" -eq 0 ]; then
  fail "$STATUS_REPO_NOT_FOUND"
fi

target_dir=""
other_note=""
if [ "${#matches[@]}" -eq 1 ]; then
  target_dir="${matches[0]}"
else
  # 複数一致した場合、feature用の兄弟worktree（ディレクトリ名にサフィックスが付く）より
  # リポジトリ名そのままのメインチェックアウトを優先する。
  repo_lc="$(printf '%s' "$repo" | tr '[:upper:]' '[:lower:]')"
  for c in "${matches[@]}"; do
    if [ "$(basename "$c" | tr '[:upper:]' '[:lower:]')" = "$repo_lc" ]; then
      target_dir="$c"
      break
    fi
  done
  [ -z "$target_dir" ] && target_dir="${matches[0]}"
  other_note="$(build_other_note "$target_dir" "${matches[@]}")"
fi

if ! git -C "$target_dir" fetch origin "pull/${pr_number}/head" >/dev/null 2>&1; then
  fail "$STATUS_FETCH_FAILED"
fi
head_sha="$(git -C "$target_dir" rev-parse FETCH_HEAD 2>/dev/null)"
if [ -z "$head_sha" ]; then
  fail "$STATUS_FETCH_FAILED"
fi

pr_json="$(gh pr view "$pr_number" --repo "${owner}/${repo}" --json baseRefName 2>/dev/null)"
if [ -z "$pr_json" ]; then
  fail "$STATUS_GH_FAILED"
fi
base_ref_name="$(jq -r '.baseRefName // empty' <<< "$pr_json")"
if [ -z "$base_ref_name" ]; then
  fail "$STATUS_GH_FAILED"
fi

if ! git -C "$target_dir" fetch origin "$base_ref_name" >/dev/null 2>&1; then
  fail "$STATUS_FETCH_FAILED"
fi
base_sha="$(git -C "$target_dir" rev-parse "origin/${base_ref_name}" 2>/dev/null)"
if [ -z "$base_sha" ]; then
  fail "$STATUS_FETCH_FAILED"
fi

diff_spec="${base_sha}...${head_sha}"

if [ "$dry_run" -eq 1 ]; then
  echo "target_dir=$target_dir"
  echo "diff_spec=$diff_spec"
  echo "other_note=$other_note"
  exit 0
fi

if git -C "$target_dir" diff --quiet "$diff_spec" 2>/dev/null; then
  fail "$STATUS_NO_DIFF"
fi

pr_label="(PR #${pr_number})"

# --- 以下、herdr/hunkのペイン管理（hunk-openスキルと同一。会話コンテキストは不要） ---

# $1: 最大リトライ回数（初回チェックは含まない）、$2以降: 真偽を返すチェックコマンド。
poll() {
  local max="$1"; shift
  "$@" && return 0
  local i
  for ((i = 0; i < max; i++)); do
    sleep 1
    "$@" && return 0
  done
  return 1
}

layout_json="$(herdr pane layout --pane "$HERDR_PANE_ID")"
self_x="$(jq -r --arg id "$HERDR_PANE_ID" '.result.layout.panes[] | select(.pane_id == $id) | .rect.x' <<< "$layout_json")"
right_pane_id="$(jq -r --argjson x "$self_x" '[.result.layout.panes[] | select(.rect.x > $x)] | sort_by(.rect.x) | .[0].pane_id // empty' <<< "$layout_json")"

target_dir_q="$(printf '%q' "$target_dir")"

if [ -z "$right_pane_id" ]; then
  split_json="$(herdr pane split --current --direction right --cwd "$target_dir" --no-focus)"
  pane_id="$(jq -r '.result.pane.pane_id' <<< "$split_json")"
  herdr pane run "$pane_id" "hunk diff $diff_spec" >/dev/null

  check_launched() {
    jq -e '.result.process_info.foreground_processes[]? | select(.argv0 == "hunk")' >/dev/null 2>&1 \
      <<< "$(herdr pane process-info --pane "$pane_id")"
  }
  if poll 3 check_launched; then
    fail "hunk: opened $target_dir $pr_label$other_note"
  else
    fail "$STATUS_LAUNCH_FAIL"
  fi
fi

pane_id="$right_pane_id"
proc_json="$(herdr pane process-info --pane "$pane_id")"
if ! jq -e '.result.process_info.foreground_processes[]? | select(.argv0 == "hunk")' >/dev/null 2>&1 <<< "$proc_json"; then
  # hunkが前面にいない: シェルのプロンプトが空いているだけ（idle）なら、そこへ直接起動する。
  # zsh/bash等以外の前面プロセスが動いている場合のみ本当のbusyとみなす。
  if ! jq -e '[.result.process_info.foreground_processes[]?.argv0] | all(. as $a | ["zsh","bash","sh","dash","ksh","fish"] | index($a) != null)' \
      >/dev/null 2>&1 <<< "$proc_json"; then
    fail "$STATUS_PANE_BUSY"
  fi

  herdr pane run "$pane_id" "cd -- $target_dir_q && hunk diff $diff_spec" >/dev/null
  check_launched() {
    jq -e '.result.process_info.foreground_processes[]? | select(.argv0 == "hunk")' >/dev/null 2>&1 \
      <<< "$(herdr pane process-info --pane "$pane_id")"
  }
  if poll 3 check_launched; then
    fail "hunk: opened $target_dir $pr_label$other_note"
  else
    fail "$STATUS_LAUNCH_FAIL"
  fi
fi

hunk_pid="$(jq -r '.result.process_info.foreground_processes[] | select(.argv0 == "hunk") | .pid' <<< "$proc_json" | head -1)"
tty_name="/dev/$(ps -p "$hunk_pid" -o tty= | tr -d ' ')"

session_list_json="$(hunk session list --json)"
session_id="$(jq -r --arg tty "$tty_name" \
  '.sessions[] | select(.terminal.locations[]?.source == "tty" and .terminal.locations[]?.tty == $tty) | .sessionId' \
  <<< "$session_list_json" | head -1)"
if [ -z "$session_id" ]; then
  fail "$STATUS_SESSION_NOT_FOUND"
fi
session_repo_root="$(jq -r --arg id "$session_id" '.sessions[] | select(.sessionId == $id) | .repoRoot' <<< "$session_list_json")"
session_repo_root_norm="$(physical_path "$session_repo_root")"

if [ -n "$session_repo_root_norm" ] && [ "$session_repo_root_norm" = "$target_dir" ]; then
  if ! hunk session reload "$session_id" -- diff "$diff_spec" >/dev/null 2>&1; then
    fail "$STATUS_RELOAD_FAIL"
  fi
  fail "hunk: reloaded $target_dir $pr_label$other_note"
fi

# worktreeが不一致: 同じ右側ペインで対象ディレクトリからHunkを再起動する。
herdr pane send-keys "$pane_id" 'ctrl+c' >/dev/null

check_stopped() {
  ! jq -e '.result.process_info.foreground_processes[]? | select(.argv0 == "hunk")' >/dev/null 2>&1 \
    <<< "$(herdr pane process-info --pane "$pane_id")"
}
if ! poll 3 check_stopped; then
  fail "$STATUS_STOP_FAIL"
fi

herdr pane run "$pane_id" "cd -- $target_dir_q && hunk diff $diff_spec" >/dev/null

check_restarted() {
  jq -e '.result.process_info.foreground_processes[]? | select(.argv0 == "hunk")' >/dev/null 2>&1 \
    <<< "$(herdr pane process-info --pane "$pane_id")"
}
if ! poll 3 check_restarted; then
  fail "$STATUS_RESTART_FAIL"
fi

new_session_repo_root=""
check_new_session() {
  local list nid
  list="$(hunk session list --json)"
  nid="$(jq -r --arg tty "$tty_name" --arg old "$session_id" \
    '.sessions[] | select(.terminal.locations[]?.source == "tty" and .terminal.locations[]?.tty == $tty and .sessionId != $old) | .sessionId' \
    <<< "$list" | head -1)"
  [ -z "$nid" ] && return 1
  new_session_repo_root="$(jq -r --arg id "$nid" '.sessions[] | select(.sessionId == $id) | .repoRoot' <<< "$list")"
  return 0
}
if ! poll 3 check_new_session; then
  fail "$STATUS_SESSION_NOT_FOUND"
fi

new_root_norm="$(physical_path "$new_session_repo_root")"
if [ -z "$new_root_norm" ] || [ "$new_root_norm" != "$target_dir" ]; then
  fail "$STATUS_WORKTREE_MISMATCH"
fi
fail "hunk: reopened $target_dir $pr_label$other_note"
