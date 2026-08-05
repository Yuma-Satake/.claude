---
name: hunk-open
description: Herdr環境で、現在のペインの右側にHunkのdiff表示を用意する。会話内で実際に編集したファイルのGitルートを最優先し、submodule内部の差分はsubmodule直下で表示する。対象が会話から分からない場合だけ現在または兄弟worktreeから未コミット差分を持つリポジトリを特定する。右側にまだ無ければhunk diffを起動し、既に起動していれば表示対象を照合してリロードまたは再起動する。issue-fixなど、作業完了時やレビュー修正後にユーザへ差分を見せたい場面で使用する。Herdr環境でない場合は何もしない。
context: fork
agent: haiku-agent-wrapper
background: true
---

以下を順番に実行する。

## 出力フォーマット

このスキルの成果物はペイン操作という副作用そのものであり、テキストは成果物ではない。最終報告は下記の英語固定パターン1行のみとする。これはグローバル言語ルール（常に日本語で応答する）に対する明示的な例外である。分岐ごとに以下のいずれかを一字一句そのまま使い、他のプロースに言い換えない。

- `hunk: skipped (not herdr)` — Herdr環境でない場合
- `hunk: opened <dir>` — 新規オープンに成功した場合
- `hunk: failed (launch not confirmed)` — 新規オープンでプロセス起動を確認できなかった場合
- `hunk: skipped (pane busy)` — 右側ペインがhunk以外で使用中の場合
- `hunk: failed (diff target not found)` — 現在または兄弟worktreeに未コミット差分を持つリポジトリが無い場合
- `hunk: failed (diff target ambiguous)` — 同じ優先順位で未コミット差分を持つリポジトリが複数あり、一意に選べない場合
- `hunk: failed (session not found)` — リロード対象のHunkセッションが特定できなかった場合
- `hunk: failed (reload failed)` — Hunkセッションのリロードに失敗した場合
- `hunk: failed (stop not confirmed)` — 別worktreeのHunkプロセスを停止できなかった場合
- `hunk: failed (restart not confirmed)` — 対象worktreeでのHunk再起動を確認できなかった場合
- `hunk: failed (worktree not confirmed)` — リロード後のHunkセッションを取得できなかった場合
- `hunk: failed (worktree mismatch)` — リロードまたは再起動後もHunkセッションが対象worktreeと一致しない場合
- `hunk: reloaded <dir>` — リロードに成功した場合
- `hunk: reopened <dir>` — 同じ右側ペインで対象worktreeのHunk再起動に成功した場合

`<dir>`は対象ディレクトリの絶対パスに置き換える。この固定1行を再要約・再翻訳せず、そのままユーザーに提示する。

## 1. 前提確認

```bash
test "${HERDR_ENV:-}" = 1
```

失敗した場合、Herdr環境ではないため以降の手順を実行せず `hunk: skipped (not herdr)` と報告して終了する。

## 2. 差分を持つ対象リポジトリを特定

Hunkはsuperprojectからsubmodule内部の作業ツリー差分を展開しない。単に現在のGitルートを対象にすると、rootには` m sources/<repo>`だけが表示され、ユーザーが実際のコード差分を見られない。そのため、`hunk diff`を起動するリポジトリを以下の優先順で解決する。

### 2.1 会話内の変更ファイルから解決

このスキルは会話コンテキスト内で実行し、現在のタスクで編集・作成・削除したファイルのパス、または明示された作業worktreeのパスを最優先の情報源とする。

1. 現在のタスクで変更したファイルパスが分かる場合、各パスの所属Gitルートを次で取得する。

```bash
git -C "$(dirname <changed_file>)" rev-parse --show-toplevel
```

削除済みファイルなどで親ディレクトリが存在しない場合は、存在する最も近い親ディレクトリまで遡って実行する。

