#!/usr/bin/env bash
# hunk-open: 差分対象リポジトリの解決とHunk diffペインの起動/リロード/再起動を1回のBash呼び出しで行う。
# 判定根拠・分岐理由はここに書く（SKILL.md側に置くとスキル呼び出しごとにコンテキストへ載るため）。
#
# 使い方:
#   hunk_open.sh [--changed-file <path> ...] [--worktree <path>] [--task-start-ref <ref>] [--dry-run]
#
# --changed-file: 会話内で実際に編集・作成・削除したファイルのパス（複数回指定可）。最優先の情報源。
# --worktree: 変更ファイルが不明で作業worktreeだけが明示されている場合のそのパス。
# --task-start-ref: 対象リポジトリの作業ツリーがcleanで、かつ会話内の記録からこのタスク中に
#                    対象リポジトリへ複数コミットしたと確認できる場合の、タスク開始時点のHEAD。
#                    省略時や対象リポジトリに存在しない場合はHEAD~1にフォールバックする。
# --dry-run: ペイン操作を行わず、解決した target_dir / diff_base のみ出力する（検証用）。
#
# 標準出力の最後の1行が最終ステータス（例: "hunk: opened /path"）。呼び出し元はこの1行のみを報告する。
#
# 複数リポジトリに変更がある場合、Hunkは1ペインに1リポジトリしか表示できないため対象は1つに絞る。
# 従来はambiguousとして失敗させていたが、代わりに候補から1つを選んで表示し、残りは最終ステータス行に
# 注記する（build_other_note）。

set -uo pipefail

STATUS_NOT_HERDR="hunk: skipped (not herdr)"
STATUS_PANE_BUSY="hunk: skipped (pane busy)"
STATUS_LAUNCH_FAIL="hunk: failed (launch not confirmed)"
STATUS_TARGET_NOT_FOUND="hunk: failed (diff target not found)"
STATUS_SESSION_NOT_FOUND="hunk: failed (session not found)"
STATUS_RELOAD_FAIL="hunk: failed (reload failed)"
STATUS_STOP_FAIL="hunk: failed (stop not confirmed)"
STATUS_RESTART_FAIL="hunk: failed (restart not confirmed)"
STATUS_WORKTREE_NOT_CONFIRMED="hunk: failed (worktree not confirmed)"
STATUS_WORKTREE_MISMATCH="hunk: failed (worktree mismatch)"
STATUS_NO_DIFF="hunk: failed (no diff to show)"

fail() { echo "$1"; exit 0; }

changed_files=()
explicit_worktree=""
task_start_ref=""
dry_run=0

while [ $# -gt 0 ]; do
  case "$1" in
    --changed-file) changed_files+=("$2"); shift 2 ;;
    --worktree) explicit_worktree="$2"; shift 2 ;;
    --task-start-ref) task_start_ref="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ "${HERDR_ENV:-}" != "1" ]; then
  fail "$STATUS_NOT_HERDR"
fi

physical_path() {
  ( cd "$1" 2>/dev/null && pwd -P )
}

# 削除済みファイルなどで親ディレクトリが存在しない場合、存在する最も近い親ディレクトリまで遡る。
git_root_for_file() {
  local f="$1" dir
  dir="$(dirname -- "$f")"
  while [ ! -d "$dir" ] && [ "$dir" != "/" ] && [ "$dir" != "." ]; do
    dir="$(dirname -- "$dir")"
  done
  git -C "$dir" rev-parse --show-toplevel 2>/dev/null
}

submodule_paths() {
  local repo="$1"
  [ -f "$repo/.gitmodules" ] || return 0
  git -C "$repo" config --file .gitmodules --get-regexp path 2>/dev/null | awk '{print $2}'
}

# Hunkはsuperprojectからsubmodule内部の作業ツリー差分を展開できない。単に現在のGitルートを対象にすると
# rootには" M <submodule_path>"だけが表示され、ユーザーが実際のコード差分を見られない。
#
# さらに --ignore-submodules=dirty はsubmodule作業ツリー内の未コミット変更を無視するだけで、
# submoduleが指すコミット(gitlink)自体がrootの記録から進んでいる場合は作業ツリーがcleanでも
# " M <submodule_path>" が残る。多くのマルチリポワークスペースは「submoduleの参照コミットは
# 明示指示があるまでrootにコミットしない」運用のため、submodule単体で作業している間はrootで
# 常にこの行が現れる。これは実コードの差分ではなく参照ポインタの遅延であり、除外しないと
# 無関係なrootを候補として誤検出し続ける。ステージ済み変更・通常ファイルの変更・未追跡ファイルは
# 引き続き差分として検出する。
has_diff() {
  local repo="$1" line path status_out subpaths
  status_out="$(git -C "$repo" status --porcelain --untracked-files=all --ignore-submodules=dirty 2>/dev/null)"
  [ -z "$status_out" ] && return 1
  subpaths="$(submodule_paths "$repo")"
  if [ -z "$subpaths" ]; then
    return 0
  fi
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    path="${line:3}"
    [[ "$path" == *" -> "* ]] && path="${path#*-> }"
    if ! grep -qxF "$path" <<< "$subpaths"; then
      return 0
    fi
  done <<< "$status_out"
  return 1
}

