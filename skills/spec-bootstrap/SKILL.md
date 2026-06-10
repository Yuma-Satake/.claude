---
name: spec-bootstrap
description: 自律開発ワークフローの初回立ち上げを行う。constitution・visionの作成、phaseラベルの整備、visionからのroadmap起案、Unit Issueの一括起票までを対話的に実行する。「自律開発をセットアップして」「このサービスでspecワークフローを始めたい」と依頼された場合に使用する。サービスリポジトリごとに1回実行する。
---

# spec-bootstrap

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

- テンプレート: `~/.claude/skills/spec-bootstrap/templates/spec-constitution.md.tmpl` および `spec-vision.md.tmpl`
- AskUserQuestionでユーザに質問しながら各セクションを埋める。1回あたり最大4問とし、回答を受けて深掘りする
- 特に「非ゴール」「優先順位の解法」「エスカレーション基準」「マージポリシー」は自律駆動の品質を決めるため、曖昧なまま進めない
- 既に存在する場合は内容を読み、空欄セクションがあれば同様に埋める

### 3. phase ラベルの整備

以下を `gh label create <name> --color <color> --force` で作成する。

| label | color |
|---|---|
| phase:proposed | e4e669 |
| phase:spec_review | fbca04 |
| phase:spec_fix | f9d0c4 |
| phase:impl | 1d76db |
| phase:code_review | 5319e7 |
| phase:impl_fix | b60205 |
| phase:done | 0e8a16 |
| blocked:human | d93f0b |

### 4. ADRディレクトリの作成

`docs/adr/` を作成する（空なら `.gitkeep` を置く）。

### 5. roadmap の起案

pmサブエージェントに以下を依頼する。

- `docs/constitution.md` と `docs/vision.md` を読むこと
- visionを、独立してデプロイ可能かつ単体で価値を持つUnitの列に分解すること
- 各Unitについて: 名前・Outcome（1〜2文）・依存するUnit・実装順序を提示すること
- 実装方針には踏み込まないこと

pmの提案をユーザに提示し、AskUserQuestionで承認を得る。修正指示があれば反映して再提示する。

### 6. Unit Issue の一括起票

承認されたroadmap順に、Unitごとに spec-create-unit skill をロードして起票する。

- 起票順がそのまま優先順位になる（Issue番号昇順 = roadmap順）
- 依存関係は本文の「依存」セクションに `#番号` で記載する

### 7. 初期コミット

`docs/constitution.md`・`docs/vision.md`・`docs/adr/` をコミットする（commit skillを使用する）。

constitutionには「変更はPRで行う」とあるが、初回作成はユーザ同席で内容を確定させているため、例外としてデフォルトブランチへ直接コミットしてよい。

### 8. 完了報告

以下を報告する。

- 作成したdocs・ラベル・起票したUnit一覧
- 自律駆動の開始方法: `/loop 10m /spec-orchestrate`
- ユーザの関与点: `blocked:human` ラベルの付いたIssueへのコメント裁定のみ
