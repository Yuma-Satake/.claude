---
name: tool-gh-image
description: GitHubのPull Requestやissueの本文・コメントに画像やスクリーンショットをアップロードして貼り付ける。ユーザーが「PRに画像貼って」「PRに貼って」「PRに画像を添付して」「PRにスクショを載せて」「この画像をPR本文に追加して」「issueに画像を貼って」「コメントに画像を添付して」「Before / After画像を載せて」「gh imageでアップロードして」と依頼した場合は必ず使用する。動画の場合もアップロード可能なので、同様に使用する。
---

# tool-gh-image

GitHubのPR・issueへ画像を添付する場合は、`gh image`拡張機能で画像をアップロードし、出力されたMarkdownを対象の本文またはコメントへ反映する。

## 手順

1. ユーザーの依頼から、対象のPRまたはissue、添付先が本文かコメントか、画像ファイルを特定する
2. 対象または画像ファイルが特定できない場合は、AskUserQuestionToolで不足情報を確認する
3. `gh`コマンドで対象の最新状態とリポジトリの`owner/repo`を取得する
4. 各ファイルについて`gh image <ファイル> --repo owner/repo`を実行する。画像は`![...](URL)`形式のMarkdownを返すが、動画ファイル（`.mov`/`.mp4`等）は生のURLのみを返す（img markdown形式ではない）
5. 取得したMarkdown、または動画の場合は生のURLを独立した行として、既存内容を保持したまま指定された本文またはコメントへ反映する（動画のURLはそのまま貼ればGitHub側が自動でプレーヤー表示する）
6. `gh`コマンドで反映後の本文またはコメントを取得し、画像のMarkdownまたは動画のURLが含まれていることを確認する

## Before / After

画面変更のBefore / Afterを掲載する場合は、`gh image`の出力から画像URLを取り出し、以下のHTMLテーブルで必ず横並びにする。

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
- `gh image`またはGitHubへの反映に失敗した: `tool-gh-image: failed (<reason>)`
