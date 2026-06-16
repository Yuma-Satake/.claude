---
name: pilot-fix-feature
description: 自律開発ワークフローのFeature Issueのタスクを1件実装する。pilot-pmサブエージェントからpilot-workerとしてattachされる際（phase:coding・phase:wait_code_fix）に必ずロードする。このスキルは「実装フェーズのpilot-worker」専用であり、仕様作成・レビュー・Issue起票は行わない。ユーザーが直接「バグを修正して」と依頼する場合はfix-issueスキルを使うこと。
argument-hint: "[issue-number]"
---

# pilot-fix-feature

引数: $ARGUMENTS

- `$0`: Feature Issueの番号

Feature Issue `#$0` のタスクを1件実装する。`~/.claude/rules/` 配下のルールおよびプロジェクト固有の `CLAUDE.md` に従って実装する。

pilot kit 共通規約（ESCALATE 記法・worktree 隔離前提など）は `${CLAUDE_PLUGIN_ROOT}/CONVENTIONS.md` を参照すること。

## 前提

- 隔離されたworktree内で実行されている（呼び出し元が `isolation: "worktree"` を指定する）
- 最初に `git fetch origin` を実行する。リモートに `feature/issue-$0` が存在すればそれを追跡してswitchする（前のcycleでpush済みの作業を引き継ぐため）。存在しなければ `origin/<デフォルトブランチ>` の最新から作成する

## 対象タスクの決定

- phase:coding の場合: Issue本文「タスク」セクションの上から最初の未チェックタスク1件のみを対象とする。複数のタスクを1回で実装しない
- phase:wait_code_fix の場合: Issueのpilot-logコメントにあるpilot-reviewer指摘への対応を対象とする
- タスクのチェックボックスは自分では更新しない（pilot-pmが検収後に更新する）

## 手順

### 1. Issueについての情報収集

`gh issue view $0 --comments` で本文・コメントを精読し、関連情報を並列で収集する。

- 言及されているPR・issue（`#xxx` 形式）があれば `gh pr view` / `gh issue view` で内容を確認する
- 外部リンクがあればWebFetchで情報取得を試みる

### 2. コード/ライブラリについての情報収集

- Exploreエージェントで、対象タスクに関わるコード・類似実装・呼び出し元・テストの有無を調査する
- ライブラリの仕様が必要な場合はContext7 MCPでドキュメントを取得する
- `docs/constitution.md` の技術制約・品質基準を確認する

調査結果は以下の2つの視点で整理する。

- 静的モデル: 関係するコンポーネント・モジュールの責務と相互関係
- 動的モデル: 対象処理の主要なフロー（データの流れ・呼び出し順序）

### 3. プランニング

1. 実現可能な実装アプローチを複数案検討し、各案のトレードオフ（変更範囲・リスク・保守性・性能）を整理する
2. `docs/constitution.md` の原則に照らして1案を自己決定する
3. 以下の場合は実装に入らず、結果の先頭に `ESCALATE:` と質問を書いて報告を返し、作業を終了する
   - 複数案が拮抗し、constitutionでは決めきれない場合
   - constitutionのエスカレーション基準に該当する場合
4. アーキテクチャ上の判断（データモデル・外部サービス選定・モジュール境界の変更等）を伴う場合、`docs/adr/` にADRを起案してコミットに含める
   - テンプレート: `${CLAUDE_PLUGIN_ROOT}/skills/pilot-setup/templates/adr.md.tmpl`
   - 番号は既存ADRの連番に続ける。push前に `origin/<デフォルトブランチ>` 上のADRと番号が重複していないか確認し、重複していれば振り直す
5. 決定したアプローチと根拠をIssueにコメントで記録する（言い切りの箇条書きで一度だけ）

### 4. 実装

- 対象タスクのスコープ内だけを変更する。スコープ外の問題は変更せず報告に含める
- Issue本文「受け入れ基準」のうち本タスクに関わるものを必ずテストコードに変換する。テストが仕様の永続形であり、基準とテストの対応が取れないタスクは完了にならない

### 5. 品質チェック

変更内容に応じて以下を実行し、エラーがないことを確認する。

- type-check / lint: プロジェクトのスクリプトを `package.json` / `pyproject.toml` / `Makefile` 等から検出して実行する
- テスト: 追加したテストを含め、変更箇所に関連するテストを実行する
- エラー発生時は根本原因を特定して修正する。`--no-verify` やチェックのスキップで回避しない

### 6. コミットとpush

- 変更をコミットし、`feature/issue-$0` をpushする
- コミットメッセージは規約（`~/.claude/rules/`、プロジェクトのCLAUDE.md）に従う

## 完了報告

呼び出し元（pilot-pm）に以下を報告する。

- `COMPLETED_TASK:` 行: Issue本文のチェックボックスと完全一致するテキストを1行で記載する（pilot-pmがこの文字列で `- [ ]` → `- [x]` 置換を行うため、1文字の差異も許容されない）。例: `COMPLETED_TASK: Google Maps Platform の地図コンポーネントを実装する`
- 受け入れ基準とテストコードの対応表（基準ごとにテストファイル・テスト名）
- 起案したADR（ある場合のみ）
- 実行した品質チェックと結果
- スコープ外で発見した問題（ある場合のみ）
