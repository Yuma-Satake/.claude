---
name: claude-code-spec
description: Claude Code の機能仕様・設定方法・フロントマター・フックの書き方・スキルの仕様・MCP設定・CLAUDE.md の書き方など、Claude Code に関する正確な情報が必要なときに積極的に使う。「スキルのフロントマターにどんなフィールドが書ける？」「フックのイベント名は？」「settings.json の書き方は？」「エージェントタイプを追加するには？」という疑問が生じたら、組み込み知識だけで答えず必ずこのスキルを使って一次情報源を確認すること。ユーザーから「ドキュメントを確認して」「リポジトリを見て」「仕様を調べて」と指示されたときはもちろん、Claude Code の設定・拡張機能・API について実装するときも積極的に発動させること。
user-invokable: true
---

# claude-code-spec

Claude Code の一次情報源を参照して、正確な仕様・設定方法・ベストプラクティスを提供する。

## 情報源と使い分け

### 設定値・フロントマター・内部実装 → 公式リポジトリ

設定ファイルのキー名、フロントマターのフィールド定義、ディレクトリ構造などは、ソースコードが唯一の正解。

- リポジトリ: `https://github.com/anthropics/claude-code`
- ファイル一覧: `gh api repos/anthropics/claude-code/contents/{path}`
- コード検索: `gh search code --repo anthropics/claude-code "{query}"`

### 活用例・ベストプラクティス・概念説明 → 公式ドキュメント

機能の概要や使い方はドキュメントサイトを WebFetch で参照する。

- ドキュメントインデックス: `https://code.claude.com/docs/llms.txt`（全ページ一覧）
- 主要ページ:
  - `https://code.claude.com/docs/en/skills.md` - スキル
  - `https://code.claude.com/docs/en/hooks.md` - フック
  - `https://code.claude.com/docs/en/settings.md` - 設定
  - `https://code.claude.com/docs/en/mcp.md` - MCPサーバー
  - `https://code.claude.com/docs/en/agents.md` - エージェント
  - `https://code.claude.com/docs/en/memory.md` - CLAUDE.md / メモリ
  - `https://code.claude.com/docs/en/commands.md` - コマンド
  - `https://code.claude.com/docs/en/permissions.md` - 権限
  - `https://code.claude.com/docs/en/plugins.md` - プラグイン
  - `https://code.claude.com/docs/en/workflows.md` - ワークフロー
  - `https://code.claude.com/docs/en/sub-agents.md` - サブエージェント
  - `https://code.claude.com/docs/en/hooks-guide.md` - フックガイド（実践例）

## 調査手順

1. トピックを特定する（スキル / フック / 設定 / MCP / エージェント / CLAUDE.md 等）
2. **仕様・フィールド定義が必要** → リポジトリのソースコードを `gh search code` で検索
3. **使い方・概念が必要** → まず `llms.txt` で関連ページを特定し、WebFetch で本文を取得
4. 両方が必要な場合は並行して調べる
5. 得られた情報を元に正確な回答を生成する

## 調査のコツ

- `llms.txt` でキーワードを絞り込んでから関連ページだけ取得すると効率的
- リポジトリ内の `examples/` や `.claude/` ディレクトリには実例が含まれていることがある
- Agent SDK に関する質問は `https://code.claude.com/docs/en/agent-sdk/` 配下のページを参照する
