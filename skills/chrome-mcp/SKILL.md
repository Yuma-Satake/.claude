---
name: chrome-mcp
description: ブラウザ自動化のベストプラクティスを提供します。Claude in Chrome（mcp__claude-in-chrome__*）ツールでWebページを操作する場合、フォーム入力、要素の検索、値の取得、スクリーンショット撮影を行う場合に使用します。
user-invocable: false
---

# Browser Automation (Claude in Chrome)

## フォーム操作

- テキスト入力の上書きには `triple_click` で全選択してから `type` で入力すること
- ボタンクリックが反応しない場合は `find` でボタン要素を特定し、`ref` 指定でクリックすること

## 値の取得

- 画面上で切れている値は `read_page` で `ref_id` を指定し、DOM内の要素から全文を取得できる
- クリップボードAPIはセキュリティ制約で使えない場合がある。`read_page` による DOM 直接参照を優先すること
- コピーボタンのクリック + `navigator.clipboard.readText()` は信頼性が低い

## 一般的なブラウザ操作

- 操作開始時は必ず `tabs_context_mcp` でタブ情報を取得すること
- 新しいセッションでは既存タブのIDを再利用しないこと
- ページの読み込みが完了したかは、タブのタイトル変化で判断できる
- 小さいUI要素は `zoom` で拡大して確認してから操作すること
- `find` は自然言語でのUI要素検索が可能で、座標指定より信頼性が高い
- ページ遷移が遅いサイトでは、操作後に `wait` で数秒待機してから `screenshot` を撮ること
