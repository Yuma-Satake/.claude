---
name: pilot-setup
description: 自律開発ワークフローの初回立ち上げを行う。constitution・visionの作成、phaseラベルの整備、visionからのroadmap起案・保存までを対話的に実行する。「自律開発をセットアップして」「pilot-runを始めたい」「このプロジェクトに自律開発ワークフローを導入したい」と依頼された場合は必ずこのスキルを使用すること。constitution.mdやphaseラベルが未整備なリポジトリでpilot-runを使おうとしている場合は、まずこのスキルを実行する必要がある。サービスリポジトリごとに1回だけ実行する。
---

# pilot-setup

自律開発ワークフローをサービスリポジトリに導入する。ユーザ同席を前提とした対話的なskillであり、ここで確定した判断がその後の自律駆動の基準になる。

## 現在のリポジトリ

- リポジトリ: !`gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "不明"`
- constitution: !`ls docs/constitution.md 2>/dev/null || echo "なし"`
- vision: !`ls docs/vision.md 2>/dev/null || echo "なし"`

## 手順

### 1. 前提確認

- `gh auth status` が通ることを確認する
- gitリポジトリのルートで実行されていることを確認する

### 2. constitution と vision の作成

`docs/constitution.md` と `docs/vision.md` が存在しない場合、テンプレートから複製する。

- テンプレート: `~/.claude/skills/pilot-setup/templates/constitution.md.tmpl` および `vision.md.tmpl`
- AskUserQuestionでユーザに質問しながら各セクションを埋める。1回あたり最大4問とし、回答を受けて深掘りする
- 特に「非ゴール」「優先順位の解法」「エスカレーション基準」「マージポリシー」は自律駆動の品質を決めるため、曖昧なまま進めない
- 既に存在する場合は内容を読み、空欄セクションがあれば同様に埋める

### 3. phase ラベルの整備

以下を `gh label create <name> --color <color> --force` で作成する。

| label | color |
|---|---|
| phase:proposed | e4e669 |
| phase:wait_spec_review | fbca04 |
| phase:wait_spec_fix | f9d0c4 |
| phase:coding | 1d76db |
| phase:wait_code_review | 5319e7 |
| phase:wait_code_fix | b60205 |
| phase:done | 0e8a16 |
| blocked:human | d93f0b |

### 4. ADRディレクトリの作成

`docs/adr/` を作成する（空なら `.gitkeep` を置く）。

### 5. roadmap の起案と保存

pmサブエージェントに以下を依頼する。

- `docs/constitution.md` と `docs/vision.md` を読むこと
- visionを、独立してデプロイ可能かつ単体で価値を持つFeatureの列に分解すること
- 各Featureについて: 名前・Outcome（1〜2文）・依存するFeature・実装順序を提示すること
- 実装方針には踏み込まないこと

pmの提案をユーザに提示し、AskUserQuestionで承認を得る。修正指示があれば反映して再提示する。

承認されたroadmapを `~/.claude/skills/pilot-setup/templates/roadmap.md.tmpl` をもとに `docs/roadmap.md` として保存する。各Featureを表に1行ずつ書き、「Issue」列は `-`（未起票）とする。

Feature Issueの一括起票はここでは行わない。pilot-runから起動されるmasterサブエージェントがcycleごとに先頭の未起票Featureを起票することで、先行Featureの実装結果・ADR・vision更新といった最新コンテキストを反映できる。

### 6. 初期コミット

`docs/constitution.md`・`docs/vision.md`・`docs/roadmap.md`・`docs/adr/` をコミットする（commit skillを使用する）。

constitutionには「変更はPRで行う」とあるが、初回作成はユーザ同席で内容を確定させているため、例外としてデフォルトブランチへ直接コミットしてよい。

### 7. 完了報告

以下を報告する。

- 作成したdocs・ラベル・roadmap.mdに記載したFeature数
- 自律駆動の開始方法: `/loop 10m /pilot-run`（pilot-runスキルが1cycleごとにmasterサブエージェントを起動し、先頭Featureの起票から自動で進める）
- ユーザの関与点: `blocked:human` ラベルの付いたIssueへのコメント裁定のみ

## 管理するテンプレート

`templates/` 配下のテンプレートと利用スキルの対応:

| テンプレート | 用途 | 使用スキル |
|---|---|---|
| constitution.md.tmpl | constitution初期作成 | pilot-setup（手順2） |
| vision.md.tmpl | vision初期作成 | pilot-setup（手順2） |
| roadmap.md.tmpl | roadmap初期作成 | pilot-setup（手順5） |
| adr.md.tmpl | ADR起案 | pm agent（プロダクト判断時）・pilot-fix-feature（手順3） |
| spec-feature-issue.md.tmpl | Feature Issue本文 | pilot-create-feature（手順4） |
