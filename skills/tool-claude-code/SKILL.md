---
name: tool-claude-code
description: Claude Code の機能仕様・設定方法・フロントマター・フックの書き方・スキルの仕様・MCP設定・CLAUDE.md の書き方など、Claude Code に関する正確な情報が必要なときに積極的に使う。「スキルのフロントマターにどんなフィールドが書ける？」「フックのイベント名は？」「settings.json の書き方は？」「エージェントタイプを追加するには？」という疑問が生じたら、組み込み知識だけで答えず必ずこのスキルを使って一次情報源を確認すること。ユーザーから「ドキュメントを確認して」「リポジトリを見て」「仕様を調べて」と指示されたときはもちろん、Claude Code の設定・拡張機能・API について実装するときも積極的に発動させること。
user-invocable: true
---

# tool-claude-code

Claude Code の一次情報源を参照して、正確な仕様・設定方法・ベストプラクティスを提供する。

## 情報源と使い分け

### 設定値・フロントマター・内部実装 → まず公式ドキュメント

`https://github.com/anthropics/claude-code` にはCLI本体を実装したソースコードは含まれておらず（ルートは`.claude-plugin`・`examples`・`plugins`・`scripts`・ドキュメント関連ファイルのみ）、設定ファイルのキー名やフロントマターのフィールド定義を`gh search code`で検索しても見つからない。これらの仕様は公式ドキュメントのreferenceテーブル（例: skills.md の「Frontmatter reference」）が唯一の正解であり、先に確認する。

- ドキュメント本文は生データで確認する: `curl -s https://code.claude.com/docs/en/{page}.md`（WebFetchの要約はreferenceテーブルの列を欠落させることがあるため、フィールド仕様など正確性が必要な確認では生データを直接読む）
- リポジトリはサンプル実装（`examples/`・`plugins/`・`.claude/`配下）の参考程度にとどめる。ドキュメントに記載がない場合のみ、これらのディレクトリを`gh api repos/anthropics/claude-code/contents/{path}`で確認する

### 活用例・ベストプラクティス・概念説明 → 公式ドキュメント

機能の概要や使い方はドキュメントサイトを参照する。

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
2. `llms.txt` で関連ページを特定し、`curl`でMarkdownを直接取得する（仕様・フィールド定義が必要な場合はreferenceテーブルを確認する）
3. ドキュメントに記載がない場合のみ、リポジトリのサンプル実装を `gh api repos/anthropics/claude-code/contents/{path}` で確認する
4. 得られた情報を元に正確な回答を生成する

## 調査のコツ

- `llms.txt` でキーワードを絞り込んでから関連ページだけ取得すると効率的
- リポジトリ内の `examples/` や `.claude/` ディレクトリには実例が含まれていることがある
- Agent SDK に関する質問は `https://code.claude.com/docs/en/agent-sdk/` 配下のページを参照する
