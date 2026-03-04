---
name: claude-code-spec
description: Claude Codeの機能仕様について、組み込み知識では正確な回答ができず行き詰まった場合、またはユーザーに「ドキュメントを確認して」「リポジトリを見て」と指示された場合に使用する。
user-invokable: false
---

# claude-code-spec

Claude Codeの機能仕様について、一次情報源を参照して正確な情報を提供する。

## 起動条件

- 組み込み知識だけでは正確な回答ができず行き詰まった場合
- ユーザーから明示的に調査を指示された場合

上記に該当しない場合はこのスキルを使用しない。

## 情報源と使い分け

### 設定方法・フォーマット・仕様 → 公式リポジトリのコード

設定ファイルの書き方、フロントマターのフィールド、ディレクトリ構造などの仕様情報はソースコードを直接確認する。

- リポジトリ: `https://github.com/anthropics/claude-code`
- `gh` CLIで検索・参照する
  - ファイル一覧: `gh api repos/anthropics/claude-code/contents/{path}`
  - コード検索: `gh search code --repo anthropics/claude-code "{query}"`

### 活用例・ベストプラクティス・ユースケース → 公式ドキュメント

実際のexampleや活用パターンはドキュメントサイトをWebFetchで参照する。

- `https://code.claude.com/docs/en/skills` - スキル
- `https://code.claude.com/docs/en/hooks` - フック
- `https://code.claude.com/docs/en/settings` - 設定
- `https://code.claude.com/docs/en/mcp` - MCPサーバー
- `https://code.claude.com/docs/en/agents` - エージェント
- `https://code.claude.com/docs/en/claude-md` - CLAUDE.md

## 調査手順

1. トピックを特定する（スキル、フック、設定、MCP等）
2. 設定方法・仕様 → リポジトリのソースコードを確認する
3. 活用例・ベストプラクティス → ドキュメントサイトを参照する
4. 得られた情報を元に正確な回答を生成する
