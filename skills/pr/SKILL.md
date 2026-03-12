---
name: pr
description: 現在のブランチをpushしてPull Requestを作成・更新する。ユーザーが「PRを作って」「プルリクエストを出して」と依頼した場合、またはレビュー用にコード変更を共有する場合に使用します。事前にcommitスキルで変更をコミットしておくことが前提です。-dオプションでドラフトPRとして作成します。
argument-hint: "[-d]"
model: sonnet
---

# pr

引数: $ARGUMENTS

## 現在のGit状態

- デフォルトブランチ: !`git remote show origin | grep HEAD`
- 現在のブランチ: !`git branch --show-current`
- ステータス: !`git status --short`
- 直近コミット: !`git log --oneline -10`
- ブランチの全コミット: !`base=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}'); git log --oneline origin/$base..HEAD 2>/dev/null || echo "差分なし"`
- ブランチの全差分: !`base=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}'); git diff origin/$base..HEAD 2>/dev/null || echo "差分なし"`
- 既存PR: !`gh pr view --json number,title,url,baseRefName 2>/dev/null || echo "既存PRなし"`
- PRテンプレート: !`cat $(find . -path '*/.github/*pull_request_template*' -o -name 'pull_request_template.md' 2>/dev/null | head -1) 2>/dev/null || echo "テンプレートなし"`

## 動作モード

- 引数なし → 通常のPRを作成・更新する
- `-d` → ドラフトPRとして作成する（`gh pr create --draft`）
  - 既存PRの更新時にはドラフト状態の変更は行わない

## 動作フロー

1. **ブランチ判定**
   - 作業ブランチにいる場合 → そのまま続行
   - デフォルトブランチ or epicブランチにいる場合 → ユーザに確認を求める
2. **push**
3. **PR判定**
   - 既存PRあり → PRの説明文を更新
   - 既存PRなし → 新規PR作成（`-d` 指定時はドラフトとして作成）

コミットされていない変更（ステータスに差分）がある場合は、PR作成の前に `/commit -p` スキルを実行してコミットとpushを行う。

## PRの向き先

- デフォルトブランチから派生 → デフォルトブランチへ
- epicブランチから派生 → epicブランチへ

epicブランチとは `epic/` などで命名されたブランチを指す。

## PRタイトル

### issue番号が既知の場合

`Fix #<issue_number> <title>` の形式で記載する。

例: `Fix #42 ログイン時のバリデーションエラーを修正`

### issue番号が不明の場合

`<type>: <title>` の形式で記載する。

### type一覧

| type | 用途 |
| --- | --- |
| `feat` | 新機能の追加 |
| `fix` | バグ修正 |
| `refactor` | 機能変更を伴わないコード改善 |
| `style` | フォーマット変更（動作に影響なし） |
| `docs` | ドキュメントのみの変更 |
| `test` | テストの追加・修正 |
| `chore` | ビルド・ツール関連 |

## PR説明文

### テンプレート

テンプレートが存在する場合は必ず使用する。

### 必須要素

テンプレートがない場合、以下の2点を必ず記載する。テンプレートにこれらの要素が含まれている場合はテンプレートに従う。

1. **概要（What）**: このPRで何が変わるか
2. **背景（Why）**: なぜこの変更が必要か

### 記述スタイル

- 誇張表現や主観的な評価を含めない
- 文章として記述することは避け、言い切り形式で簡潔に記載する
- 日本語で記載（英語の方が分かりやすい用語は英語で記載）
- エラーハンドリング・retry処理など実装の本質でない箇所については言及しない

## アサイン

- PR作成後、自分自身をアサインする（`gh pr edit --add-assignee @me`）

## 基本ルール

- ブランチ操作には `git checkout` ではなく `git switch` を使用する

## 生成の優先度

PRのタイトル・説明文は**コミットと差分の内容を最優先**に生成する。会話の文脈はあくまで補足情報として扱い、内容の根拠は常に実際のコード変更に基づくこと。

- ブランチの全コミットと差分を分析し、変更内容を正確に記述する
- 会話の中で議論された意図や背景は参考にしてよいが、差分に反映されていない内容を含めない
