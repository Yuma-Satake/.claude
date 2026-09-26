---
name: mcp-chrome-devtools
description: mcp-chrome-devtools
user-invocable: false
---

# Chrome DevTools MCP

このスキルは Chrome DevTools MCP（プラグイン `chrome-devtools-mcp@claude-plugins-official`、ツール名は `mcp__plugin_chrome-devtools-mcp_*`）を使う際の使い分けと基本方針を定める。

## mcp-chrome との使い分け

| 用途 | 使うMCP |
| --- | --- |
| ユーザーのログイン状態が必要な操作（Google・社内ツール・SaaS等） | Claude in Chrome（`mcp-chrome` スキル） |
| ローカル開発中のページのデバッグ、パフォーマンストレース、ネットワーク・コンソールの詳細調査、a11y・LCP・メモリリークの調査 | Chrome DevTools MCP |

- Chrome DevTools MCP は自前のChromeを起動し、永続プロファイルを使う。ユーザーが普段使っているChromeのログイン状態は共有されない。ログインが必要な操作は Claude in Chrome を使う
- 単なるブラウザ操作（クリック・入力・スクリーンショット）は Claude in Chrome を優先する。DevToolsの調査機能が必要な場合のみ本MCPを使う

## 専用skillの参照

プラグインに同梱された以下のskillが調査内容ごとの手順を持つ。該当する場合は先に読むこと。

| 場面 | skill |
| --- | --- |
| 基本操作・ワークフロー全般 | `chrome-devtools-mcp:chrome-devtools` |
| アクセシビリティの監査 | `chrome-devtools-mcp:a11y-debugging` |
| LCP・Core Web Vitals の改善 | `chrome-devtools-mcp:debug-optimize-lcp` |
| Cookie・セッション・認証エラーの調査 | `chrome-devtools-mcp:cookie-debugging` |
| メモリリークの調査 | `chrome-devtools-mcp:memory-leak-debugging` |
| `list_pages` `new_page` `navigate_page` の失敗、サーバー起動失敗 | `chrome-devtools-mcp:troubleshooting` |
| シェルスクリプトからのCLI利用 | `chrome-devtools-mcp:chrome-devtools-cli` |

## 基本方針

- ページ操作の流れは navigate_page または new_page、wait_for、take_snapshot、click や fill の順にする。要素は snapshot が返す `uid` で指定する
- ページ単位のツールには `pageId` が必要。`list_pages` で確認するか `new_page` の戻り値を使う
- 要素が見つからない場合は snapshot を取り直す
- 自動化には `take_snapshot`（テキスト）を使い、見た目の確認が必要なときのみ `take_screenshot` を使う
- 出力が大きくなるもの（スクリーンショット・snapshot・トレース）は `filePath` でファイルに出力する。一覧系は `pageIdx` `pageSize` `types` で絞る
- 入力系ツールは、更新後のページ状態が不要なら `includeSnapshot: false` を指定する
- 複数のツール呼び出しを並列で送る場合も、navigate、wait、snapshot、操作の順序は守る
- 拡張機能ツール（`install_extension` 等）は起動引数 `--categoryExtensions`、メモリ調査ツールは `--memoryDebugging` が必要。ツールが一覧に無い場合はユーザーに設定変更を依頼する
- `alert` `confirm` `prompt` などのダイアログを発生させる操作は、後続のコマンドを止めうるため避ける

## 設定上の注意

- MCPサーバーの起動引数はプラグインの `.mcp.json`（`plugins/cache/claude-plugins-official/chrome-devtools-mcp/<version>/`）で定義され、プラグインの更新で上書きされる。引数を変えたい場合はこの点を踏まえてユーザーに確認する
- 使用状況の統計送信は既定で有効。無効化には起動引数 `--no-usage-statistics` が必要
