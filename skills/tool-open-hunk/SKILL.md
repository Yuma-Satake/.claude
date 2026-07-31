---
name: tool-open-hunk
description: Herdr環境で、現在のペインの右側にHunkのdiff表示を用意する。右側にまだ無ければペインを分割してhunk diffを起動し、既に起動していればリロードする。issue-fixなど、作業完了時やレビュー修正後にユーザへ差分を見せたい場面で使用する。Herdr環境でない場合は何もしない。
context: fork
agent: tool-open-hunk-runner
---

以下を順番に実行する。

## 1. 前提確認

```bash
test "${HERDR_ENV:-}" = 1
```

失敗した場合、Herdr環境ではないため以降の手順を実行せず「Herdr環境ではないためスキップした」と報告して終了する。

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

`foreground_processes`に`argv0`が`hunk`のプロセスが現れるまで、見当たらない場合は1秒待って最大3回まで再試行する。それでも現れなければ起動失敗として報告する。

4. 「新規オープン」の結果として、対象ディレクトリと起動確認できた旨を報告する。

## 4. 右側ペインが既にある場合

1. 前面プロセスを確認する

```bash
herdr pane process-info --pane <pane_id>
```

2. `foreground_processes`の`argv0`が`hunk`でない場合、右側ペインは別用途で使用中のため何も変更せず「右側ペインはhunk以外が使用中のためスキップした」と報告して終了する。

3. `argv0`が`hunk`の場合、そのプロセスの`pid`を取得し、ttyを特定する

```bash
ps -p <pid> -o tty=
```

出力（例: `ttys097`）の先頭に`/dev/`を付与した文字列を得る（例: `/dev/ttys097`）。

4. 対応するHunkセッションを特定する

```bash
hunk session list
```

`location[tty]`が3で得たtty文字列と一致するセッションのIDを特定する（以下 `<session_id>`）。一致するセッションが見つからない場合は特定不能として報告する。

5. セッションをリロードする

```bash
hunk session reload <session_id> -- diff
```

6. 「リロード」の結果と対象ディレクトリを報告する。
