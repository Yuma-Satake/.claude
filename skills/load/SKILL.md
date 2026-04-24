---
name: load
description: GitHub issueまたはPRの情報を読み込んでコンテキストとして保持する。ユーザーが「#123を読み込んで」「issue #45を取得して」「PR #678を見て」と依頼した場合に使用します。番号の後に指示を続けることで、読み込み後にその指示の実行へ進みます。
argument-hint: "[number] [後続指示]"
model: sonnet
---

# load

引数: $ARGUMENTS

- `$0`: issue/PR番号（`gh` コマンドの対象）
- `$0` 以降に文字列が続く場合、読み込み後に実行する後続指示として扱う

## 現在の環境

- リポジトリ: !`gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "不明"`
- 現在のブランチ: !`git branch --show-current`
- `#$0` の種別: !`gh api "repos/{owner}/{repo}/issues/$0" --jq 'if .pull_request then "PR" else "issue" end' 2>/dev/null || echo "見つかりません"`

## 対象が見つからない場合

- ユーザに番号の確認を求める
- フォークしたリポジトリで作業している場合は、親リポジトリのissue/PRが対象である可能性を確認する

## 情報収集

種別ごとに以下の情報を**並列で**収集する。独立したツール呼び出し（`gh` コマンド・`WebFetch` 等）は積極的に並列化すること。

### issueの場合

1. **本文・コメント**: `gh issue view $0 --comments`
2. **関連 issue / PR**: 言及されている `#xxx` 形式があれば `gh issue view` / `gh pr view` で内容を確認する（1段階のみ辿る）
3. **外部リンク**: 外部URLがあれば `WebFetch` で内容を取得する

### PRの場合

1. **本文・コメント**: `gh pr view $0 --comments`
2. **差分**: `gh pr diff $0`
3. **レビューコメント**: `gh pr view $0 --json reviews --jq '.reviews[] | select(.body != "") | "[\(.author.login)] \(.state): \(.body)"'`
4. **CIステータス**: `gh pr checks $0`
5. **関連 issue / PR**: 言及されている `#xxx` 形式があれば `gh issue view` / `gh pr view` で内容を確認する（1段階のみ辿る）
6. **外部リンク**: 外部URLがあれば `WebFetch` で内容を取得する

## 読み込み完了の報告

以下の1行のみを提示する。

```
## 読み込み完了: [issue|PR] #<番号> <タイトル>
```

読み込んだ内容の要約や解説は行わない。コンテキストとして保持するに留め、ユーザからの質問や後続指示が来た時点で活用する。

## 後続動作

### 後続指示がない場合

- ユーザの次の指示を待つ
- 実装・ブランチ作成・コメント投稿などのアクションは行わない

### 後続指示がある場合

- 読み込んだ内容を前提として、後続指示の実行に移る
- 後続指示はユーザからの直接の依頼として扱う
- 実装系の指示であっても、このスキル内ではコミット・PR作成までは行わない（`commit` / `pr` スキルに委ねる）
