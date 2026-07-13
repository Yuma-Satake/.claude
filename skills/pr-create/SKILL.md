---
name: pr-create
description: 現在のブランチをpushしてPull Requestを作成・更新する。ユーザーが「PRを作って」「プルリクエストを出して」「レビューに出して」「プルリク作って」「PR出して」と依頼した場合、またはレビュー用にコード変更を共有する場合に使用する。コミット済みでない変更がある場合はコミット・pushも行ってからPRを作成する。-dオプションでドラフトPRとして作成する。
argument-hint: "[-d]"
model: sonnet
---

# pr-create

引数: $ARGUMENTS

## 手順

### Step 1: 状態の把握

1. `git branch --show-current` で現在のブランチを確認する
2. `git remote show origin | grep 'HEAD branch'` でデフォルトブランチを確認する
3. `git status --short` でコミットされていない変更を確認する
4. `git log --oneline -10` で直近コミットを確認する
5. `base=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}'); git log --oneline origin/$base..HEAD 2>/dev/null || echo "差分なし"` でブランチの全コミットを確認する
6. `base=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}'); git diff origin/$base..HEAD 2>/dev/null || echo "差分なし"` でブランチの全差分を確認する
7. `gh pr view --json number,title,url,baseRefName 2>/dev/null || echo "既存PRなし"` で既存PRを確認する
8. `cat $(find . -path '*/.github/*pull_request_template*' -o -name 'pull_request_template.md' 2>/dev/null | head -1) 2>/dev/null || echo "テンプレートなし"` でPRテンプレートを確認する

### Step 2: ブランチの確認

1. 現在のブランチがデフォルトブランチ、または `epic/` などのepicブランチである場合: ユーザに確認を求めてから続行する
2. 作業ブランチにいる場合: そのまま Step 3 へ

### Step 3: コミットされていない変更の処理

`git status --short` の結果に変更がない場合はこのステップをスキップし Step 4 へ。

コミットされていない変更がある場合は、PR作成の前に `commit` スキルを `-p` オプション付きで実行してコミットとpushを行い、完了後は Step 5 へ進む（Step 4 はスキップ）。

### Step 4: push

1. `git ls-remote --heads origin <branch>` でリモートにブランチが存在するか確認する
2. リモートにブランチが存在する場合: `git push` を実行する
3. リモートにブランチが存在しない場合: `git push -u origin <branch>` を実行する

### Step 5: PR の作成・更新

#### PR の向き先

- デフォルトブランチから派生したブランチ → デフォルトブランチへ
- epicブランチから派生したブランチ → epicブランチへ

#### PR タイトルの生成

issue番号が既知の場合は `Fix #<issue_number> <title>` の形式で記載する。

例: `Fix #42 ログイン時のバリデーションエラーを修正`

issue番号が不明の場合は `<type>: <title>` の形式で記載する。

| type | 用途 |
| --- | --- |
| `feat` | 新機能の追加 |
| `fix` | バグ修正 |
| `refactor` | 機能変更を伴わないコード改善 |
| `style` | フォーマット変更（動作に影響なし） |
| `docs` | ドキュメントのみの変更 |
| `test` | テストの追加・修正 |
| `chore` | ビルド・ツール関連 |

タイトル・説明文はコミットと差分の内容を最優先に生成する。会話の文脈はあくまで補足情報として扱い、内容の根拠は常に実際のコード変更に基づくこと。

#### PR 説明文の生成

テンプレートが存在する場合は必ず使用する。テンプレートがない場合、以下の2点を必ず記載する。

1. 概要（What）: このPRで何が変わるか
2. 背景（Why）: なぜこの変更が必要か

記述スタイル:
- 誇張表現や主観的な評価を含めない
- 言い切り形式で簡潔に記載する
- 日本語で記載（英語の方が分かりやすい用語は英語で記載）
- エラーハンドリング・retry処理・テストした内容など実装の本質でない箇所については言及しない

#### 画像の添付

PR 説明文に画像（スクリーンショット等）を含める場合は、`coding-git-workflow` skill の「gh CLI 拡張」セクションを参照してアップロード方法を確認する。

#### 作成・更新の実行

- 既存PRあり → `gh pr edit` でPR説明文を更新する
- 既存PRなし → `gh pr create` で新規PR作成する（`-d` 指定時は `gh pr create --draft`）

### Step 6: アサイン

PR作成・更新後、自分自身をアサインする。

`gh pr edit --add-assignee @me`
