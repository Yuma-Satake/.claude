---
name: spec-create-feature
description: 自律開発ワークフローのFeature Issueを起票する。spec-runがroadmap先頭の未起票Featureを逐次起票する際、またはpmがFeature分割やroadmap補充を行う際に使用する。人間との対話を前提とするcreate-issueと異なり、constitution・visionに基づく自己判断で起票し、判断できない事項はESCALATEで呼び出し元に報告する。
argument-hint: "[Featureの概要]"
---

# spec-create-feature

引数: $ARGUMENTS

Featureの概要 `$ARGUMENTS` をもとに、自律開発ワークフロー用のFeature Issueを起票する。

## 現在のリポジトリ

- リポジトリ: !`gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "不明"`

## 実行モードの判定

呼び出し元の指示に従う。明示がない場合は自律実行として扱う。

- ユーザ同席（ユーザが直接 `/spec-create-feature` を呼び出した場合など、明示されたとき）: AskUserQuestionによる確認ができる
- 自律実行（spec-runからの逐次起票dispatch・pmサブエージェントからの分割起票など）: ユーザへの質問はできない。判断できない事項は `ESCALATE:` で呼び出し元に報告する

## このスキルの責務

このスキルは「何をするか・なぜするか」をOutcomeとして明確にすることに集中する。

- 実装方針（どうやるか）は書かない。workerの責務である
- 受け入れ基準・タスクもこの時点では書かない。phase:proposedの段階でpmが記入する（直前に書くことで仕様の陳腐化を防ぐ）

## 手順

### 1. コードベースの調査

Featureに関連するコード・ファイル・機能をExploreエージェントで軽く調査する（thoroughness: quick〜medium）。

把握すること:

- 関連する既存のコード・コンポーネントはどこか
- 技術的に実現できるか、制約や前提条件はあるか

### 2. 不明点の解消

不明点は次の順で解消する。

1. `docs/constitution.md` と `docs/vision.md` を読み、自己回答を試みる
2. ユーザ同席の場合はAskUserQuestionで確認する
3. 自律実行でconstitutionでも判断できない場合、不明点を本文の「関連コード・背景」に前提確認事項として明記する。Featureの成立自体に関わる不明点なら、起票後に結果の先頭へ `ESCALATE:` と質問を書いて呼び出し元に報告する（`blocked:human` の付与はmasterが行うため、自分では付けない）

### 3. 分割の判定

Featureが大きすぎる場合は分割する。基準は「独立してデプロイ可能かつ単体で価値を持つ」こと。

- 複数の独立したコンポーネントにまたがる変更が必要な場合
- 段階的にリリースできる区切りが明確に存在する場合

分割した場合、各Featureを個別に起票し、依存関係を「依存」セクションで結ぶ。後から起票されたFeatureはIssue番号が大きくなり番号順 = 優先順位の前提が崩れるため、先に着手すべきFeatureへの依存を必ず張って着手順を強制する。

### 4. Issueの起票

テンプレート `~/.claude/skills/spec-setup/templates/spec-feature-issue.md.tmpl` に従って本文を作成し、起票する。

- タイトル: `[Feature] <名前>`（言い切り形で簡潔に）
- 記入するセクション: Outcome・やらないこと・依存・関連コード・背景
- 受け入れ基準・タスクのセクションはテンプレートの説明文を残したまま空欄にする
- ラベル: `phase:proposed`（新規起票時の初期ラベルは起票者が付与してよい。それ以外のラベル操作はmasterの責務）

```
gh issue create --title "[Feature] <名前>" --body-file <本文> --label "phase:proposed"
```

既存のopen Issueと重複していないか `gh issue list --state open --limit 200` で確認してから起票する。