# base配下のroot自身＋初期化済みsubmoduleのうち、未コミット差分(gitlink除く)を持つものを候補として列挙する。
collect_candidates() {
  local base="$1" sp subpath
  has_diff "$base" && physical_path "$base"
  while IFS= read -r sp; do
    [ -z "$sp" ] && continue
    subpath="$base/$sp"
    git -C "$subpath" rev-parse --show-toplevel >/dev/null 2>&1 || continue
    has_diff "$subpath" && physical_path "$subpath"
  done < <(submodule_paths "$base")
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
  printf ' (他にも変更あり、未表示: %s)' "${joined%, }"
}

target_dir=""
other_note=""

# 会話内の変更ファイルから解決する。superproject配下のsubmoduleファイルを変更した場合、対象は
# superprojectではなくそのファイルが所属するsubmoduleのGitルートになる。
if [ "${#changed_files[@]}" -gt 0 ]; then
  roots=()
  for f in "${changed_files[@]}"; do
    root="$(git_root_for_file "$f")"
    [ -n "$root" ] && roots+=("$(physical_path "$root")")
  done
  if [ "${#roots[@]}" -gt 0 ]; then
    mapfile -t roots < <(printf '%s\n' "${roots[@]}" | sort -u)
  fi
  if [ "${#roots[@]}" -eq 1 ]; then
    target_dir="${roots[0]}"
  elif [ "${#roots[@]}" -gt 1 ]; then
    # --changed-fileで最初に挙げられたファイルのリポジトリを優先して選ぶ。
    for f in "${changed_files[@]}"; do
      root="$(git_root_for_file "$f")"
      [ -z "$root" ] && continue
      target_dir="$(physical_path "$root")"
      break
    done
    other_note="$(build_other_note "$target_dir" "${roots[@]}")"
  fi
  # 0件（変更ファイルパスが解決できない）の場合は下の自動解決にフォールバックする。
fi

# 作業worktreeだけが明示され変更ファイルが不明な場合、そのworktreeについて候補収集を行う。
if [ -z "$target_dir" ] && [ -n "$explicit_worktree" ]; then
  base="$(physical_path "$explicit_worktree")"
  if [ -z "$base" ]; then
    fail "$STATUS_TARGET_NOT_FOUND"
  fi
  cands=()
  while IFS= read -r c; do [ -n "$c" ] && cands+=("$c"); done < <(collect_candidates "$base" | sort -u)
  case "${#cands[@]}" in
    1) target_dir="${cands[0]}" ;;
    0) fail "$STATUS_TARGET_NOT_FOUND" ;;
    *)
      target_dir="${cands[0]}"
      other_note="$(build_other_note "$target_dir" "${cands[@]}")"
      ;;
  esac
fi

# 会話から対象が分からない場合だけ、現在または兄弟worktreeから未コミット差分を持つリポジトリを特定する。
if [ -z "$target_dir" ]; then
  current_repo="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -z "$current_repo" ]; then
    fail "$STATUS_TARGET_NOT_FOUND"
  fi
  current_repo="$(physical_path "$current_repo")"
  cands=()
  while IFS= read -r c; do [ -n "$c" ] && cands+=("$c"); done < <(collect_candidates "$current_repo" | sort -u)
  if [ "${#cands[@]}" -eq 1 ]; then
    target_dir="${cands[0]}"
  elif [ "${#cands[@]}" -gt 1 ]; then
    target_dir="${cands[0]}"
    other_note="$(build_other_note "$target_dir" "${cands[@]}")"
  else
    all_cands=()
    while IFS= read -r wt; do
      [ -z "$wt" ] && continue
      [ "$(physical_path "$wt")" = "$current_repo" ] && continue
      while IFS= read -r c; do [ -n "$c" ] && all_cands+=("$c"); done < <(collect_candidates "$wt")
    done < <(git -C "$current_repo" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10)}')
    if [ "${#all_cands[@]}" -gt 0 ]; then
      mapfile -t all_cands < <(printf '%s\n' "${all_cands[@]}" | sort -u)
    fi
    case "${#all_cands[@]}" in
      1) target_dir="${all_cands[0]}" ;;
      0) fail "$STATUS_TARGET_NOT_FOUND" ;;
      *)
        target_dir="${all_cands[0]}"
        other_note="$(build_other_note "$target_dir" "${all_cands[@]}")"
        ;;
    esac
  fi
fi

# target_dirがsubmoduleの場合、superprojectではなくsubmodule直下でhunk diffを起動する（呼び出し側で担保済み）。

# --changed-fileが指定されている場合、clean/dirty判定をリポジトリ全体のstatusではなく
# そのファイル群のパススペックに限定する。target_dirとは無関係な既存の未追跡ファイル・
# ディレクトリ（例: .claude/worktrees/ 等の作業用残留物）がリポジトリ内に存在すると、
# 全体statusは常に非空になり「直前の作業は既にコミット済み」を正しく検出できず、
# diff_baseがHEADに固定されたまま実際には何も差分が無い（=画面に何も表示されない）
# 結果になる。渡されたファイルパスに限定すれば、この無関係な残留物に影響されない。
target_changed_rel=()
if [ "${#changed_files[@]}" -gt 0 ]; then
  for f in "${changed_files[@]}"; do
    root="$(git_root_for_file "$f")"
    [ -z "$root" ] && continue
    [ "$(physical_path "$root")" = "$target_dir" ] || continue
    rel="${f#"$root"/}"
    target_changed_rel+=("$rel")
  done
