---
name: tool-open-hunk
description: Herdr環境で、現在のペインの右側にHunkのdiff表示を用意する。右側にまだ無ければペインを分割してhunk diffを起動し、既に起動していればリロードする。issue-fixなど、作業完了時やレビュー修正後にユーザへ差分を見せたい場面で使用する。Herdr環境でない場合は何もしない。
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
- `hunk: failed (session not found)` — リロード対象のHunkセッションが特定できなかった場合
- `hunk: reloaded <dir>` — リロードに成功した場合

`<dir>`は対象ディレクトリの絶対パスに置き換える。`context: fork`実行のため、この1行がそのまま親会話への最終報告になる。呼び出し元はこの行を再要約・再翻訳せず、そのままユーザーに提示する。

## 1. 前提確認

```bash
test "${HERDR_ENV:-}" = 1
```

失敗した場合、Herdr環境ではないため以降の手順を実行せず `hunk: skipped (not herdr)` と報告して終了する。

## 2. 右側ペインの有無を確認

```bash
herdr pane layout --pane "$HERDR_PANE_ID"
```

`panes`配列から`focused_pane_id`に一致するpaneの`rect`を自分の位置とし、それより`rect.x`が大きいpaneが右側ペインである。無ければ3、あれば4を実行する。

## 3. 右側ペインが無い場合（新規オープン）

1. 新規ペインを分割する

```bash
herdr pane split --current --direction right --cwd "$PWD" --no-focus
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

## 4. 右側ペインが既にある場合

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
hunk session list
```

`location[tty]`が3で得たtty文字列と一致するセッションのIDを特定する（以下 `<session_id>`）。一致するセッションが見つからない場合は `hunk: failed (session not found)` と報告する。

5. セッションをリロードする

```bash
hunk session reload <session_id> -- diff
```

6. リロードに成功したら `hunk: reloaded <dir>` と報告する。
