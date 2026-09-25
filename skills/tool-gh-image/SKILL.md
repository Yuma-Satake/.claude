---
name: tool-gh-image
description: GitHubのPull Requestやissueの本文・コメントに画像やスクリーンショットをアップロードして貼り付ける。ユーザーが「PRに画像貼って」「PRに貼って」「PRに画像を添付して」「PRにスクショを載せて」「この画像をPR本文に追加して」「issueに画像を貼って」「コメントに画像を添付して」「Before / After画像を載せて」「gh imageでアップロードして」と依頼した場合は必ず使用する。動画の場合もアップロード可能なので、同様に使用する。
---

# tool-gh-image

GitHubのPR・issueへ画像や動画を添付する場合は、`gh`公式の`--attach`フラグを使用する（`gh issue create`・`gh issue edit`・`gh issue comment`・`gh pr create`・`gh pr edit`・`gh pr comment`で対応）。

## 前提

- `gh` v2.99.0以上が必要
- 対応形式: 画像はPNG・JPEG・GIF・WebP・SVG、動画はMP4・MOV・WebM
- 添付にはリポジトリへのpush権限が必要
- `--attach`は繰り返し指定することで複数ファイルを添付できるが、同じファイルを2回添付することはできない
- 代替テキストを付ける場合は `--attach 'PATH/TO/IMAGE#代替テキスト'` の形式を使う

## 手順

1. ユーザーの依頼から、対象のPRまたはissue、添付先が本文かコメントか、画像・動画ファイルを特定する
2. 対象またはファイルが特定できない場合は、AskUserQuestionToolで不足情報を確認する
3. `gh`コマンドで対象の最新状態を取得する
4. 既存の本文・コメントに追記する場合は`gh issue edit`・`gh pr edit`・`gh issue comment`・`gh pr comment`に`--attach <ファイル>`を付けて実行する（既存本文は保持され、添付ファイルは本文末尾に追記される。新規作成時は`gh issue create`・`gh pr create`に同様に付ける）
5. `gh`コマンドで反映後の本文またはコメントを取得し、画像・動画が添付されていることを確認する

## Before / After

画面変更のBefore / Afterを掲載する場合は、`--attach`で反映された画像URLを取り出し、以下のHTMLテーブルで必ず横並びにする。

```html
<table>
<tr><th>Before</th><th>After</th></tr>
<tr>
<td><img src="<Before画像URL>" width="300"></td>
<td><img src="<After画像URL>" width="300"></td>
</tr>
</table>
```

- `img`の`width`は`300`に固定する
- `img`に`height`属性を指定しない

## 完了報告

この報告は言語ルールの例外として英語の固定形式にする。

- 成功: `tool-gh-image: attached <target>`
- 対象や画像が不足して実行できない: `tool-gh-image: blocked (<reason>)`
- `gh --attach`またはGitHubへの反映に失敗した: `tool-gh-image: failed (<reason>)`