2. Gitルートを`cd <path> && pwd -P`で物理パスへ正規化し、重複を除く。
3. 変更ファイルの所属Gitルートが1件なら、そのパスを`target_dir`として手順3へ進む。
4. 複数リポジトリを変更している場合、単一ペインの対象を推測せず`hunk: failed (diff target ambiguous)`と報告して終了する。
5. 作業worktreeだけが明示され、変更ファイルが不明な場合は、そのworktreeについて2.3の候補収集を行う。

superproject配下のsubmoduleファイルを変更した場合、対象はsuperprojectではなく、そのファイルが所属するsubmoduleのGitルートになる。会話内に変更ファイル情報があるのに、カレントディレクトリや別worktreeを優先してはならない。

### 2.2 現在位置を解決

```bash
if current_repo="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  current_repo="$(cd "$current_repo" && pwd -P)"
else
  current_repo=""
fi
```

Gitリポジトリ外の場合は差分対象を解決できないため、`hunk: failed (diff target not found)` と報告して終了する。

### 2.3 リポジトリの未コミット差分判定

候補にするのは、次のコマンドの出力が空でないリポジトリだけとする。

```bash
git -C <repo> status --porcelain --untracked-files=all --ignore-submodules=dirty
```

`--ignore-submodules=dirty`はsuperproject側の` m <submodule>`をroot自身の差分と誤認しないために必要である。gitlink自体の更新、rootの通常ファイル、ステージ済み変更、未追跡ファイルは引き続き差分として検出される。

### 2.4 現在worktree内の候補を収集

1. `<current_repo>`自身が2.3の条件を満たす場合は候補に加える。
2. `<current_repo>/.gitmodules`が存在する場合、次でsubmoduleパスを列挙する。

```bash
git -C "$current_repo" config --file .gitmodules --get-regexp path
```

3. 各`<current_repo>/<submodule_path>`がGitリポジトリとして初期化済みで、2.3の条件を満たす場合は、そのsubmoduleの物理パスを候補に加える。
4. 候補パスは`cd <path> && pwd -P`で正規化し、重複を除く。

現在worktree内の候補が1件なら、そのパスを`target_dir`として手順3へ進む。2件以上なら単一ペインの表示対象を推測せず、`hunk: failed (diff target ambiguous)` と報告して終了する。

### 2.5 兄弟worktreeの候補を収集

会話内の変更ファイル・作業worktreeから対象を解決できず、現在worktree内の候補も0件の場合だけ、現在のリポジトリに紐づくworktreeを列挙する。

```bash
git -C "$current_repo" worktree list --porcelain
```

各`worktree <path>`について2.4と同じ方法でrootと初期化済みsubmoduleを調べる。ただし`current_repo`自身は再調査しない。

兄弟worktree全体の候補が1件なら、そのパスを`target_dir`とする。0件なら`hunk: failed (diff target not found)`、2件以上なら`hunk: failed (diff target ambiguous)`と報告して終了する。

### 2.6 対象確認

以降の`<dir>`には`$target_dir`を使用する。`target_dir`がsubmoduleの場合、superprojectではなくsubmodule直下で`hunk diff`を起動する。

## 3. 右側ペインの有無を確認

```bash
herdr pane layout --pane "$HERDR_PANE_ID"
```

`panes`配列から`focused_pane_id`に一致するpaneの`rect`を自分の位置とし、それより`rect.x`が大きいpaneが右側ペインである。無ければ4、あれば5を実行する。

## 4. 右側ペインが無い場合（新規オープン）

1. 新規ペインを分割する

```bash
herdr pane split --current --direction right --cwd "$target_dir" --no-focus
```

`.result.pane.pane_id`を取得する（以下 `<pane_id>`）。

2. Hunkを起動する

```bash
herdr pane run <pane_id> "hunk diff"
```

3. 起動確認のためプロセス情報を取得する

```bash
herdr pane process-info --pane <pane_id>
```

