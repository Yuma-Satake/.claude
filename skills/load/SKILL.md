---
name: load
description: GitHub issueまたはPRの情報を読み込んでコンテキストとして保持する。ユーザーが「#123を読み込んで」「issue #45の情報を取得して」と依頼した場合に使用します。番号の後に指示を続けることで、読み込み後にそのまま作業を開始できます。
argument-hint: "[number] [指示]"
---

# load

引数: $ARGUMENTS

- `$0`: issue/PR番号（コマンド実行に使用）
- `$0` 以降に文字列が続く場合、それは後続指示である

## 現在のGit状態

- 現在のブランチ: !`git branch --show-current`
- リポジトリ: !`gh repo view --json nameWithOwner -q .nameWithOwner`

## 対象の種別判定

`gh issue view $0` または `gh pr view $0` を実行して種別を判定する。

## 情報収集手順

### 対象が見つからない場合

- どちらも見つからない場合、ユーザに番号の確認を求める
- フォークしたリポジトリで作業している場合には、親リポジトリのissue/PRを確認すること

### issueの場合

以下の情報を収集する:

1. **本文・コメント**: `gh issue view $0 --comments`
2. **関連リンク**: issue内で言及されている `#xxx` 形式のPR・issueがあれば `gh pr view` / `gh issue view` で内容を確認する
3. **外部リンク**: 外部リンクがあれば WebSearch / WebFetch で情報取得を試みる

### PRの場合

以下の情報を収集する:

1. **本文・コメント**: `gh pr view $0 --comments`
2. **差分**: `gh pr diff $0`
3. **レビューコメント**: `gh api repos/{owner}/{repo}/pulls/$0/reviews --jq '.[] | select(.body != "") | "[\(.user.login)] \(.state): \(.body)"'`
4. **CIステータス**: `gh pr checks $0`
5. **関連リンク**: PR内で言及されている `#xxx` 形式のPR・issueがあれば `gh pr view` / `gh issue view` で内容を確認する
6. **外部リンク**: 外部リンクがあれば WebSearch / WebFetch で情報取得を試みる

## 出力と後続動作

以下をユーザに提示する:

```
## 読み込み完了: [issue/PR] #番号 タイトル
```

### 後続指示がない場合

- ユーザの次の指示を待つ
- 実装やブランチ作成などのアクションは行わない

### 後続指示がある場合

- 読み込んだ情報をコンテキストとして保持したまま、後続指示の実行に移る
- 後続指示はユーザからの直接の依頼として扱う
