---
name: skill-coding-skill-dedup
description: coding-*系skill（coding-standards・coding-architecture・coding-js・coding-typescript等）のSKILL.md間で、同じ規約・原則が文言を変えて重複して記載されていないかを検出し、優先順位に基づき下位skill側の記載を削除するPRを発行する。3日に1回程度の定期cloud routineとして実行されるほか、手動で重複チェックしたい場合にも使用する。
---

# coding-*系skillの重複検出・解消

## 背景

`skills/coding-*/SKILL.md` はそれぞれ独立して追記されてきたため、同じ規約が複数のskillファイルに文言を変えて重複して記載されることがある。pr-review・notion-fixはレビュー用skillごとにcode-reviewer agentを並列起動するため、同じ規約が複数のskillに重複していると、対応する複数のレビュアーが同じ指摘を別々の根拠で返し、レビュー結果に重複が生じる。このskillは重複を継続的に検知し、優先順位に基づいて解消するための手順を定義する。

このファイルはcloud routineのpromptから`Read`されて実行されることを前提とする。実行環境はこのリポジトリの設定（rules配下のグローバル指示）を継承しないため、本文中の指示は自己完結させてある。手順から逸脱せず、ここに書かれていないルール（他のskillファイルの内容等）を推測で補わないこと。

## 対象範囲

`skills/coding-*/SKILL.md` 全体。次のコマンドで一覧を取得する。

```
ls skills/coding-*/SKILL.md
```

## 優先順位

1. `skills/coding-standards/SKILL.md`・`skills/coding-architecture/SKILL.md`（上位）
2. 上記2つを除く、その他すべての`coding-*`skill（下位）

同じ規約が上位・下位の間で重複している場合、上位の記載を正とし、下位側の記載を削除する。

下位skill同士（例: `coding-js`と`coding-test`）の間で重複が見つかった場合、このskillでは優先順位が定義されていないため自動修正の対象外とする。該当箇所はコードを編集せず、PR本文の「検出したが自動修正しなかった重複」欄に記載するに留める。

## 検出したい重複のレベル

文言が完全一致するものだけでなく、表現が異なっていても同じ規約・原則を指している記述（意味レベルの重複）も対象とする。単にトピックが重なっている（例: どちらも「エラーハンドリング」に言及している）だけでは重複と判定せず、実際に指示している行動・条件が同一かどうかで判断すること。下位skillが上位skillの内容を継承しつつ、言語・フレームワーク固有の追加情報（具体的なAPI名、固有の落とし穴など）を付け加えている場合は重複とみなさない。

## 手順

### Step 1: ファイルの読み込み

`skills/coding-standards/SKILL.md`・`skills/coding-architecture/SKILL.md`と、その他すべての`coding-*/SKILL.md`を全文読み込む。

### Step 2: 重複の検出

その他すべての`coding-*`skillそれぞれについて、記載されている規約を1件ずつ、`coding-standards`・`coding-architecture`の記載と比較する。意味レベルで同一の規約と判断したものを重複候補としてリストアップする（対象skill、該当箇所、対応する上位skillの該当箇所、判断根拠を記録する）。

### Step 3: 修正

重複候補それぞれについて、下位skill側の該当記述を削除する。上位skill側は一切編集しない。削除の結果、見出しや表が空になる場合は、その見出し・表ごと削除し、不自然な空セクションを残さない。それ以外の構成（見出し構造、他の項目の順序）は変更しない。

重複が1件も見つからなかった場合、Step 4以降は実行せず、ここで終了する。ブランチ作成・PR発行は行わない。

### Step 4: 既存PRの確認

重複が見つかった場合、ブランチを作成する前に、このルーティンが過去に発行して未マージのままのPRが無いか確認する。

```
gh pr list --state open --search "skill-dedup in:title" --json number,headRefName,url
```

- 該当PRが無い場合: Step 5へ進む
- 該当PRがあり、そのブランチが現在のdefaultブランチの最新コミットから派生している場合: 新規ブランチ・新規PRは作成せず、そのブランチに今回の修正をコミット・pushし、`gh pr edit`でPR本文を更新する。Step 5・Step 6はスキップし、Step 7へ進む
- 該当PRがあるが、defaultブランチが進んでいて古い場合: 既存PRは`gh pr close`でクローズし、Step 5から新規に作成し直す

### Step 5: ブランチ作成

現在のdefaultブランチの最新コミットから、`chore/skill-dedup-<実行日、YYYYMMDD形式>`という名前でブランチを作成する。

### Step 6: コミット・push

Step 3で編集したファイルのみをコミットする。コミットメッセージは`chore: coding-*系skillの重複記載を解消`のように変更内容を簡潔に表す1行とする。作成したブランチをoriginにpushする。

### Step 7: PR作成・更新

タイトル: `chore: coding-*系skillの重複記載を解消 (skill-dedup)`

本文には次を含める。

1. 検出して自動修正した重複の一覧（表形式）。列: 修正したskillファイル、削除した記述の要約、対応する上位skillの記述箇所、判断根拠
2. 検出したが優先順位未定義のため自動修正しなかった重複がある場合、その一覧（同じ列構成）
3. 「このPRはissue #4のskill-coding-skill-dedup routineによって自動生成された。マージ前に内容を確認すること。」という一文

本文の記述スタイル:
- 言い切り形式で簡潔に記載する。誇張表現や主観的な評価を含めない
- `---`・`**`を使用しない
- 絵文字を使用しない

新規PRの場合は`gh pr create --draft`でdraft PRとして作成し、baseはdefaultブランチとする。既存PRを更新する場合はStep 4の指示に従う。

このskillはdraft PRを発行するところまでを責務とし、マージ・レビュー承認は行わない。mainへの直接コミットは行わない。