fi

# 差分ベースを決定する。target_dirの作業ツリーに未コミットの変更が無い場合、`hunk diff HEAD`は
# 常に空の差分になり、直前の作業がコミット済みであってもユーザーに何も見せられない。
diff_base="HEAD"
if [ "${#target_changed_rel[@]}" -gt 0 ]; then
  status_out="$(git -C "$target_dir" status --porcelain --untracked-files=all --ignore-submodules=dirty -- "${target_changed_rel[@]}" 2>/dev/null)"
else
  status_out="$(git -C "$target_dir" status --porcelain --untracked-files=all --ignore-submodules=dirty 2>/dev/null)"
fi
if [ -z "$status_out" ]; then
  # 作業ツリーがclean＝直前の作業は既にコミット済み。タスク中に対象へ複数コミットしている場合、
  # HEAD~1では直前1コミットしか差分に含まれずタスク全体の変更を見せられないため、
  # task_start_refが対象リポジトリに存在すればそれを使う。
  if [ -n "$task_start_ref" ] && git -C "$target_dir" rev-parse --verify -q "$task_start_ref" >/dev/null 2>&1; then
    diff_base="$task_start_ref"
  elif git -C "$target_dir" rev-parse --verify -q HEAD~1 >/dev/null 2>&1; then
    diff_base="HEAD~1"
  fi
  # 親コミットが無い場合（リポジトリ最初のコミット等）はdiff_base=HEADのままにする。
fi

if [ "$dry_run" -eq 1 ]; then
  echo "target_dir=$target_dir"
  echo "diff_base=$diff_base"
  echo "other_note=$other_note"
  exit 0
fi

# diff_base確定後も、実際にhunkへ渡した時に表示される差分が空（tracked diffも対象範囲の
# 未追跡ファイルも無い）なら、空のペインを黙って開かずここで明示的に失敗させる。
# --changed-fileが指定されていれば対象ファイルのパススペックに限定し、無関係な既存の
# 未追跡ファイルによって「差分あり」と誤検出しないようにする。
if [ "${#target_changed_rel[@]}" -gt 0 ]; then
  tracked_diff_empty=1
  git -C "$target_dir" diff --quiet "$diff_base" -- "${target_changed_rel[@]}" 2>/dev/null && tracked_diff_empty=1 || tracked_diff_empty=0
  untracked_out="$(git -C "$target_dir" ls-files --others --exclude-standard -- "${target_changed_rel[@]}" 2>/dev/null)"
else
  tracked_diff_empty=1
  git -C "$target_dir" diff --quiet "$diff_base" 2>/dev/null && tracked_diff_empty=1 || tracked_diff_empty=0
  untracked_out="$(git -C "$target_dir" ls-files --others --exclude-standard 2>/dev/null)"
fi
if [ "$tracked_diff_empty" -eq 1 ] && [ -z "$untracked_out" ]; then
  fail "$STATUS_NO_DIFF"
fi

# --- 以下、herdr/hunkのペイン管理（会話コンテキストは不要） ---

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
  herdr pane run "$pane_id" "hunk diff $diff_base" >/dev/null

  check_launched() {
    jq -e '.result.process_info.foreground_processes[]? | select(.argv0 == "hunk")' >/dev/null 2>&1 \
      <<< "$(herdr pane process-info --pane "$pane_id")"
  }
  if poll 3 check_launched; then
    fail "hunk: opened $target_dir$other_note"
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

  herdr pane run "$pane_id" "cd -- $target_dir_q && hunk diff $diff_base" >/dev/null
  check_launched() {
    jq -e '.result.process_info.foreground_processes[]? | select(.argv0 == "hunk")' >/dev/null 2>&1 \
      <<< "$(herdr pane process-info --pane "$pane_id")"
  }
  if poll 3 check_launched; then
    fail "hunk: opened $target_dir$other_note"
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
  if ! hunk session reload "$session_id" -- diff "$diff_base" >/dev/null 2>&1; then
    fail "$STATUS_RELOAD_FAIL"
  fi
  get_json="$(hunk session get "$session_id" --json 2>/dev/null)" || fail "$STATUS_WORKTREE_NOT_CONFIRMED"
  new_root_norm="$(physical_path "$(jq -r '.session.repoRoot // empty' <<< "$get_json")")"
  if [ -z "$new_root_norm" ] || [ "$new_root_norm" != "$target_dir" ]; then
    fail "$STATUS_WORKTREE_MISMATCH"
  fi
  fail "hunk: reloaded $target_dir$other_note"
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

herdr pane run "$pane_id" "cd -- $target_dir_q && hunk diff $diff_base" >/dev/null

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
fail "hunk: reopened $target_dir$other_note"
