# user CLAUDE.md

- issueやPRでは常に言い切りの簡潔な文章で書くこと
- 文章において"---"・"**"は使用しないこと

## Rules 適用ガイド

- `code-editing.md`: コードの編集・新規作成・リファクタリング時に適用
- `development-workflow.md`: タスク分割・並行作業・大規模変更の計画・実行時に適用
- `git.md`: Git操作（commit/push/branch/リネーム等）時に適用
- `dependencies.md`: 依存パッケージの追加・削除・更新時に適用
- `javascript-typescript.md`: JS/TSファイルの編集・作成時に適用
- `typescript.md`: TSファイルの編集時に `javascript-typescript.md` と併用
- `react-nextjs.md`: React/Next.jsのコンポーネント・hooks編集時に適用
- `nextjs.md`: Next.jsプロジェクトのコード編集時に適用

## Skills 適用ガイド

- `commit`: ローカル変更のコミット時に参照
- `pr`: PR作成・更新時に参照
- `fix-issue`: GitHub issue対応時に参照
- `load`: GitHub issue/PRの情報読み込み時に参照
- `slack-mcp`: Slack MCPツール使用時に参照
- `chrome-mcp`: Chrome MCPツール使用時に参照
- `claude-code-spec`: Claude Codeの機能仕様（スキル、フック、設定等）について正確な情報が必要な場合に参照

## サブエージェント適用ガイド

- `Explore`: コードベースの調査・検索（thoroughness: quick/medium/very thorough）
- `Plan`: 実装方針の設計・アーキテクチャ検討
- `general-purpose`: 汎用的なリサーチ・複数ステップのタスク
- `react-expert`: Reactのリファクタリング・パフォーマンス改善・状態管理
- `nextjs-expert`: Next.js開発・サーバーレス・SSG最適化
- `typescript-expert`: TypeScript開発・型安全性の改善
- `fujino-san`: コード変更後のデグレード・エッジケース・考慮漏れレビュー（コード変更時に必ず起動）
- `frontend-quality-guardian`: フロントエンドコードの型安全性・規約・React固有の問題チェック（フロントエンド変更時に必ず起動）
- `qa-test-reviewer`: テストカバレッジ・テスタビリティレビュー（既存テスト基盤があるリポジトリでのコード変更時に起動）
- `rules-guardian`: ルールファイルへの準拠チェック（コード変更時に必ず起動）