`foreground_processes`に`argv0`が`hunk`のプロセスが現れるまで、見当たらない場合は1秒待って最大3回まで再試行する。それでも現れなければ `hunk: failed (launch not confirmed)` と報告する。

4. 起動確認できた場合、`hunk: opened <dir>` と報告する。

## 5. 右側ペインが既にある場合

1. 前面プロセスを確認する

```bash
herdr pane process-info --pane <pane_id>
```

2. `foreground_processes`の`argv0`が`hunk`でない場合、右側ペインは別用途で使用中のため何も変更せず `hunk: skipped (pane busy)` と報告して終了する。

3. `argv0`が`hunk`の場合、そのプロセスの`pid`を取得し、ttyを特定する

```bash
ps -p <pid> -o tty=
```

出力（例: `ttys097`）の先頭に`/dev/`を付与した文字列を得る（例: `/dev/ttys097`）。

4. 対応するHunkセッションを特定する

```bash
hunk session list --json
```

`sessions[].terminal.locations[]`の`source`が`tty`かつ`tty`が3で得た文字列と一致するセッションから、`sessionId`と`repoRoot`を取得する（以下 `<session_id>`、`<session_repo_root>`）。一致するセッションが見つからない場合は `hunk: failed (session not found)` と報告する。

5. Hunkセッションのworktreeを対象ディレクトリと照合する

`<session_repo_root>`を`cd`して`pwd -P`で物理パスへ正規化し、`$target_dir`と比較する。正規化できない場合も不一致として扱う。

6. 一致する場合は現在のセッションのディレクトリでリロードする

```bash
hunk session reload <session_id> -- diff
```

コマンドが失敗した場合は `hunk: failed (reload failed)` と報告する。

リロード後のworktreeを取得する。

```bash
hunk session get <session_id> --json
```

コマンドが失敗した場合は `hunk: failed (worktree not confirmed)` と報告する。

`session.repoRoot`を`cd`して`pwd -P`で物理パスへ正規化し、`$target_dir`と比較する。一致しない場合や正規化できない場合は `hunk: failed (worktree mismatch)` と報告する。

一致を確認できたら `hunk: reloaded <dir>` と報告する。

7. 一致しない場合は、同じ右側ペインでHunkを対象ディレクトリから再起動する

現在のHunkを停止する。

```bash
herdr pane send-keys <pane_id> 'ctrl+c'
```

停止確認のためプロセス情報を取得する。

```bash
herdr pane process-info --pane <pane_id>
```

`foreground_processes`に`argv0`が`hunk`のプロセスが残っている場合は1秒待って最大3回まで再試行する。それでも残っていれば `hunk: failed (stop not confirmed)` と報告する。

対象ディレクトリをshell用にエスケープし、同じペインでHunkを起動する。

```bash
target_dir_q="$(printf '%q' "$target_dir")"
herdr pane run <pane_id> "cd -- $target_dir_q && hunk diff"
```

起動確認のためプロセス情報を取得する。

```bash
herdr pane process-info --pane <pane_id>
```

`foreground_processes`に`argv0`が`hunk`のプロセスが現れるまで、見当たらない場合は1秒待って最大3回まで再試行する。それでも現れなければ `hunk: failed (restart not confirmed)` と報告する。

8. 再起動後のworktreeを確認する

```bash
hunk session list --json
```

4で得たtty文字列と一致し、かつ`sessionId`が再起動前の`<session_id>`と異なるセッションが現れるまで、見当たらない場合は1秒待って最大3回まで再試行する。再起動前のセッションが同じttyで残っていても対象にしない。それでも新しいセッションが見つからなければ `hunk: failed (session not found)` と報告する。

一致するセッションの`repoRoot`を`cd`して`pwd -P`で物理パスへ正規化し、`$target_dir`と比較する。一致しない場合や正規化できない場合は `hunk: failed (worktree mismatch)` と報告する。

一致を確認できたら `hunk: reopened <dir>` と報告する。
